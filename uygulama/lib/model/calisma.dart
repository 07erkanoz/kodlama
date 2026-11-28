import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../servis/ayarlar.dart';
import '../servis/kopru_istemci.dart';
import 'yanki_secimi.dart';
import '../servis/kurulum_sunucusu.dart';
import '../servis/paylasim.dart';
import '../servis/termux.dart';
import '../servis/yerel_dosya.dart';
import 'kurulum.dart';
import 'sesli_konusma.dart';
import 'sohbet.dart';
import 'terminal_oturumu.dart';

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

  /// Bu uygulamanın beklediği en düşük köprü sürümü. Köprüye yeni bir işlem
  /// eklenince artırılır; telefondaki köprü daha eskiyse güncelleme önerilir.
  static const gerekenKopruSurumu = '0.12.0';
  String? kopruSurumu;
  bool kopruGuncelleniyor = false;
  KurulumSunucusu? _kurulumSunucusu;

  /// Köprünün söylediği yetenekler ('kur', 'giris', 'kopru_guncelle'…). Eski
  /// köprüde liste yoktur: uygulama o zaman eski yola (Termux penceresi) düşer.
  Set<String> kopruYetenekleri = {};
  bool yetenek(String ad) => kopruYetenekleri.contains(ad);

  /// Köprüde çalışan kurulum betiği ve ajan girişi: canlı olaylarla güncellenir.
  final kurulum = KurulumDurumu();

  /// Köprünün bütün olayları; istemci yeniden kurulsa da aynı akış.
  final _olayAkisi = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get olaylar => _olayAkisi.stream;
  bool _baglanmisti = false;
  final giris = GirisDurumu();

  bool get kopruEski {
    final s = kopruSurumu;
    if (s == null) return false;
    List<int> p(String v) =>
        v.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final a = p(s), b = p(gerekenKopruSurumu);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }

  List<Map<String, dynamic>> sunucular = [];

  /// Ajana göre seçilebilecek modeller (köprüden, bir kez yüklenir).
  final modeller = <String, List<Map<String, dynamic>>>{};
  Map<String, String> effortAdlari = const {};
  final _modelYukleniyor = <String>{};
  final _modelHatasi = <String, DateTime>{};
  Map<String, List<dynamic>> kotalar = {};
  String? kok;
  Sohbet? secili;

  /// Paylaş menüsünden gelip hedefi seçilmiş, henüz yazma kutusuna alınmamış
  /// içerik: açık sohbet ya da başlangıç ekranı alır ve boşaltır.
  final paylasim = ValueNotifier<Paylasim?>(null);
  String? onizlenen;

  /// Geniş ekranda sağdaki dosya paneli açık mı.
  late bool dosyaPaneli = ayarlar.dosyaPaneli;

  /// Orta ve geniş ekranda soldaki oturum listesi açık mı.
  late bool kenarCubugu = ayarlar.kenarCubugu;
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
    if (baglanti == BaglantiDurumu.bagli) {
      yenile();
      // Bağlantı koptuysa (telefon uyudu, köprü yeniden başladı) arada kaçan
      // olaylar açık sohbete geçmiştan geri yüklenir.
      if (_baglanmisti) secili?.gecmisiYukle();
      _baglanmisti = true;
    }
    notifyListeners();
  }

  void _olay(Map<String, dynamic> e) {
    _olayAkisi.add(e);
    // Başka yerden (zamanlayıcı, başka istemci) açılmış bir oturumdan olay:
    // listeyi tazele ki widget ve bildirimler adını, durumunu bilsin.
    final oid = e['oturum'];
    if (oid is String &&
        e['ev'] != 'oturum' &&
        !oturumlar.any((o) => o['id'] == oid)) {
      _bilinmeyenOturum();
    }
    switch (e['ev']) {
      case 'kota':
        kotalar = {...kotalar, e['ajan'] as String: e['pencereler'] as List};
        notifyListeners();
      case 'kurulum':
        kurulum.isle(e);
        // Kurulum bitince ajanların kurulu/sürüm bilgisi değişmiştir.
        if (e['tur'] == 'bitti') yenile();
      case 'giris':
        giris.isle(e);
        if (e['tur'] == 'bitti') yenile();
      case 'oturum':
        final i = oturumlar.indexWhere((o) => o['id'] == e['oturum']);
        if (i >= 0) {
          oturumlar[i] = (e['ozet'] as Map).cast<String, dynamic>();
          notifyListeners();
        } else if (e['yeni'] == true && e['ozet'] is Map) {
          // Köprünün kendi açtığı oturum (zamanlanmış iş): listenin başına.
          oturumlar = [
            (e['ozet'] as Map).cast<String, dynamic>(),
            ...oturumlar,
          ];
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

  DateTime _sonTazeleme = DateTime(0);

  /// Tanınmayan oturumdan gelen olaylarda en çok 5 saniyede bir yenile.
  void _bilinmeyenOturum() {
    final simdi = DateTime.now();
    if (simdi.difference(_sonTazeleme) < const Duration(seconds: 5)) return;
    _sonTazeleme = simdi;
    unawaited(yenile());
  }

  Future<void> yenile() async {
    try {
      final d = await istemci.iste('durum');
      kopruSurumu = d['surum'] as String?;
      kopruYetenekleri = ((d['yetenekler'] as List?) ?? const [])
          .cast<String>()
          .toSet();
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

  /// Kimliği bilinen oturumu aç (bildirime dokununca); listede yoksa önce tazele.
  Future<void> oturumuAc(String id) async {
    var ozet = oturumlar.where((o) => o['id'] == id).firstOrNull;
    if (ozet == null) {
      await yenile();
      ozet = oturumlar.where((o) => o['id'] == id).firstOrNull;
    }
    if (ozet != null) await sec(ozet);
  }

  Future<void> sec(Map<String, dynamic> ozet) async {
    if (secili?.id == ozet['id']) {
      // Aynı oturum: geçmiş yüklenememişse yeniden dene.
      if (secili!.yuklemeHatasi != null) await secili!.gecmisiYukle();
      return;
    }
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
    bool yanki = false,
  }) async {
    final r = await istemci.iste('oturum_ac', {
      'model': ?model,
      'effort': ?effort,
      if (yanki) 'yanki': true,
      if (yanki) ...YankiSecimi.varsayilan(ayarlar).kopruAlanlari(),
      'ajan': ajan,
      'cwd': cwd,
      'mod': mod,
      'sunucu': ?sunucu,
      'uzak_klasor': ?uzakKlasor,
    });
    final ozet = (r['oturum'] as Map).cast<String, dynamic>();
    oturumlar = [ozet, ...oturumlar];
    await sec(ozet);
    if (yanki) await _yankiCihaziBagla();
  }

  /// [s]'de yapılan işi öbür ajana (Claude ↔ Codex) aynı klasörde
  /// inceletir: yeni bir oturum açılır ve inceleme isteği gönderilir.
  Future<void> inceletme(Sohbet s, String ozet) async {
    final hedef = s.ajan == 'claude' ? 'codex' : 'claude';
    final kim = s.ajan == 'claude' ? 'Claude Code' : 'Codex';
    final kisa = ozet.length > 6000 ? '${ozet.substring(0, 6000)}…' : ozet;
    await yeniOturum(
      ajan: hedef,
      cwd: s.cwd,
      mod: 'sor', // inceleyen okur; değiştireceği bir şey olursa sorar
      sunucu: s.sunucu,
      uzakKlasor: s.uzakKlasor,
    );
    await secili?.gonder(
      'Bu projede $kim az önce bir iş yaptı. Yaptığı değişiklikleri bağımsız '
      'olarak incele: önce `git status` ve `git diff` ile neyin değiştiğine bak, '
      'gerekirse dosyaları oku. Hataları, eksik kalan yerleri, güvenlik '
      'sorunlarını ve test edilmemiş durumları önem sırasıyla, dosya ve satır '
      'vererek listele. Kod değiştirme; yalnız bulguları yaz.'
      '${kisa.trim().isEmpty ? '' : '\n\n$kim yaptığını şöyle özetledi:\n$kisa'}',
    );
  }

  /// Asistan'ı aç: varsa en son Asistan oturumu, yoksa yenisi (Codex).
  /// Asistan oturumları, en yenisi önce (başlangıçtaki geçmiş listesi).
  List<Map<String, dynamic>> get asistanOturumlari => [
    for (final o in oturumlar)
      if (o['asistan'] == true) o,
  ];

  /// Her dokunuşta yeni bir Asistan oturumu açar; eskileri geçmişten açılır.
  Future<void> asistanAc() async {
    final y = YankiSecimi.varsayilan(ayarlar);
    final r = await istemci.iste('oturum_ac', {
      'ajan': 'codex',
      'asistan': true,
      ...y.kopruAlanlari(),
      'model': ?y.ajanModel,
      'effort': ?y.ajanEffort,
    });
    final ozet = (r['oturum'] as Map).cast<String, dynamic>();
    oturumlar = [ozet, ...oturumlar];
    await sec(ozet);
    await _yankiCihaziBagla();
  }

  /// Yeni bir Yankı/Asistan oturumuna son seçilen cihazı bağla. Bağlanamazsa
  /// oturum cihazsız kalır; çip "Cihaz yok" gösterir, ajan da bunu bilir.
  Future<void> _yankiCihaziBagla() async {
    final s = secili;
    final d = ayarlar.yankiCihaz;
    if (s == null || !s.yanki || s.cihaz != null || d == null) return;
    if (!sunucular.any((x) => x['ad'] == d)) return;
    try {
      await s.cihazSec(d);
    } catch (_) {}
  }

  Future<void> modelleriYukle(String ajan) async {
    if (modeller.containsKey(ajan)) return;
    final hata = _modelHatasi[ajan];
    if (hata != null && DateTime.now().difference(hata).inSeconds < 60) return;
    if (!_modelYukleniyor.add(ajan)) return;
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
      // eski köprü ya da bağlantı yok: yerleşik liste kullanılır, bir dakika
      // sonra yeniden denenir
      _modelHatasi[ajan] = DateTime.now();
    } finally {
      _modelYukleniyor.remove(ajan);
    }
  }

  Future<KurulumSunucusu> _sunucu() async {
    final s = _kurulumSunucusu ??= KurulumSunucusu();
    s
      ..token = ayarlar.token
      ..ajanlar = ayarlar.ajanlar;
    await s.baslat();
    return s;
  }

  /// Sihirbazın kullandığı, kurulum betiğini ve köprü dosyasını sunan yerel sunucu.
  Future<KurulumSunucusu> kurulumSunucusu() => _sunucu();

  Future<void> kurulumSunucusunuDurdur() async => _kurulumSunucusu?.durdur();

  /// Telefondaki köprüyü bu uygulamanın içindeki sürümle değiştirip yeniden
  /// başlatır. Köprü yeniyse (`kopru_guncelle` yeteneği) bunu köprünün kendisi
  /// yapar; eskiyse Termux'a komut gönderilir (izin yoksa kopyala-yapıştır).
  /// Yeni köprüye bağlanınca true döner.
  Future<bool> kopruyuGuncelle() async {
    if (kopruGuncelleniyor) return false;
    kopruGuncelleniyor = true;
    notifyListeners();
    try {
      if (yetenek('kopru_guncelle')) {
        final kopru = await rootBundle.loadString(
          'assets/kurulum/atolye_kopru.py',
        );
        final rehber = await rootBundle.loadString(
          'assets/kurulum/termux_rehberi.md',
        );
        await istemci.iste('kopru_guncelle', {
          'kopru': kopru,
          'rehber': rehber,
        });
      } else if (Termux.destekleniyor) {
        final komut = (await _sunucu()).guncellemeKomutu();
        if (await Termux.komutIzniVar()) {
          await Termux.calistir(
            '${Termux.prefix}/bin/bash',
            args: ['-lc', komut],
          );
        } else {
          await Termux.terminaldeAc(komut);
        }
      } else {
        return false;
      }
      // köprü kapanıp açılır; istemci kendiliğinden yeniden bağlanır
      for (var i = 0; i < 90; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (baglanti == BaglantiDurumu.bagli) {
          await yenile();
          if (!kopruEski) {
            modeller.clear();
            _modelHatasi.clear();
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      hata = '$e';
      return false;
    } finally {
      kopruGuncelleniyor = false;
      notifyListeners();
    }
  }

  /// Termux'ta kurulum komutunu açar (eski yol: köprü yenisi değilse ya da
  /// uygulama içi kurulum çalışmazsa). [ajanlar] verilirse yalnız onlar.
  Future<bool> kurulumuYenile({List<String>? ajanlar}) async {
    final secilen = ajanlar ?? ayarlar.ajanlar;
    ayarlar.ajanlar = {...ayarlar.ajanlar, ...secilen}.toList();
    final komut = (await _sunucu()).komut(
      token: ayarlar.token,
      ajanlar: secilen,
    );
    return Termux.terminaldeAc(komut);
  }

  /// Geliştirme araçlarını ve [ajanlar]ı köprü üzerinden kurar; çıktı
  /// [kurulum]da canlı akar, Termux açılmaz. Köprü eskiyse (`kur` yeteneği
  /// yok) Termux penceresine düşer ve false döner.
  Future<bool> kurulumuBaslat({
    required List<String> ajanlar,
    String asama = 'paketler',
  }) async {
    if (!yetenek('kur')) {
      await kurulumuYenile(ajanlar: ajanlar);
      return false;
    }
    ayarlar.ajanlar = {...ayarlar.ajanlar, ...ajanlar}.toList();
    final betik = await rootBundle.loadString('assets/kurulum/kur.sh');
    kurulum.sifirla();
    await istemci.iste('kur', {
      'betik': betik,
      'ajanlar': ajanlar,
      'asama': asama,
    });
    return true;
  }

  Future<void> kurulumuIptalEt() async {
    try {
      await istemci.iste('kur_iptal');
    } catch (_) {}
  }

  /// Ekran sonradan açıldıysa köprüdeki kurulumun şu anki durumunu al.
  Future<void> kurulumDurumunuYukle() async {
    if (!yetenek('kur')) return;
    try {
      kurulum.yukle(await istemci.iste('kur_durum'));
    } catch (_) {}
  }

  /// Ajanın hesap girişini köprüde başlatır; adres ve kod [giris]e gelir.
  Future<void> girisBaslat(String ajan) async {
    giris.baslat(ajan);
    try {
      await istemci.iste('giris_baslat', {'ajan': ajan});
    } catch (e) {
      giris.basarisiz('$e');
    }
  }

  Future<void> girisKodGonder(String kod) async {
    try {
      await istemci.iste('giris_kod', {'kod': kod});
    } catch (e) {
      giris.basarisiz('$e');
    }
  }

  Future<void> girisIptalEt() async {
    try {
      await istemci.iste('giris_iptal');
    } catch (_) {}
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
    bool yanki = false,
    List<({String ad, String yol, int boyut})> yerelEkler = const [],
  }) async {
    await yeniOturum(
      model: model,
      effort: effort,
      yanki: yanki,
      ajan: ajan,
      cwd: cwd,
      mod: mod,
      sunucu: sunucu,
      uzakKlasor: uzakKlasor,
    );
    final s = secili;
    if (s == null) return;
    try {
      final ekler = <String>[];
      for (final e in yerelEkler) {
        ekler.add(
          await s.ekYukle(e.ad, base64Encode(await yerelDosyaOku(e.yol))),
        );
      }
      await s.gonder(metin, ekler: ekler);
    } catch (e) {
      // Oturum açıldı ama mesaj ulaşmadı: başlangıç ekranı kapandığı için
      // hata orada gösterilemez; metin sohbetin yazma kutusuna geri konur.
      s.gonderilemedi = (metin: metin, hata: '$e');
      notifyListeners();
    }
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
    ayarlar.dosyaPaneli = dosyaPaneli;
    if (!dosyaPaneli) onizlenen = null;
    notifyListeners();
  }

  /// Proje klasörü başına bir terminal; sayfa kapanınca da yaşar.
  final _terminaller = <String, TerminalOturumu>{};
  TerminalOturumu terminal(String cwd) =>
      _terminaller[cwd] ??= TerminalOturumu(istemci, cwd);

  /// Arka planda açık kalma ayarı (bildirim alanındaki servis).
  void arkaPlandaAcikDegistir(bool v) {
    ayarlar.arkaPlandaAcik = v;
    notifyListeners();
  }

  void kenarCubuguDegistir() {
    kenarCubugu = !kenarCubugu;
    ayarlar.kenarCubugu = kenarCubugu;
    notifyListeners();
  }

  /// Claude ve Codex kullanım sınırlarını yeniden okut (token harcamaz);
  /// sonuçlar 'kota' olaylarıyla gelir.
  Future<void> kotaYenile() async {
    if (!yetenek('kota_oku')) return;
    try {
      await istemci.iste('kota_oku');
    } catch (_) {}
  }

  /// Uzak oturumdaki dosyayı bu cihazın önbelleğine indirir ve yerel yolunu
  /// verir (önizleyiciler yerel dosya okur; düzenleyiciden kaydedilen
  /// önbellek dosyasını köprü sunucuya geri yazar). Göreli yol oturumun
  /// uzak klasörüne göredir.
  Future<String> uzakYerel(Sohbet s, String yol) async {
    var tam = yol;
    if (!tam.startsWith('/') && !tam.startsWith('~')) {
      final kok = s.uzakKlasor ?? '~';
      tam = '${kok.endsWith('/') ? kok : '$kok/'}$tam';
    }
    final r = await istemci.iste('uzak_indir', {
      'sunucu': s.sunucu,
      'yol': tam,
    });
    return r['yol'] as String;
  }

  /// Sesli konuşmayı aç ya da kapat (kulaklık tuşu, kısayol, bildirim).
  /// Açık oturum sesi desteklemiyorsa Asistan açılır.
  Future<void> sesiAcKapat() async {
    if (!yetenek('ses')) return;
    var s = secili;
    if (s != null && s.ses.acik) {
      await s.ses.bitir();
      return;
    }
    if (s == null || !s.sesDestekleniyor) {
      if (!yetenek('asistan')) return;
      await asistanAc();
      s = secili;
      if (s == null) return;
    }
    await s.ses.baslat(
      ses: gecerliSes(ayarlar.sesSesi),
      dil: ayarlar.sesDili,
      model: ayarlar.sesModeli.isEmpty ? null : ayarlar.sesModeli,
      sesleOnay: ayarlar.sesleOnay,
    );
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
