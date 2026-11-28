import 'dart:async';

import 'package:flutter/widgets.dart';

import '../arayuz/ortak.dart';
import '../servis/bildirim.dart';
import '../servis/kopru_istemci.dart';
import 'calisma.dart';
import 'sesli_konusma.dart';

/// Ajanların durumunu bildirimlere çevirir:
///
/// - Bir ajan (ya da kurulum) çalışırken kalıcı "çalışıyor" bildirimi ve ön plan
///   servisi açık kalır; telefon kilitlense ya da başka uygulamaya geçilse de
///   Atölye'nin süreci yaşar, köprüden gelen olaylar kaçmaz.
/// - Uygulama ekranda değilken ajan onay isterse ya da işi biterse bildirim
///   gelir; dokununca o oturum açılır.
class BildirimYoneticisi {
  BildirimYoneticisi(this.c) {
    _yasam = AppLifecycleListener(onStateChange: _yasamDegisti);
    c.addListener(_servisiGuncelle);
    c.kurulum.addListener(_servisiGuncelle);
    SesliKonusma.herhangiAcik.addListener(_servisiGuncelle);
    _abone = c.olaylar.listen(_olay);
    Bildirim.dinle(
      acildi: _oturumuAc,
      karar: _karar,
      ses: _ses,
      eylem: (e) => eylem?.call(e),
    );
    unawaited(_acilistaOturum());
  }

  final Calisma c;
  late final AppLifecycleListener _yasam;
  StreamSubscription? _abone;
  bool _onde = true;
  String _sonServis = '';
  final _gosterilen = <int>{};

  /// Oturum → bekleyen onaylar (sırayla); bildirimde ilki gösterilir.
  final _onaylar = <String, List<Map<String, dynamic>>>{};

  /// Bekleyen onaylar (widget da gösterir); değişince [onayDegisti] tetiklenir.
  Map<String, List<Map<String, dynamic>>> get onaylar => _onaylar;
  final onayDegisti = ValueNotifier<int>(0);

  /// Widget düğmeleri ('yeni', 'ara', 'widgetAyar', 'widgetYenile'); WidgetYoneticisi bağlar.
  void Function(String eylem)? eylem;

  /// Bildirim kimliği: widget'tan verilen onay da aynı bildirimi kaldırır.
  static int kimlik(String? oturum) => _kimlik(oturum);

  void dispose() {
    _yasam.dispose();
    c.removeListener(_servisiGuncelle);
    c.kurulum.removeListener(_servisiGuncelle);
    SesliKonusma.herhangiAcik.removeListener(_servisiGuncelle);
    _abone?.cancel();
  }

  void _yasamDegisti(AppLifecycleState s) {
    _onde = s == AppLifecycleState.resumed;
    if (_onde) {
      // Kullanıcı uygulamaya döndü: bekleyen olay bildirimleri artık gereksiz.
      for (final k in _gosterilen) {
        Bildirim.iptal(k);
      }
      _gosterilen.clear();
    }
  }

  static int _kimlik(String? oturum) =>
      oturum == null ? 90 : 100 + (oturum.hashCode & 0x7fff);

  String _baslik(String? oturum) {
    final o = c.oturumlar.where((x) => x['id'] == oturum).firstOrNull;
    return (o?['baslik'] as String?)?.trim().isNotEmpty == true
        ? o!['baslik'] as String
        : 'Oturum';
  }

  // --- kalıcı "çalışıyor" bildirimi ve ön plan servisi

