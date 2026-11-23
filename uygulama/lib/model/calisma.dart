import 'dart:async';

import 'package:flutter/foundation.dart';

import '../servis/ayarlar.dart';
import '../servis/kopru_istemci.dart';
import '../servis/termux.dart';
import 'sohbet.dart';

enum ThemeModeSecimi { sistem, acik, koyu }

/// Uygulamanın tamamının durumu: köprü bağlantısı, oturumlar, seçili sohbet
/// ve önizlenen dosya. Ekran katlanıp açıldığında ya da döndüğünde düzen
/// değişir ama bu nesne aynı kalır; sohbet yarıda kesilmez.
class Calisma extends ChangeNotifier {
  Calisma(this.ayarlar)
    : istemci = KopruIstemci(port: ayarlar.port, token: ayarlar.token) {
    istemci.durum.addListener(_durumDegisti);
    _olayAbone = istemci.olaylar.listen(_olay);
  }

  final Ayarlar ayarlar;
  KopruIstemci istemci;
  StreamSubscription? _olayAbone;

  List<Map<String, dynamic>> oturumlar = [];
  List<Map<String, dynamic>> ajanlar = [];
  List<Map<String, dynamic>> projeler = [];
  List<Map<String, dynamic>> sunucular = [];

  /// Ajana göre seçilebilecek modeller (köprüden, bir kez yüklenir).
  final modeller = <String, List<Map<String, dynamic>>>{};
  Map<String, String> effortAdlari = const {};
  final _modelYukleniyor = <String>{};
  Map<String, List<dynamic>> kotalar = {};
  String? kok;
  Sohbet? secili;
  String? onizlenen;

  /// Geniş ekranda sağdaki dosya paneli açık mı.
  bool dosyaPaneli = true;
  String? hata;

  BaglantiDurumu get baglanti => istemci.durum.value;

  /// Bağlantı ayarları değişti (elle bağlanma ekranı): istemciyi yenile.
  Future<void> yenidenKur() async {
    await istemci.kapat();
    istemci.durum.removeListener(_durumDegisti);
    await _olayAbone?.cancel();
    secili?.dispose();
    secili = null;
    istemci = KopruIstemci(port: ayarlar.port, token: ayarlar.token);
    istemci.durum.addListener(_durumDegisti);
    _olayAbone = istemci.olaylar.listen(_olay);
    await baslat();
  }

  Future<void> baslat() async {
    if (Termux.destekleniyor && await Termux.komutIzniVar()) {
      // Köprü kapalıysa Termux'ta arka planda aç; açıksa bir şey yapmaz.
      try {
        await Termux.kopruyuBaslat();
      } catch (_) {}
    }
    await istemci.baglan();
  }

  void _durumDegisti() {
    if (baglanti == BaglantiDurumu.bagli) yenile();
    notifyListeners();
  }

  void _olay(Map<String, dynamic> e) {
    switch (e['ev']) {
      case 'kota':
        kotalar = {...kotalar, e['ajan'] as String: e['pencereler'] as List};
        notifyListeners();
      case 'oturum':
        final i = oturumlar.indexWhere((o) => o['id'] == e['oturum']);
        if (i >= 0) {
          oturumlar[i] = (e['ozet'] as Map).cast<String, dynamic>();
          notifyListeners();
        }
      case 'durum':
        final i = oturumlar.indexWhere((o) => o['id'] == e['oturum']);
        if (i >= 0) {
          oturumlar[i] = {...oturumlar[i], 'durum': e['durum']};
          notifyListeners();
        }
    }
  }

  Future<void> yenile() async {
    try {
      final d = await istemci.iste('durum');
      ajanlar = ((d['ajanlar'] as List?) ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      kotalar = ((d['kotalar'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as List),
      );
      kok = d['kok'] as String?;
      final p = await istemci.iste('projeler');
      projeler = ((p['projeler'] as List?) ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      try {
        final ssh = await istemci.iste('ssh_durum');
        sunucular = ((ssh['sunucular'] as List?) ?? const [])
            .cast<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
      } catch (_) {}
      final o = await istemci.iste('oturumlar');
      oturumlar = ((o['oturumlar'] as List?) ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      hata = null;
    } catch (e) {
      hata = e.toString();
    }
    notifyListeners();
  }

  Future<void> sec(Map<String, dynamic> ozet) async {
    if (secili?.id == ozet['id']) return;
    secili?.dispose();
    final s = Sohbet(istemci, ozet);
    secili = s;
    onizlenen = null;
    notifyListeners();
    await s.gecmisiYukle();
  }

  Future<void> yeniOturum({
    required String ajan,
    required String cwd,
    String mod = 'otomatik',
    String? sunucu,
    String? uzakKlasor,
    String? model,
    String? effort,
  }) async {
    final r = await istemci.iste('oturum_ac', {
      'model': ?model,
      'effort': ?effort,
      'ajan': ajan,
      'cwd': cwd,
      'mod': mod,
      'sunucu': ?sunucu,
      'uzak_klasor': ?uzakKlasor,
    });
    final ozet = (r['oturum'] as Map).cast<String, dynamic>();
    oturumlar = [ozet, ...oturumlar];
    await sec(ozet);
  }

  Future<void> modelleriYukle(String ajan) async {
    if (modeller.containsKey(ajan) || !_modelYukleniyor.add(ajan)) return;
    try {
      final r = await istemci.iste('modeller', {'ajan': ajan});
      modeller[ajan] = ((r['modeller'] as List?) ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      effortAdlari = ((r['effort_adlari'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as String),
      );
      notifyListeners();
    } catch (_) {
      // bağlantı yoksa sonra yeniden denenir
    } finally {
      _modelYukleniyor.remove(ajan);
    }
  }

  /// Seçili oturumdan çık: başlangıç ekranına dön.
  void baslangica() {
    secili?.dispose();
    secili = null;
    onizlenen = null;
    notifyListeners();
  }

  /// Başlangıç ekranından tek adımda: oturumu aç ve ilk mesajı gönder.
  Future<void> hizliBaslat({
    required String ajan,
    required String cwd,
    required String metin,
    String mod = 'otomatik',
    String? sunucu,
    String? uzakKlasor,
    String? model,
    String? effort,
  }) async {
    await yeniOturum(
      model: model,
      effort: effort,
      ajan: ajan,
      cwd: cwd,
      mod: mod,
      sunucu: sunucu,
      uzakKlasor: uzakKlasor,
    );
    await secili?.gonder(metin);
  }

  Future<String> projeOlustur(String ad) async {
    final r = await istemci.iste('proje_ac', {'ad': ad});
    await yenile();
    return r['yol'] as String;
  }

  ThemeModeSecimi get tema => ThemeModeSecimi.values.firstWhere(
    (t) => t.name == ayarlar.tema,
    orElse: () => ThemeModeSecimi.sistem,
  );

  void temaDegistir(ThemeModeSecimi t) {
    ayarlar.tema = t.name;
    notifyListeners();
  }

  Future<void> oturumSil(String id) async {
    await istemci.iste('oturum_sil', {'oturum': id});
    oturumlar.removeWhere((o) => o['id'] == id);
    if (secili?.id == id) {
      secili?.dispose();
      secili = null;
    }
    notifyListeners();
  }

  void dosyaPaneliDegistir() {
    dosyaPaneli = !dosyaPaneli;
    if (!dosyaPaneli) onizlenen = null;
    notifyListeners();
  }

  void onizle(String? yol) {
    onizlenen = yol;
    notifyListeners();
  }

  @override
  void dispose() {
    _olayAbone?.cancel();
    secili?.dispose();
    istemci.kapat();
    super.dispose();
  }
}
