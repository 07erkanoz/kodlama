import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../servis/kopru_istemci.dart';

enum SesDurumu { kapali, baglaniyor, dinliyor, konusuyor, calisiyor }

/// Konuşmanın ekranda görünen bir satırı (kullanıcının dediği ya da sesin
/// cevabı); akarken uzar.
class SesSatiri {
  SesSatiri(this.kullanici, [this.metin = '']);
  final bool kullanici;
  String metin;
}

/// Codex ile sesli konuşma (Codex'in realtime sesi, WebRTC).
///
/// Ses doğrudan bu cihazla OpenAI arasında akar: köprü yalnızca bağlantı
/// teklifini (SDP) Codex'e iletir, yanıtını geri verir. Konuşma açık sohbetin
/// thread'ine bağlıdır: sesle istenen iş Codex'e devredilir, Codex aynı
/// projede çalışır; araçlar ve onaylar sohbette her zamanki gibi görünür.
/// Onaylar yalnızca dokunarak verilir.
class SesliKonusma extends ChangeNotifier {
  SesliKonusma(this.istemci, this.oturum, {required this.ajanCalisiyor}) {
    _abone = istemci.olaylar.listen((e) {
      if (e['oturum'] == oturum && e['ev'] == 'ses') _olay(e);
    });
  }

  final KopruIstemci istemci;
  final String oturum;

  /// Ajan şu an iş yapıyor mu (sessizlikte kapanmayı erteler).
  final bool Function() ajanCalisiyor;

  /// Bu kadar sessizlikten sonra (ajan çalışmıyorsa) konuşma kendiliğinden kapanır.
  static const sessizlikSiniri = Duration(seconds: 60);

  /// Codex'in yanıtı bazen yarım dakika gecikir; geç kalan bırakılıp bir kez
  /// daha istenir.
  static const yanitSabri = Duration(seconds: 25);

  SesDurumu durum = SesDurumu.kapali;
  String? hata;
  bool sessiz = false;
  final satirlar = <SesSatiri>[];

  StreamSubscription? _abone;
  RTCPeerConnection? _pc;
  RTCDataChannel? _kanal;
  MediaStream? _mikrofon;
  Completer<String>? _yanit;
  Timer? _saat;
  DateTime _sonEtkinlik = DateTime.now();
  SesSatiri? _duyulan, _soylenen;
  bool _kapaniyor = false;

  bool get acik => durum != SesDurumu.kapali;

  void _ver(SesDurumu d) {
    if (durum == d) return;
    durum = d;
    notifyListeners();
  }

  Future<void> baslat({String? ses}) async {
    if (acik) return;
    hata = null;
    sessiz = false;
    satirlar.clear();
    _duyulan = _soylenen = null;
    _ver(SesDurumu.baglaniyor);
    try {
      _mikrofon = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      for (var deneme = 1; ; deneme++) {
        final pc = _pc = await createPeerConnection({
          'sdpSemantics': 'unified-plan',
        });
        for (final t in _mikrofon!.getAudioTracks()) {
          await pc.addTrack(t, _mikrofon!);
        }
        final kanal = _kanal = await pc.createDataChannel(
          'oai-events',
          RTCDataChannelInit(),
        );
        kanal.onMessage = _kanalOlayi;
        pc.onConnectionState = (c) {
          if (c == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _sonEtkinlik = DateTime.now();
            if (durum == SesDurumu.baglaniyor) _ver(SesDurumu.dinliyor);
          } else if (c ==
                  RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              c == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
            hata ??= 'Ses bağlantısı koptu.';
            unawaited(bitir());
          }
        };
        final teklif = await pc.createOffer({'offerToReceiveAudio': true});
        await pc.setLocalDescription(teklif);
        _yanit = Completer<String>();
        await istemci.iste('ses_baslat', {
          'oturum': oturum,
          'sdp': teklif.sdp,
          'ses': ?ses,
        });
        final String sdp;
        try {
          sdp = await _yanit!.future.timeout(
            deneme < 2 ? yanitSabri : const Duration(seconds: 60),
          );
        } on TimeoutException {
          if (deneme >= 2) rethrow;
          pc.onConnectionState = null;
          _pc = _kanal = null;
          unawaited(() async {
            try {
              await kanal.close();
              await pc.close();
            } catch (_) {}
          }());
          continue; // ses_baslat öncekini kendisi kapatır
        }
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        break;
      }
      _sonEtkinlik = DateTime.now();
      _saat = Timer.periodic(const Duration(seconds: 1), (_) => _tik());
    } catch (e) {
      hata ??= _acikla(e);
      await bitir();
    }
  }

  static String _acikla(Object e) {
    final s = '$e';
    if (e is TimeoutException) {
      return 'Codex sesi zamanında cevap vermedi. Biraz sonra yeniden dene.';
    }
    if (s.contains('Permission') || s.contains('NotAllowed')) {
      return 'Mikrofon izni verilmedi.';
    }
    if (s.contains('login') || s.contains('auth')) {
      return 'Codex\'e giriş yapılmamış (Ayarlar › Ajanlar › Giriş yap).';
    }
    return 'Sesli konuşma açılamadı: $s';
  }

  void hatayiKapat() {
    hata = null;
    notifyListeners();
  }

