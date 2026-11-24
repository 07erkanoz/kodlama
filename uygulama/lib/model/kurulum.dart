import 'package:flutter/foundation.dart';

class KurulumSatiri {
  const KurulumSatiri(this.tur, this.metin);

  /// 'adim', 'tamam', 'uyari' ya da 'satir'.
  final String tur;
  final String metin;
}

/// Köprünün çalıştırdığı kurulum betiğinin (kur.sh) durumu. Olaylar köprüden
/// canlı gelir; ekran açılırken `kur_durum` ile o ana kadarki hâli yüklenir.
class KurulumDurumu extends ChangeNotifier {
  static const enFazlaSatir = 300;

  /// Hiç başlatıldı mı (bu oturumda ya da köprüde)?
  bool basladi = false;
  bool calisiyor = false;
  bool bitti = false;
  int? kod;
  String adim = '';
  List<String> adimlar = [];
  List<String> ajanlar = [];
  String asama = '';
  final satirlar = <KurulumSatiri>[];

  bool get basarili => bitti && kod == 0;
  bool get basarisiz => bitti && kod != 0;

  void sifirla() {
    basladi = false;
    calisiyor = false;
    bitti = false;
    kod = null;
    adim = '';
    adimlar = [];
    ajanlar = [];
    asama = '';
    satirlar.clear();
    notifyListeners();
  }

  void _ekle(String tur, String metin) {
    satirlar.add(KurulumSatiri(tur, metin));
    if (satirlar.length > enFazlaSatir) satirlar.removeAt(0);
  }

  void isle(Map<String, dynamic> e) {
    final metin = e['metin'] as String? ?? '';
    switch (e['tur']) {
      case 'basladi':
        sifirla();
        basladi = true;
        calisiyor = true;
        ajanlar = ((e['ajanlar'] as List?) ?? const []).cast<String>();
        asama = e['asama'] as String? ?? '';
      case 'adim':
        adim = metin;
        adimlar = [...adimlar, metin];
        _ekle('adim', metin);
      case 'tamam' || 'uyari' || 'satir':
        _ekle(e['tur'] as String, metin);
      case 'bitti':
        calisiyor = false;
        bitti = true;
        kod = (e['kod'] as num?)?.toInt();
      default:
        return;
    }
    notifyListeners();
  }

  /// Köprünün `kur_durum` yanıtından (ekran sonradan açıldıysa).
  void yukle(Map<String, dynamic> d) {
    if (d['var'] != true) return;
    basladi = true;
    calisiyor = d['calisiyor'] == true;
    bitti = d['bitti'] == true;
    kod = (d['kod'] as num?)?.toInt();
    adim = d['adim'] as String? ?? '';
    adimlar = ((d['adimlar'] as List?) ?? const []).cast<String>();
    ajanlar = ((d['ajanlar'] as List?) ?? const []).cast<String>();
    asama = d['asama'] as String? ?? '';
    satirlar
      ..clear()
      ..addAll(
        ((d['satirlar'] as List?) ?? const []).cast<Map>().map(
          (m) => KurulumSatiri(
            m['tur'] as String? ?? 'satir',
            m['metin'] as String? ?? '',
          ),
        ),
      );
    notifyListeners();
  }
}

/// Bir ajanın hesabına giriş akışı. Köprü CLI'ın giriş komutunu çalıştırır;
/// adres ve (Codex'te) cihaz kodu buraya gelir, hesap girişi tarayıcıda yapılır.
class GirisDurumu extends ChangeNotifier {
  String? ajan;
  bool calisiyor = false;
  String? url;
  String? kod;
  bool kodIste = false;
  bool? basarili;
  String? hata;

  void baslat(String yeniAjan) {
    ajan = yeniAjan;
    calisiyor = true;
    url = null;
    kod = null;
    kodIste = false;
    basarili = null;
    hata = null;
    notifyListeners();
  }

  /// Başlatılamadı (CLI kurulu değil, bağlantı yok…).
  void basarisiz(String neden) {
    calisiyor = false;
    basarili = false;
    hata = neden;
    notifyListeners();
  }

  void isle(Map<String, dynamic> e) {
    if (ajan != null && e['ajan'] != null && e['ajan'] != ajan) return;
    switch (e['tur']) {
      case 'url':
        url = e['url'] as String?;
      case 'kod':
        kod = e['kod'] as String?;
      case 'kod_iste':
        kodIste = true;
      case 'bitti':
        calisiyor = false;
        basarili = e['basarili'] == true;
        hata = e['hata'] as String?;
      default:
        return;
    }
    notifyListeners();
  }
}