  Future<void> _servisiGuncelle() async {
    final calisanlar = [
      for (final o in c.oturumlar)
        if (o['durum'] == 'calisiyor') o,
    ];
    var calisiyor = true;
    var ilerleme = true;
    final ses = SesliKonusma.herhangiAcik.value;
    String baslik, metin;
    String? oturum;
    if (ses) {
      oturum = c.secili?.id;
      baslik = 'Sesli konuşma sürüyor';
      metin = calisanlar.isNotEmpty
          ? '${ajanAdi(calisanlar.first['ajan'] as String? ?? '')} çalışıyor'
          : 'Ekran kilitliyken de dinliyor';
    } else if (calisanlar.isNotEmpty) {
      final ilk = calisanlar.first;
      oturum = ilk['id'] as String?;
      baslik = calisanlar.length == 1
          ? '${ajanAdi(ilk['ajan'] as String? ?? '')} çalışıyor'
          : '${calisanlar.length} ajan çalışıyor';
      metin = calisanlar.map((o) => o['baslik'] as String? ?? '').join(' · ');
    } else if (c.kurulum.calisiyor) {
      baslik = 'Kurulum sürüyor';
      metin = c.kurulum.adim;
    } else if (c.ayarlar.arkaPlandaAcik && c.baglanti == BaglantiDurumu.bagli) {
      // Boşta ama bağlı: küçük, sessiz bildirim; Atölye arka planda yaşar.
      ilerleme = false;
      baslik = 'Atölye açık';
      final n = c.oturumlar.length;
      metin = n == 0 ? 'Köprüye bağlı' : 'Köprüye bağlı · $n oturum';
    } else {
      calisiyor = false;
      baslik = metin = '';
    }
    final anahtar = '$calisiyor|$ses|$baslik|$metin';
    if (anahtar == _sonServis) return;
    final ilkKez = calisiyor && !_sonServis.startsWith('true');
    _sonServis = anahtar;
    if (ilkKez && !c.ayarlar.bildirimIzniSoruldu) {
      // İlk kez bir iş başladı (kullanıcı ekranda): bildirim iznini bir kez sor.
      c.ayarlar.bildirimIzniSoruldu = true;
      await Bildirim.izinIste();
    }
    await Bildirim.servis(
      calisiyor: calisiyor,
      baslik: baslik,
      metin: metin,
      oturum: oturum,
      ilerleme: ilerleme,
      ses: ses,
    );
  }

  // --- olay bildirimleri (uygulama ekranda değilken)

  /// Köprünün bekleyen onay listesi: elimizdekinin yerine geçer.
  void _esitle(List onaylar) {
    final eski = {
      for (final l in _onaylar.values)
        for (final x in l) '${x['oturum']}|${x['rid']}',
    };
    final eskiOturumlar = _onaylar.keys.toSet();
    _onaylar.clear();
    for (final x in onaylar.whereType<Map>()) {
      final oturum = x['oturum'] as String?;
      if (oturum == null || x['rid'] == null) continue;
      (_onaylar[oturum] ??= []).add(x.cast<String, dynamic>());
    }
    onayDegisti.value++;
    if (_onde) return;
    for (final o in {...eskiOturumlar, ..._onaylar.keys}) {
      final ilk = _onaylar[o]?.firstOrNull;
      // Yeni çıkan ya da kapanan onayların bildirimi güncellenir.
      if (ilk == null || !eski.contains('$o|${ilk['rid']}')) _onayGoster(o);
    }
  }