  /// Mikrofonu kapat/aç (konuşma sürer, sen duyulmazsın).
  void sessizeAl() {
    sessiz = !sessiz;
    for (final t in _mikrofon?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !sessiz;
    }
    notifyListeners();
  }

  /// Konuşmaya yazıyla bir şey ekle (ses okur, gerekirse işi devreder).
  Future<void> yaz(String metin) =>
      istemci.iste('ses_metin', {'oturum': oturum, 'metin': metin});

  Future<void> bitir() async {
    if (_kapaniyor) return;
    _kapaniyor = true;
    final pc = _pc, kanal = _kanal, mik = _mikrofon;
    _pc = _kanal = null;
    _mikrofon = null;
    _saat?.cancel();
    _saat = null;
    pc?.onConnectionState = null;
    if (_yanit case final y? when !y.isCompleted) {
      y.completeError(StateError('durduruldu'));
      y.future.ignore();
    }
    try {
      await istemci.iste('ses_bitir', {'oturum': oturum});
    } catch (_) {}
    try {
      await kanal?.close();
      for (final t in mik?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await mik?.dispose();
      await pc?.close();
    } catch (_) {}
    _duyulan = _soylenen = null;
    _kapaniyor = false;
    _ver(SesDurumu.kapali);
    notifyListeners();
  }

  @override
  void dispose() {
    _abone?.cancel();
    unawaited(bitir());
    super.dispose();
  }

  void _tik() {
    if (_pc == null) return;
    final sessizlik = DateTime.now().difference(_sonEtkinlik);
    // Sonu gelmeyen bir satır birkaç saniye sonra söylenmiş sayılır.
    if (sessizlik > const Duration(seconds: 4)) _duyulan = _soylenen = null;
    final calisiyor = ajanCalisiyor();
    if (calisiyor) _sonEtkinlik = DateTime.now();
    if (!calisiyor && sessizlik > sessizlikSiniri) {
      satirlar.add(SesSatiri(false, '(Sessizlik uzadı, konuşma kapandı.)'));
      unawaited(bitir());
      return;
    }
    if (durum == SesDurumu.baglaniyor) return;
    _ver(
      calisiyor
          ? SesDurumu.calisiyor
          : _soylenen != null
          ? SesDurumu.konusuyor
          : SesDurumu.dinliyor,
    );
  }

  void _olay(Map<String, dynamic> e) {
    switch (e['tur']) {
      case 'sdp':
        if (_yanit case final y? when !y.isCompleted) {
          y.complete(e['sdp'] as String? ?? '');
        }
      case 'hata':
        hata = 'Ses: ${e['metin'] ?? ''}';
        if (_yanit case final y? when !y.isCompleted) {
          y.completeError(StateError(hata!));
        } else {
          notifyListeners();
        }
      case 'kapandi':
        if (_pc != null && _yanit?.isCompleted != false) unawaited(bitir());
      case 'parca':
        _sonEtkinlik = DateTime.now();
        final metin = e['metin'] as String? ?? '';
        if (e['rol'] == 'user') {
          (_duyulan ??= _satir(true)).metin += metin;
          _soylenen = null;
        } else {
          (_soylenen ??= _satir(false)).metin += metin;
          _duyulan = null;
          if (durum == SesDurumu.dinliyor) durum = SesDurumu.konusuyor;
        }
        notifyListeners();
      case 'bitti':
        _sonEtkinlik = DateTime.now();
        final metin = (e['metin'] as String? ?? '').trim();
        if (e['rol'] == 'user') {
          if (metin.isNotEmpty) (_duyulan ?? _satir(true)).metin = metin;
          _duyulan = null;
          if (durdurmaSozu(metin)) {
            unawaited(bitir());
            return;
          }
        } else {
          if (metin.isNotEmpty) (_soylenen ?? _satir(false)).metin = metin;
          _soylenen = null;
        }
        notifyListeners();
    }
  }

  SesSatiri _satir(bool kullanici) {
    final s = SesSatiri(kullanici);
    satirlar.add(s);
    if (satirlar.length > 40) satirlar.removeAt(0);
    return s;
  }

  void _kanalOlayi(RTCDataChannelMessage m) {
    // Kullanıcı söze girdi: ses susar, söylenen satır kapanır.
    if (m.text.contains('input_audio_buffer.speech_started')) {
      _soylenen = null;
      _sonEtkinlik = DateTime.now();
      notifyListeners();
    }
  }
}

/// "Kapat", "yeter", "görüşürüz" gibi kısa bir söz konuşmayı bitirir.
bool durdurmaSozu(String soz) {
  final kelimeler = soz
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zçğıöşü\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (kelimeler.isEmpty || kelimeler.length > 5) return false;
  const kokler = [
    'kapa',
    'sus',
    'yeter',
    'dur',
    'bitir',
    'bitti',
    'görüşürüz',
    'hoşçakal',
    'hoşça',
  ];
  // "durum", "durumu" gibi soru kelimeleri kapatmasın
  const istisna = {'durum', 'durumu', 'durumda', 'duruyor', 'kapalı', 'kapak'};
  return kelimeler.any(
    (k) => !istisna.contains(k) && kokler.any((s) => k.startsWith(s)),
  );
}
