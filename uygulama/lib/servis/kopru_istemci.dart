import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum BaglantiDurumu { kapali, baglaniyor, bagli, yetkisiz }

class KopruHatasi implements Exception {
  KopruHatasi(this.mesaj, {this.ayrinti});
  final String mesaj;

  /// Köprünün verdiği yapılandırılmış ayrıntı (ör. SSH hatasının türü).
  final Map<String, dynamic>? ayrinti;
  @override
  String toString() => mesaj;
}

/// Termux'taki Atölye köprüsüne WebSocket bağlantısı.
///
/// İstekler `no` ile eşlenir ([iste]); köprünün yayınladığı olaylar
/// ([olaylar]) her bağlı ekrana gider. Bağlantı koparsa kendiliğinden
/// yeniden bağlanır.
class KopruIstemci {
  KopruIstemci({required this.port, required this.token});

  final int port;
  final String token;

  final durum = ValueNotifier(BaglantiDurumu.kapali);
  final _olaylar = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get olaylar => _olaylar.stream;

  WebSocketChannel? _kanal;
  StreamSubscription? _abone;
  final _bekleyen = <int, Completer<Map<String, dynamic>>>{};
  int _no = 0;
  bool _kapatildi = false;
  Timer? _tekrar;
  int _deneme = 0;

  // Olay sırası (köprü 0.13+): köprü her olaya artan bir numara verir.
  // Yeniden bağlanırken son görülen numara söylenir, arada kaçanlar gelir.
  String? _kopruKimlik;
  int? _sira;
  int? _selamNo;

  /// Son bağlanışta kaçan olaylar köprüden geldi mi (geldiyse geçmişi
  /// yeniden yüklemeye gerek yok).
  bool devam = false;

  /// Bağlanırken köprüde bekleyen onaylar; eski köprüde null.
  List<Map<String, dynamic>>? acikOnaylar;

  Uri get _wsAdres => Uri.parse('ws://127.0.0.1:$port');

