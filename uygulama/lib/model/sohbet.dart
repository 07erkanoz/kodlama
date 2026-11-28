import 'dart:async';

import 'package:flutter/foundation.dart';

import '../servis/kopru_istemci.dart';
import 'yanki_secimi.dart';
import 'sesli_konusma.dart';

/// Sohbette görünen bir öğe. Köprünün olaylarından kurulur; geçmiş de canlı
/// akış da aynı [Sohbet.isle] yolundan geçer.
sealed class Oge {
  /// Öğeyi üreten ajan, oturumun ajanından farklıysa (Yankı'da Claude).
  String? kaynak;
}

class KullaniciOge extends Oge {
  KullaniciOge(this.metin, this.ekler);
  final String metin;
  final List<String> ekler;
}

class MetinOge extends Oge {
  MetinOge(this.anahtar, this.metin, {this.akiyor = false});
  final String anahtar;
  String metin;
  bool akiyor;
}

/// Modelin düşünmesi (Claude thinking, Codex reasoning özeti).
class DusunceOge extends Oge {
  DusunceOge(this.anahtar, this.metin, {this.akiyor = false});
  final String anahtar;
  String metin;
  bool akiyor;
  final baslangic = DateTime.now();
  DateTime? bitis;
}

class AracOge extends Oge {
  AracOge(this.aid, this.ad, this.ozet, this.girdi);
  final String aid;
  final String ad;
  final String ozet;
  final String girdi;
  String? cikti;
  bool hata = false;
  bool bitti = false;
}

class OnayOge extends Oge {
  OnayOge(this.rid, this.arac, this.ozet, this.girdi, this.neden);
  final String rid;
  final String arac;
  final String ozet;
  final String girdi;
  final String neden;
  bool kapandi = false;
  String? karar;
}

class DosyaOge extends Oge {
  DosyaOge(this.yol, this.goreli, this.eylem);
  final String yol;
  final String goreli;
  final String eylem;
}

class BittiOge extends Oge {
  BittiOge(this.hata, this.maliyet);
  final String? hata;
  final double? maliyet;
}

class UyariOge extends Oge {
  UyariOge(this.metin, {this.bilgi = false, this.ssh});
  final String metin;

  /// SSH hatasıysa köprünün ayrıntısı (çözüm düğmesi için).
  final Map<String, dynamic>? ssh;

  /// Hata değil, bilgi notu (ör. "İşi yapan: Claude", "Cihaz: ofis").
  final bool bilgi;
}

/// Bir oturumun sohbeti: öğeler, durum, bekleyen onaylar.
class Sohbet extends ChangeNotifier {
  Sohbet(this.istemci, Map<String, dynamic> ozet) : _ozet = ozet {
    _abone = istemci.olaylar.listen((m) {
      if (m['oturum'] == id) isle(m);
    });
  }

  final KopruIstemci istemci;
  Map<String, dynamic> _ozet;
  StreamSubscription? _abone;

  final ogeler = <Oge>[];
  final _metinler = <String, MetinOge>{};
  final _dusunceler = <String, DusunceOge>{};

  /// Canlı izlenen turun başladığı an (geçmişten yüklenince bilinmez).
  DateTime? turBasi;
  final _araclar = <String, AracOge>{};
  final _onaylar = <String, OnayOge>{};
  bool yukleniyor = false;

  /// Dosya panelinde en son bakılan klasör ve sekme: telefonda çekmece her
  /// açılışta yeniden kurulur, kaldığı yerden açılsın diye burada tutulur.
  String? panelKlasoru;
  int panelSekmesi = 0;

  /// Geçmiş yüklenemediyse nedeni (sohbet ekranı "Yeniden dene" gösterir).
  String? yuklemeHatasi;

  /// Başlangıç ekranından gönderilip ulaşmayan ilk mesaj: yazma kutusuna
  /// geri konur ki kaybolmasın.
  ({String metin, String hata})? gonderilemedi;

  String get id => _ozet['id'] as String;
  String get ajan => _ozet['ajan'] as String;
  String get cwd => _ozet['cwd'] as String;
  String get baslik => (_ozet['baslik'] as String?) ?? '';
  String? get sunucu => _ozet['sunucu'] as String?;
  String? get uzakKlasor => _ozet['uzak_klasor'] as String?;
  String get mod => (_ozet['mod'] as String?) ?? 'otomatik';
  String? get model => _ozet['model'] as String?;
  String? get effort => _ozet['effort'] as String?;
  bool get calisiyor => _ozet['durum'] == 'calisiyor';

  /// Projeden bağımsız Asistan oturumu (Codex konuşur, ağır işi Claude yapar).
  bool get asistan => _ozet['asistan'] == true;

