import 'dart:async';

import 'package:flutter/widgets.dart';

import '../arayuz/ortak.dart';
import '../servis/bildirim.dart';
import '../servis/kopru_istemci.dart';
import 'calisma.dart';

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
    _abone = c.olaylar.listen(_olay);
    Bildirim.acilinca(_oturumuAc);
    unawaited(_acilistaOturum());
  }

  final Calisma c;
  late final AppLifecycleListener _yasam;
  StreamSubscription? _abone;
  bool _onde = true;
  String _sonServis = '';
  final _gosterilen = <int>{};

  void dispose() {
    _yasam.dispose();
    c.removeListener(_servisiGuncelle);
    c.kurulum.removeListener(_servisiGuncelle);
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
    String baslik, metin;
    String? oturum;
    if (calisanlar.isNotEmpty) {
      final ilk = calisanlar.first;
      oturum = ilk['id'] as String?;
      baslik = calisanlar.length == 1
          ? '${ajanAdi(ilk['ajan'] as String? ?? '')} çalışıyor'
          : '${calisanlar.length} ajan çalışıyor';
      metin = calisanlar.map((o) => o['baslik'] as String? ?? '').join(' · ');
    } else if (c.kurulum.calisiyor) {
      baslik = 'Kurulum sürüyor';
      metin = c.kurulum.adim;
    } else {
      calisiyor = false;
      baslik = metin = '';
    }
    final anahtar = '$calisiyor|$baslik|$metin';
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
    );
  }

  // --- olay bildirimleri (uygulama ekranda değilken)

  void _olay(Map<String, dynamic> e) {
    if (_onde) return;
    final oturum = e['oturum'] as String?;
    switch (e['ev']) {
      case 'onay':
        _goster(
          oturum,
          'Onay bekliyor · ${_baslik(oturum)}',
          '${e['arac'] ?? ''}: ${e['ozet'] ?? ''}'.trim(),
          onemli: true,
        );
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
          basarili
              ? 'Atölye hazır.'
              : 'Ayrıntılar için Atölye\'yi aç.',
        );
      case 'giris' when e['tur'] == 'bitti' && e['basarili'] == true:
        _goster(
          null,
          '${girisAdi(e['ajan'] as String? ?? '')} girişi tamamlandı',
          'Atölye\'ye dönebilirsin.',
        );
    }
  }

  void _goster(
    String? oturum,
    String baslik,
    String metin, {
    bool onemli = false,
  }) {
    final kimlik = _kimlik(oturum);
    _gosterilen.add(kimlik);
    Bildirim.goster(
      kimlik: kimlik,
      baslik: baslik,
      metin: metin,
      oturum: oturum,
      onemli: onemli,
    );
  }

  // --- bildirime dokununca oturumu aç

  Future<void> _acilistaOturum() async {
    final oturum = await Bildirim.acilisOturumu();
    if (oturum != null) await _oturumuAc(oturum);
  }

  Future<void> _oturumuAc(String oturum) async {
    // Uygulama yeni açıldıysa köprüye bağlanmasını bekle.
    for (var i = 0; i < 40 && c.baglanti != BaglantiDurumu.bagli; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await c.oturumuAc(oturum);
  }
}