  void _olay(Map<String, dynamic> e) {
    if (e['ev'] == 'onaylar_esitle') {
      _esitle(e['onaylar'] as List);
      return;
    }
    final oturum = e['oturum'] as String?;
    // Bekleyen onaylar uygulama öndeyken de izlenir: arka plana geçince
    // bildirimden verilebilsin.
    if (oturum != null) {
      if (e['ev'] == 'onay' && e['rid'] != null) {
        final liste = _onaylar[oturum] ??= [];
        // Eşitleme listesinde zaten varsa (kaçan olaylar yeniden gelirken) ekleme.
        if (liste.any((x) => x['rid'] == e['rid'])) return;
        liste.add(e);
        onayDegisti.value++;
      } else if (e['ev'] == 'onay_kapandi') {
        final liste = _onaylar[oturum];
        final ilkti = liste?.firstOrNull?['rid'] == e['rid'];
        liste?.removeWhere((x) => x['rid'] == e['rid']);
        if (liste != null && liste.isEmpty) _onaylar.remove(oturum);
        onayDegisti.value++;
        if (ilkti && !_onde) _onayGoster(oturum);
        return;
      } else if (e['ev'] == 'bitti') {
        if (_onaylar.remove(oturum) != null) onayDegisti.value++;
      }
    }
    if (_onde) return;
    switch (e['ev']) {
      case 'onay':
        if (_onaylar[oturum]?.firstOrNull == e) _onayGoster(oturum);
      case 'bitti':
        final hata = e['hata'] as String?;
        _goster(
          oturum,
          hata == null
              ? 'Tamamlandı · ${_baslik(oturum)}'
              : 'Durdu · ${_baslik(oturum)}',
          hata ?? 'Ajan işini bitirdi. Sonucu görmek için dokun.',
        );
      case 'kurulum' when e['tur'] == 'bitti':
        final basarili = e['kod'] == 0;
        _goster(
          null,
          basarili ? 'Kurulum tamamlandı' : 'Kurulum tamamlanamadı',
          basarili ? 'Atölye hazır.' : 'Ayrıntılar için Atölye\'yi aç.',
        );
      case 'giris' when e['tur'] == 'bitti' && e['basarili'] == true:
        _goster(
          null,
          '${girisAdi(e['ajan'] as String? ?? '')} girişi tamamlandı',
          'Atölye\'ye dönebilirsin.',
        );
    }
  }

  /// Oturumun sıradaki onayı, düğmeleriyle; kalmadıysa bildirim kalkar.
  void _onayGoster(String? oturum) {
    final liste = oturum == null ? null : _onaylar[oturum];
    final e = liste?.firstOrNull;
    if (e == null) {
      Bildirim.iptal(_kimlik(oturum));
      return;
    }
    final kalan = liste!.length > 1 ? ' (+${liste.length - 1})' : '';
    _goster(
      oturum,
      'Onay bekliyor$kalan · ${_baslik(oturum)}',
      '${e['arac'] ?? ''}: ${e['ozet'] ?? ''}'.trim(),
      onemli: true,
      rid: e['rid'] as String?,
    );
  }

  /// Bildirimdeki düğme: kararı köprüye ilet; sıradakini göster.
  Future<void> _karar(String oturum, String rid, String karar) async {
    try {
      await c.istemci.iste('onay', {
        'oturum': oturum,
        'rid': rid,
        'karar': karar,
      });
    } catch (_) {
      _goster(
        oturum,
        'Onay iletilemedi · ${_baslik(oturum)}',
        'Köprüye ulaşılamadı. Onaylamak için dokun.',
        onemli: true,
      );
    }
  }

  void _goster(
    String? oturum,
    String baslik,
    String metin, {
    bool onemli = false,
    String? rid,
  }) {
    final kimlik = _kimlik(oturum);
    _gosterilen.add(kimlik);
    Bildirim.goster(
      kimlik: kimlik,
      baslik: baslik,
      metin: metin,
      oturum: oturum,
      onemli: onemli,
      rid: rid,
    );
  }

  // --- bildirime dokununca oturumu aç

  Future<void> _acilistaOturum() async {
    final oturum = await Bildirim.acilisOturumu();
    if (oturum != null) await _oturumuAc(oturum);
    if (await Bildirim.acilisSes()) _ses();
  }

  /// Kulaklık tuşu, "Konuş" kısayolu ya da bildirim düğmesi.
  Future<void> _ses() async {
    for (var i = 0; i < 40 && c.baglanti != BaglantiDurumu.bagli; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    try {
      await c.sesiAcKapat();
    } catch (_) {}
  }

  Future<void> _oturumuAc(String oturum) async {
    // Uygulama yeni açıldıysa köprüye bağlanmasını bekle.
    for (var i = 0; i < 40 && c.baglanti != BaglantiDurumu.bagli; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await c.oturumuAc(oturum);
  }
}