  /// Yankı modu: Codex konuşur ve yönetir, işi Claude yapar (Asistan hep böyle).
  bool get yanki => _ozet['yanki'] == true || asistan;

  /// Yankı'daki Claude'un modeli ve düşünme gücü (yoksa Opus, varsayılan güç).
  String? get claudeModel => _ozet['claude_model'] as String?;
  String? get claudeEffort => _ozet['claude_effort'] as String?;

  /// 'claude' ya da 'codex'.
  String get isci => (_ozet['isci'] as String?) ?? 'claude';

  /// Bu sohbetin Yankı seçimleri (ses ajanı oturumun kendi modelidir).
  YankiSecimi get yankiSecimi => YankiSecimi(
    ajanModel: model,
    ajanEffort: effort,
    isci: isci,
    claudeModel: claudeModel,
    claudeEffort: claudeEffort,
    yazili: (_ozet['yazili'] as String?) ?? 'codex',
    yaziliModel: _ozet['yazili_model'] as String?,
    yaziliEffort: _ozet['yazili_effort'] as String?,
    durumNotu: (_ozet['durum_notu'] as String?) ?? 'onemli',
  );

  /// Yankı seçimlerinden değişenleri köprüye yaz. İşi yapan değişince
  /// Codex yeniden başlar, sohbet sürer.
  Future<void> yankiDegistir(YankiSecimi yeni) async {
    final eski = yankiSecimi;
    if (yeni.ajanModel != eski.ajanModel ||
        yeni.ajanEffort != eski.ajanEffort) {
      await ayarla({'model': yeni.ajanModel, 'effort': yeni.ajanEffort});
    }
    final once = eski.kopruAlanlari();
    final fark = {
      for (final e in yeni.kopruAlanlari().entries)
        if (once[e.key] != e.value) e.key: e.value,
    };
    if (fark.isEmpty) return;
    final r = await istemci.iste('yanki_ayar', {'oturum': id, ...fark});
    _ozet = (r['oturum'] as Map).cast<String, dynamic>();
    notifyListeners();
  }

  /// Asistan'ın denetlediği kayıtlı sunucu; yoksa null.
  String? get cihaz => _ozet['cihaz'] as String?;

  /// Seçili cihazda bulunan LifeOS MCP'leri ('lifeos', 'folio').
  List<String> get cihazAraclari =>
      ((_ozet['cihaz_mcp'] as Map?) ?? const {}).keys.cast<String>().toList();

  bool cihazDegisiyor = false;

  /// Asistan'ın cihazını değiştir: köprü o makinede LifeOS ve Folio'yu arar,
  /// bulduklarını SSH üzerinden bağlar. Sesli konuşma açıksa kapanır.
  Future<List<String>> cihazSec(String? cihaz) async {
    cihazDegisiyor = true;
    notifyListeners();
    try {
      if (ses.acik) await ses.bitir();
      final r = await istemci.iste('asistan_cihaz', {
        'oturum': id,
        'cihaz': cihaz,
      });
      _ozet = (r['oturum'] as Map).cast<String, dynamic>();
      return ((r['araclar'] as List?) ?? const []).cast<String>();
    } finally {
      cihazDegisiyor = false;
      notifyListeners();
    }
  }

  /// Bu sohbetin sesli konuşması (Codex oturumlarında; uzak sunucuda da).
  SesliKonusma get ses =>
      _ses ??= SesliKonusma(istemci, id, ajanCalisiyor: () => calisiyor);
  SesliKonusma? _ses;
  bool get sesDestekleniyor => ajan == 'codex';

  /// Bu oturumda değişen ya da üretilen dosyalar, en yenisi önce.
  List<DosyaOge> get dosyalar {
    final gorulen = <String>{};
    return [
      for (final o in ogeler.reversed)
        if (o is DosyaOge && o.eylem != 'silindi' && gorulen.add(o.yol)) o,
    ];
  }

  Future<void> gecmisiYukle() async {
    // Yeniden bağlanınca sessizce yenilenir; yükleme göstergesi yalnız
    // sohbet boşken (ilk açılış) çıkar, kaydırma yeri korunur.
    yukleniyor = ogeler.isEmpty;
    yuklemeHatasi = null;
    notifyListeners();
    try {
      final r = await istemci.iste('gecmis', {'oturum': id});
      _ozet = (r['oturum'] as Map).cast<String, dynamic>();
      ogeler.clear();
      _metinler.clear();
      _dusunceler.clear();
      _araclar.clear();
      _onaylar.clear();
      final bekleyen = ((r['bekleyen'] as List?) ?? const []).toSet();
      for (final e in (r['olaylar'] as List? ?? const [])) {
        isle((e as Map).cast<String, dynamic>(), bildir: false);
      }
      // geçmişte kalan, artık beklenmeyen onaylar kapalı görünsün
      for (final o in _onaylar.values) {
        if (!bekleyen.contains(o.rid)) o.kapandi = true;
      }
    } catch (e) {
      yuklemeHatasi = '$e';
    } finally {
      yukleniyor = false;
      notifyListeners();
    }
  }