  /// Köprünün sunduğu bir dosyanın adresi (resim, PDF…).
  Uri dosyaAdresi(String yol) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: port,
    path: '/dosya',
    queryParameters: {'yol': yol, 't': token},
  );

  /// Dosyayı yolu adreste olacak biçimde verir (köprü 0.7+): HTML
  /// sayfaları göreli css/js/resimleriyle tarayıcıda düzgün açılır.
  Uri sayfaAdresi(String yol) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: port,
    pathSegments: [
      's',
      token,
      ...yol.split('/').where((p) => p.isNotEmpty),
      if (yol.endsWith('/')) '',
    ],
  );

  Uri get saglikAdresi => Uri.parse('http://127.0.0.1:$port/saglik');

  Future<void> baglan() async {
    _kapatildi = false;
    _tekrar?.cancel();
    if (durum.value == BaglantiDurumu.bagli ||
        durum.value == BaglantiDurumu.baglaniyor) {
      return;
    }
    durum.value = BaglantiDurumu.baglaniyor;
    try {
      final kanal = WebSocketChannel.connect(_wsAdres);
      await kanal.ready.timeout(const Duration(seconds: 5));
      _kanal = kanal;
      _abone = kanal.stream.listen(
        _gelen,
        onDone: _koptu,
        onError: (_) => _koptu(),
      );
      final yanit = await _istek({
        'op': 'hello',
        'token': token,
        if (_kopruKimlik != null) 'kimlik': _kopruKimlik,
        if (_sira != null) 'son': _sira,
      }, selam: true);
      if (yanit['hata'] != null) {
        durum.value = BaglantiDurumu.yetkisiz;
        _kapatildi = true;
        await kanal.sink.close();
        return;
      }
      _deneme = 0;
      durum.value = BaglantiDurumu.bagli;
    } catch (_) {
      _koptu();
    }
  }

  void _gelen(dynamic ham) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(ham as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final no = m['no'];
    if (no is int && _bekleyen.containsKey(no)) {
      // Selam yanıtı burada, eşzamanlı işlenir: hemen ardından gelen
      // kaçan olaylar doğru sırayla değerlendirilsin.
      if (no == _selamNo) _selamIsle(m);
      _bekleyen.remove(no)!.complete(m);
      return;
    }
    if (m['ev'] != null) {
      final s = m['sira'];
      if (s is int) {
        final son = _sira;
        if (son != null && s <= son) return; // zaten görüldü
        _sira = s;
      }
      _olaylar.add(m);
    }
  }

  void _selamIsle(Map<String, dynamic> m) {
    _selamNo = null;
    final s = m['sonuc'];
    if (m['hata'] != null || s is! Map) return;
    final kimlik = s['kimlik'] as String?;
    devam = s['devam'] == true && kimlik != null && kimlik == _kopruKimlik;
    _kopruKimlik = kimlik;
    // Devam edilmiyorsa sıra köprünün şimdiki numarasından başlar.
    if (!devam) _sira = s['sira'] as int?;
    final o = s['onaylar'];
    acikOnaylar = o is List
        ? [for (final x in o.whereType<Map>()) x.cast<String, dynamic>()]
        : null;
  }

  void _koptu() {
    _abone?.cancel();
    _abone = null;
    _kanal = null;
    for (final c in _bekleyen.values) {
      if (!c.isCompleted) c.completeError(KopruHatasi('bağlantı koptu'));
    }
    _bekleyen.clear();
    if (durum.value != BaglantiDurumu.yetkisiz) {
      durum.value = BaglantiDurumu.kapali;
    }
    if (_kapatildi) return;
    final bekle = Duration(seconds: (1 << _deneme.clamp(0, 4)));
    _deneme++;
    _tekrar = Timer(bekle, baglan);
  }

  /// Uzun sürebilen işler: yanıtı 60 sn yerine 10 dakika beklenir (yoksa
  /// iş köprüde sürerken uygulama "yanıt vermedi" derdi).
  static const _uzunIsler = {
    'git_klonla',
    'git_push',
    'git_pull',
    'git_commit',
    'gh_pr',
    'gh_anahtar_ekle',
    'sunucu_anahtar_gonder',
    'sunucu_dene',
    'yukle',
    'derleme_baslat',
    'derleme_indir',
    'kopru_guncelle',
    'mcp_ekle',
  };

  Future<Map<String, dynamic>> _istek(
    Map<String, dynamic> m, {
    bool selam = false,
  }) {
    final kanal = _kanal;
    if (kanal == null) return Future.error(KopruHatasi('bağlı değil'));
    final no = ++_no;
    if (selam) _selamNo = no;
    final c = Completer<Map<String, dynamic>>();
    _bekleyen[no] = c;
    kanal.sink.add(jsonEncode({...m, 'no': no}));
    return c.future.timeout(
      _uzunIsler.contains(m['op'])
          ? const Duration(minutes: 10)
          : const Duration(seconds: 60),
      onTimeout: () {
        _bekleyen.remove(no);
        throw KopruHatasi('köprü yanıt vermedi');
      },
    );
  }

  /// Bir işlem iste; köprü hata dönerse [KopruHatasi] atar.
  Future<Map<String, dynamic>> iste(
    String op, [
    Map<String, dynamic> params = const {},
  ]) async {
    final yanit = await _istek({'op': op, ...params});
    if (yanit['hata'] != null) {
      final a = yanit['hata_ayrinti'];
      throw KopruHatasi(
        yanit['hata'].toString(),
        ayrinti: a is Map ? a.cast<String, dynamic>() : null,
      );
    }
    return (yanit['sonuc'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<void> kapat() async {
    _kapatildi = true;
    _tekrar?.cancel();
    await _kanal?.sink.close();
    durum.value = BaglantiDurumu.kapali;
  }
}
