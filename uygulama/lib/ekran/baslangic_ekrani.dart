import 'package:flutter/material.dart';

import '../arayuz/ajan_ayarlari.dart';
import '../arayuz/mesaj_kutusu.dart';
import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';
import 'klonla_penceresi.dart';

/// Oturum seçili değilken açılan ekran: proje ve ajan seçilir, ilk mesaj
/// yazılır, gönderince oturum açılır ve iş başlar. Altında projeler ve
/// son oturumlar.
class BaslangicEkrani extends StatefulWidget {
  const BaslangicEkrani({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<BaslangicEkrani> createState() => _BaslangicEkraniState();
}

class _BaslangicEkraniState extends State<BaslangicEkrani> {
  final _yazi = TextEditingController();
  String? _proje;
  String? _ajan;
  String _mod = 'otomatik';
  String? _model;
  String? _effort;

  /// Boşsa bu cihaz; değilse kayıtlı SSH sunucusunun adı.
  String? _sunucu;
  String? _uzakKlasor;

  Map<String, dynamic>? get _seciliSunucu =>
      c.sunucular.where((s) => s['ad'] == _sunucu).firstOrNull;
  bool _gonderiliyor = false;

  Calisma get c => widget.calisma;

  static const _oneriler = [
    (
      Icons.build_circle_outlined,
      'Ortamı hazırla',
      'Bu projeyi çalıştırmak için gereken araçları ve bağımlılıkları Termux\'ta kur, sonra projeyi çalıştırıp bana nasıl açacağımı söyle.',
    ),
    (
      Icons.travel_explore,
      'Projeyi incele',
      'Bu projeyi incele: ne yapıyor, nasıl çalışıyor, nereden başlamalıyım? Kısa bir özet çıkar.',
    ),
    (
      Icons.bug_report_outlined,
      'Testleri çalıştır',
      'Testleri çalıştır, başarısız olanların nedenini bul ve düzelt.',
    ),
    (
      Icons.rate_review_outlined,
      'Kodu gözden geçir',
      'Son değişiklikleri gözden geçir; hataları, güvenlik sorunlarını ve gereksiz karmaşıklığı listele.',
    ),
    (
      Icons.description_outlined,
      'README yaz',
      'Bu proje için kurulumu, kullanımı ve yapıyı anlatan bir README.md yaz.',
    ),
    (Icons.auto_fix_high, 'Yeni özellik', 'Şu özelliği ekle: '),
  ];

  List<String> get _kuruluAjanlar => [
    for (final a in c.ajanlar)
      if (a['kurulu'] == true) a['ad'] as String,
  ];

  String? get _seciliProje {
    if (_proje != null && c.projeler.any((p) => p['yol'] == _proje)) {
      return _proje;
    }
    return c.projeler.isNotEmpty ? c.projeler.first['yol'] as String : null;
  }

  String? get _seciliAjan {
    final kurulu = _kuruluAjanlar;
    if (_ajan != null && kurulu.contains(_ajan)) return _ajan;
    return kurulu.isNotEmpty ? kurulu.first : null;
  }

  Future<void> _gonder() async {
    final metin = _yazi.text.trim();
    final proje = _seciliProje, ajan = _seciliAjan;
    final sunucu = _seciliSunucu;
    if (metin.isEmpty || ajan == null || _gonderiliyor) return;
    if (sunucu == null && proje == null) return;
    setState(() => _gonderiliyor = true);
    try {
      await c.hizliBaslat(
        ajan: ajan,
        cwd: proje ?? '',
        metin: metin,
        mod: _mod,
        model: _model,
        effort: _effort,
        sunucu: sunucu?['ad'] as String?,
        uzakKlasor: sunucu == null
            ? null
            : (_uzakKlasor ?? sunucu['klasor'] as String? ?? '~'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Başlatılamadı: $e')));
      }
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  Future<void> _klonla() async {
    final yol = await klonlaPenceresi(context, c);
    if (yol != null && mounted) setState(() => _proje = yol);
  }

  Future<void> _uzakKlasorSec() async {
    final s = _seciliSunucu;
    if (s == null) return;
    final d = TextEditingController(
      text: _uzakKlasor ?? s['klasor'] as String? ?? '~',
    );
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${s['ad']} üzerinde klasör'),
        content: TextField(
          controller: d,
          autofocus: true,
          decoration: const InputDecoration(hintText: '/home/kullanici/proje'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, d.text),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) {
      setState(() => _uzakKlasor = v.trim());
    }
  }

  Future<void> _yeniProje() async {
    final ad = TextEditingController();
    final sonuc = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni proje'),
        content: TextField(
          controller: ad,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'proje-adi'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ad.text),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (sonuc == null || sonuc.trim().isEmpty) return;
    try {
      final yol = await c.projeOlustur(sonuc.trim());
      setState(() => _proje = yol);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Oluşturulamadı: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final bagli = c.baglanti == BaglantiDurumu.bagli;
        final proje = _seciliProje;
        final ajan = _seciliAjan;
        final projeAdi = proje?.split('/').last ?? 'Proje seç';
        final sunucu = _seciliSunucu;
        return LayoutBuilder(
          builder: (context, kisit) {
            final dar = kisit.maxWidth < 600;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                dar ? 24 : kisit.maxHeight * .12,
                16,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ne üzerinde çalışalım?',
                        textAlign: dar ? TextAlign.start : TextAlign.center,
                        style:
                            (dar
                                    ? t.textTheme.headlineSmall
                                    : t.textTheme.headlineMedium)
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.5,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bagli
                            ? 'Bir proje seç, ne istediğini yaz. Ajan telefonundaki dosyalarda çalışır; Otomatik biçimde yalnız riskli işler için onayın istenir.'
                            : 'Köprüye bağlanılıyor… Termux\'ta "atolye-kopru" çalışıyor olmalı.',
                        textAlign: dar ? TextAlign.start : TextAlign.center,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: r.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      MesajKutusu(
                        denetleyici: _yazi,
                        gonder: _gonder,
                        otomatikOdak: !dar,
                        gonderilebilir:
                            bagli &&
                            (proje != null || sunucu != null) &&
                            ajan != null &&
                            !_gonderiliyor,
                        ipucu: ajan == null
                            ? 'Kurulu ajan bulunamadı'
                            : '${ajanAdi(ajan)} için bir görev yaz…',
                        cipler: [
                          if (c.sunucular.isNotEmpty)
                            SecimCipi<String>(
                              simge: Icon(
                                sunucu == null
                                    ? Icons.smartphone
                                    : Icons.dns_outlined,
                              ),
                              etiket: sunucu == null
                                  ? 'Bu cihaz'
                                  : sunucu['ad'] as String,
                              ipucu: 'Nerede çalışsın',
                              secili: _sunucu ?? '',
                              secenekler: [
                                ('', 'Bu cihaz', 'Termux içinde', true),
                                for (final s in c.sunucular)
                                  (
                                    s['ad'] as String,
                                    s['ad'] as String,
                                    'SSH · ${s['host']}',
                                    true,
                                  ),
                              ],
                              secildi: (v) => setState(() {
                                _sunucu = v.isEmpty ? null : v;
                                _uzakKlasor = null;
                              }),
                            ),
                          if (sunucu != null)
                            ActionChip(
                              avatar: const Icon(
                                Icons.folder_outlined,
                                size: 15,
                              ),
                              label: Text(
                                _uzakKlasor ??
                                    sunucu['klasor'] as String? ??
                                    '~',
                              ),
                              onPressed: _uzakKlasorSec,
                            )
                          else
                            SecimCipi<String>(
                              simge: const Icon(Icons.folder_outlined),
                              etiket: projeAdi,
                              ipucu: 'Proje',
                              secili: proje,
                              secenekler: [
                                for (final p in c.projeler)
                                  (
                                    p['yol'] as String,
                                    p['ad'] as String,
                                    goreliZaman(p['degisme'] as num?),
                                    true,
                                  ),
                                ('+', '+ Yeni proje…', null, true),
                                ('klon', '⇣ GitHub\'dan klonla…', null, true),
                              ],
                              secildi: (v) => v == '+'
                                  ? _yeniProje()
                                  : v == 'klon'
                                  ? _klonla()
                                  : setState(() => _proje = v),
                            ),
                          SecimCipi<String>(
                            simge: ajan == null
                                ? const Icon(Icons.smart_toy_outlined)
                                : AjanRozeti(ajan: ajan, boyut: 16),
                            etiket: ajan == null ? 'Ajan yok' : ajanAdi(ajan),
                            ipucu: 'Ajan',
                            secili: ajan,
                            secenekler: [
                              for (final a in c.ajanlar)
                                (
                                  a['ad'] as String,
                                  ajanAdi(a['ad'] as String),
                                  a['kurulu'] == true
                                      ? (a['surum'] as String?)
                                      : 'kurulu değil',
                                  a['kurulu'] == true,
                                ),
                            ],
                            secildi: (v) => setState(() {
                              if (v != _ajan) {
                                _model = null;
                                _effort = null;
                              }
                              _ajan = v;
                            }),
                          ),
                          if (ajan != null)
                            ...ajanAyarCipleri(
                              calisma: c,
                              ajan: ajan,
                              model: _model,
                              effort: _effort,
                              mod: _mod,
                              modelSec: (v) => setState(() {
                                _model = v;
                                _effort = uygunEffort(c, ajan, v, _effort);
                              }),
                              effortSec: (v) => setState(() => _effort = v),
                              modSec: (v) => setState(() => _mod = v),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: dar
                            ? WrapAlignment.start
                            : WrapAlignment.center,
                        children: [
                          for (final (simge, ad, metin) in _oneriler)
                            ActionChip(
                              avatar: Icon(simge, size: 16),
                              label: Text(ad),
                              onPressed: () {
                                _yazi.text = metin;
                                _yazi.selection = TextSelection.collapsed(
                                  offset: metin.length,
                                );
                              },
                            ),
                        ],
                      ),
                      if (c.projeler.isNotEmpty) ...[
                        const SizedBox(height: 36),
                        _BolumBasligi(
                          'Projeler',
                          sag: Wrap(
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: bagli ? _klonla : null,
                                icon: const Icon(
                                  Icons.download_outlined,
                                  size: 16,
                                ),
                                label: const Text('Klonla'),
                              ),
                              TextButton.icon(
                                onPressed: bagli ? _yeniProje : null,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Yeni'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: dar ? 2 : 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: dar ? 2.1 : 2.6,
                          children: [
                            for (final p in c.projeler.take(dar ? 6 : 9))
                              _ProjeKarti(
                                ad: p['ad'] as String,
                                zaman: goreliZaman(p['degisme'] as num?),
                                secili: p['yol'] == proje,
                                oturum: c.oturumlar
                                    .where((o) => o['cwd'] == p['yol'])
                                    .length,
                                bas: () =>
                                    setState(() => _proje = p['yol'] as String),
                              ),
                          ],
                        ),
                      ],
                      if (c.oturumlar.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        const _BolumBasligi('Son oturumlar'),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              for (final (i, o)
                                  in c.oturumlar.take(5).indexed) ...[
                                if (i > 0)
                                  Divider(height: 1, color: r.outlineVariant),
                                ListTile(
                                  leading: AjanRozeti(
                                    ajan: o['ajan'] as String,
                                    calisiyor: o['durum'] == 'calisiyor',
                                  ),
                                  title: Text(
                                    o['baslik'] as String? ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${(o['cwd'] as String? ?? '').split('/').last} · ${goreliZaman(o['guncelleme'] as num?)}',
                                    style: TextStyle(color: r.onSurfaceVariant),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: r.onSurfaceVariant,
                                  ),
                                  onTap: () => c.sec(o),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BolumBasligi extends StatelessWidget {
  const _BolumBasligi(this.metin, {this.sag});
  final String metin;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Text(
          metin,
          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        ?sag,
      ],
    );
  }
}

class _ProjeKarti extends StatelessWidget {
  const _ProjeKarti({
    required this.ad,
    required this.zaman,
    required this.secili,
    required this.oturum,
    required this.bas,
  });

  final String ad;
  final String zaman;
  final bool secili;
  final int oturum;
  final VoidCallback bas;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Material(
      color: secili
          ? r.primaryContainer.withValues(alpha: .5)
          : r.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: secili ? r.primary : r.outlineVariant,
          width: secili ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: bas,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: r.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  size: 18,
                  color: secili ? r.primary : r.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      oturum > 0 ? '$zaman · $oturum oturum' : zaman,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: r.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