  void isle(Map<String, dynamic> e, {bool bildir = true}) {
    final once = ogeler.length;
    _isle(e);
    if (ogeler.length > once && e['kaynak'] is String) {
      for (final o in ogeler.skip(once)) {
        o.kaynak = e['kaynak'] as String;
      }
    }
    if (bildir) notifyListeners();
  }

  void _isle(Map<String, dynamic> e) {
    switch (e['ev']) {
      case 'kullanici':
        ogeler.add(
          KullaniciOge(
            e['metin'] as String? ?? '',
            ((e['ekler'] as List?) ?? const []).cast<String>(),
          ),
        );
      case 'parca':
        _dusunmeyiBitir();
        final anahtar = e['anahtar'] as String? ?? '';
        final var_ = _metinler[anahtar];
        if (var_ != null) {
          var_.metin += e['metin'] as String? ?? '';
        } else {
          final o = MetinOge(
            anahtar,
            e['metin'] as String? ?? '',
            akiyor: true,
          );
          _metinler[anahtar] = o;
          ogeler.add(o);
        }
      case 'metin':
        final anahtar = e['anahtar'] as String? ?? '';
        final var_ = _metinler[anahtar];
        if (var_ != null) {
          var_
            ..metin = e['metin'] as String? ?? ''
            ..akiyor = false;
        } else {
          final o = MetinOge(anahtar, e['metin'] as String? ?? '');
          _metinler[anahtar] = o;
          ogeler.add(o);
        }
      case 'dusunce_parca':
        final anahtar = e['anahtar'] as String? ?? '';
        final var_ = _dusunceler[anahtar];
        if (var_ != null) {
          var_.metin += e['metin'] as String? ?? '';
        } else {
          final o = DusunceOge(
            anahtar,
            e['metin'] as String? ?? '',
            akiyor: true,
          );
          _dusunceler[anahtar] = o;
          ogeler.add(o);
        }
      case 'dusunce':
        final anahtar = e['anahtar'] as String? ?? '';
        final metin = (e['metin'] as String? ?? '').trim();
        final var_ = _dusunceler[anahtar];
        if (var_ != null) {
          var_
            ..metin = metin.isNotEmpty ? metin : var_.metin
            ..akiyor = false
            ..bitis ??= DateTime.now();
          if (var_.metin.trim().isEmpty) {
            ogeler.remove(var_);
            _dusunceler.remove(anahtar);
          }
        } else if (metin.isNotEmpty) {
          final o = DusunceOge(anahtar, metin);
          _dusunceler[anahtar] = o;
          ogeler.add(o);
        }
      case 'arac':
        // araç başladıysa önceki düşünme bitmiştir
        _dusunmeyiBitir();
        final o = AracOge(
          e['aid'] as String? ?? '',
          e['ad'] as String? ?? '?',
          e['ozet'] as String? ?? '',
          e['girdi'] as String? ?? '',
        );
        _araclar[o.aid] = o;
        ogeler.add(o);
      case 'arac_sonuc':
        final o = _araclar[e['aid']];
        if (o != null) {
          o
            ..cikti = e['cikti'] as String?
            ..hata = e['hata'] == true
            ..bitti = true;
        }
      case 'onay':
        final o = OnayOge(
          e['rid'] as String,
          e['arac'] as String? ?? '?',
          e['ozet'] as String? ?? '',
          e['girdi'] as String? ?? '',
          e['neden'] as String? ?? '',
        );
        _onaylar[o.rid] = o;
        ogeler.add(o);
      case 'onay_kapandi':
        _onaylar[e['rid']]?.kapandi = true;
      case 'dosya':
        ogeler.add(
          DosyaOge(
            e['yol'] as String,
            e['goreli'] as String? ?? e['yol'] as String,
            e['eylem'] as String? ?? 'degisti',
          ),
        );
      case 'bitti':
        for (final m in _metinler.values) {
          m.akiyor = false;
        }
        for (final a in _araclar.values) {
          a.bitti = true;
        }
        _dusunmeyiBitir();
        _dusunceler.removeWhere((_, d) {
          final bos = d.metin.trim().isEmpty;
          if (bos) ogeler.remove(d);
          return bos;
        });
        ogeler.add(
          BittiOge(e['hata'] as String?, (e['maliyet'] as num?)?.toDouble()),
        );
      case 'uyari':
        ogeler.add(
          UyariOge(
            e['metin'] as String? ?? '',
            bilgi: e['bilgi'] == true,
            ssh: (e['ssh'] as Map?)?.cast<String, dynamic>(),
          ),
        );
      case 'durum':
        if (e['durum'] == 'calisiyor' && !calisiyor) turBasi = DateTime.now();
        _ozet = {..._ozet, 'durum': e['durum']};
      case 'oturum':
        _ozet = (e['ozet'] as Map).cast<String, dynamic>();
      default:
        return;
    }
  }

  void _dusunmeyiBitir() {
    for (final d in _dusunceler.values) {
      if (d.akiyor) {
        d
          ..akiyor = false
          ..bitis = DateTime.now();
      }
    }
  }

  /// Ajanın şu an ne yaptığı, kısa bir cümleyle; çalışmıyorsa null.
  ({String metin, String? ayrinti, bool onay})? get etkinlik {
    if (!calisiyor) return null;
    for (final o in ogeler.reversed) {
      switch (o) {
        case OnayOge(kapandi: false, :final ozet):
          return (metin: 'Onayın bekleniyor', ayrinti: ozet, onay: true);
        case AracOge(bitti: false, :final ad, :final ozet):
          return (metin: aracEylemi(ad), ayrinti: ozet, onay: false);
        case DusunceOge(akiyor: true):
          return (metin: 'Düşünüyor', ayrinti: null, onay: false);
        case MetinOge(akiyor: true):
          return (metin: 'Yazıyor', ayrinti: null, onay: false);
        case KullaniciOge():
          return (metin: 'Başlıyor', ayrinti: null, onay: false);
        default:
          return (
            metin: 'Sıradaki adımı düşünüyor',
            ayrinti: null,
            onay: false,
          );
      }
    }
    return (metin: 'Çalışıyor', ayrinti: null, onay: false);
  }

  Future<void> gonder(String metin, {List<String> ekler = const []}) async {
    final onceki = _ozet['durum'];
    turBasi = DateTime.now();
    _ozet = {..._ozet, 'durum': 'calisiyor'};
    notifyListeners();
    try {
      await istemci.iste('gonder', {
        'oturum': id,
        'metin': metin,
        'ekler': ekler,
      });
    } catch (_) {
      // Ulaşmadı: "çalışıyor" göstergesi takılı kalmasın.
      _ozet = {..._ozet, 'durum': onceki};
      notifyListeners();
      rethrow;
    }
  }

  Future<void> durdur() => istemci.iste('durdur', {'oturum': id});

  Future<void> onayla(OnayOge o, String karar) async {
    o
      ..karar = karar
      ..kapandi = true;
    notifyListeners();
    try {
      await istemci.iste('onay', {'oturum': id, 'rid': o.rid, 'karar': karar});
    } catch (_) {
      // Ulaşmadı: kart yeniden açılsın, ajan sonsuza dek beklemesin.
      o
        ..karar = null
        ..kapandi = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> modDegistir(String yeni) => ayarla({'mod': yeni});

  /// Model, effort ya da çalışma biçimini değiştirir; null değer CLI'ın
  /// varsayılanına döner. Ajan süreci yeni ayarla, oturum sürdürülerek açılır.
  Future<void> ayarla(Map<String, Object?> degisiklik) async {
    final r = await istemci.iste('ayar', {'oturum': id, ...degisiklik});
    _ozet = (r['oturum'] as Map).cast<String, dynamic>();
    notifyListeners();
  }

  Future<String> ekYukle(String ad, String base64Veri) async {
    final r = await istemci.iste('yukle', {
      'oturum': id,
      'ad': ad,
      'veri': base64Veri,
    });
    return r['yol'] as String;
  }

  @override
  void dispose() {
    _abone?.cancel();
    _ses?.dispose();
    super.dispose();
  }
}

/// Araç adına göre "ne yapıyor" cümlesi.
String aracEylemi(String ad) => switch (ad) {
  'Bash' || 'Komut' => 'Komut çalıştırıyor',
  'Read' => 'Dosya okuyor',
  'Write' => 'Dosya yazıyor',
  'Edit' ||
  'MultiEdit' ||
  'Düzenle' ||
  'Dosya değişikliği' => 'Dosya düzenliyor',
  'NotebookEdit' => 'Defteri düzenliyor',
  'Glob' => 'Dosya arıyor',
  'Grep' => 'Kodda arıyor',
  'WebSearch' || 'webSearch' => 'Web\'de arıyor',
  'WebFetch' => 'Sayfa okuyor',
  'Task' || 'Agent' => 'Alt görev yürütüyor',
  'TodoWrite' => 'Planı güncelliyor',
  'mcpToolCall' || 'dynamicToolCall' => 'Araç kullanıyor',
  _ => '$ad kullanıyor',
};
