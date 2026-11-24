import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';
import '../servis/termux.dart';
import '../servis/termux_indir.dart';
import '../servis/yerel_token.dart';
import 'giris_penceresi.dart';
import 'kurulum_paneli.dart';

/// İlk açılış sihirbazı. Hiçbir şey kullanıcıya sorulmadan kurulmaz;
/// her adım ne yapılacağını söyler ve onay bekler. Termux, Claude Code ve
/// Codex kendi resmi kaynaklarından kurulur, giriş her CLI'ın kendi
/// akışıyla yapılır.
class KurulumEkrani extends StatefulWidget {
  const KurulumEkrani({super.key, required this.calisma, required this.bitti});

  final Calisma calisma;
  final VoidCallback bitti;

  @override
  State<KurulumEkrani> createState() => _KurulumEkraniState();
}

class _KurulumEkraniState extends State<KurulumEkrani>
    with WidgetsBindingObserver {
  int _adim = 0;
  final _secili = <String>{'claude'};
  bool? _termuxVar;
  bool _izinVar = false;
  final _indirici = TermuxIndirici();
  String? _apkYolu;
  bool _indiriliyor = false;
  bool _izinBekleniyor = false;
  String? _indirmeHatasi;
  String? _komut;
  bool _paketlerBasladi = false;
  bool _ilerledi = false;
  String? _paketHatasi;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secili
      ..clear()
      ..addAll(c.ayarlar.ajanlar);
    c.istemci.durum.addListener(_baglantiDegisti);
    c.kurulum.addListener(_kurulumDegisti);
    c.addListener(_ciz);
    _kontrol();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.istemci.durum.removeListener(_baglantiDegisti);
    c.kurulum.removeListener(_kurulumDegisti);
    c.removeListener(_ciz);
    c.kurulumSunucusunuDurdur();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Termux'tan ya da indirme sayfasından dönünce durumu yeniden oku.
    if (state == AppLifecycleState.resumed) _kontrol();
  }

  Future<void> _kontrol() async {
    final termux = await Termux.kurulu();
    final izin = await Termux.komutIzniVar();
    if (!mounted) return;
    setState(() {
      _termuxVar = termux;
      _izinVar = izin;
    });
    if (_adim == 1 && termux) {
      // Termux az önce kuruldu: sonraki adıma kendiliğinden geç.
      await _kurulumaGec();
      return;
    }
    if (_adim == 1 && _izinBekleniyor && await Termux.kurulumIzniVar()) {
      _izinBekleniyor = false;
      await _termuxuKur();
      return;
    }
    if (_adim == 2) c.istemci.baglan();
    // Girişten dönünce ajanların giriş durumunu tazele
    if (_adim == 5) {
      await c.yenile();
      if (mounted) setState(() {});
    }
  }

  /// Resmi Termux APK'sını indirir, doğrular ve Android'in yükleme ekranını açar.
  Future<void> _termuxuKur() async {
    setState(() {
      _indirmeHatasi = null;
    });
    if (!await Termux.kurulumIzniVar()) {
      if (!mounted) return;
      final tamam = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kurulum izni'),
          content: const Text(
            'Atölye\'nin Termux\'u kurdurabilmesi için Android\'in "Bilinmeyen '
            'uygulamaları yükle" iznine ihtiyacı var. Açılan ekranda Atölye için '
            'izni aç, sonra geri dön; indirme kendiliğinden başlar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('İzin ekranını aç'),
            ),
          ],
        ),
      );
      if (tamam == true) {
        _izinBekleniyor = true;
        await Termux.kurulumIzniAc();
      }
      return;
    }
    try {
      if (_apkYolu == null) {
        setState(() => _indiriliyor = true);
        _apkYolu = await _indirici.indir();
      }
      await Termux.apkKur(_apkYolu!);
    } catch (e) {
      _apkYolu = null;
      if (mounted) setState(() => _indirmeHatasi = '$e');
    } finally {
      if (mounted) setState(() => _indiriliyor = false);
    }
  }

  void _ciz() {
    if (mounted) setState(() {});
  }

  void _baglantiDegisti() {
    if (!mounted) return;
    if (c.baglanti == BaglantiDurumu.bagli && _adim == 2) {
      _paketlereGec();
    } else {
      setState(() {});
    }
  }

  Future<void> _kurulumaGec() async {
    final sunucu = await c.kurulumSunucusu();
    setState(() {
      _adim = 2;
      _komut = sunucu.komut(token: c.ayarlar.token, ajanlar: _secili.toList());
    });
    c.istemci.baglan();
  }

  /// Köprü ayakta: eksik araçları ve ajanları köprü üzerinden, uygulamanın
  /// içinde kur. Her şey zaten kuruluysa bu adım atlanır.
  Future<void> _paketlereGec() async {
    if (_paketlerBasladi) return;
    _paketlerBasladi = true;
    c.kurulumSunucusunuDurdur();
    setState(() {
      _adim = 3;
      _paketHatasi = null;
    });
    await c.yenile();
    if (!mounted) return;
    try {
      // Eski köprü kurulumu yönetemez: önce yenisini koy.
      if (!c.yetenek('kur')) await c.kopruyuGuncelle();
      if (!mounted) return;
      final eksik = await _eksikAjanlar();
      if (!mounted) return;
      if (eksik == null) {
        c.kurulum.sifirla();
        _izinAdimina();
        return;
      }
      if (!c.yetenek('kur')) {
        setState(
          () => _paketHatasi =
              'Köprü güncellenemedi. Ayarlar → Köprü bölümünden tekrar dene.',
        );
        return;
      }
      await c.kurulumuBaslat(ajanlar: eksik);
    } catch (e) {
      if (mounted) setState(() => _paketHatasi = '$e');
    }
  }

  /// Kurulması gereken ajanlar; hiçbir şey eksik değilse null.
  Future<List<String>?> _eksikAjanlar() async {
    final eksikAjan = [
      for (final ad in _secili)
        if (!c.ajanlar.any((a) => a['ad'] == ad && a['kurulu'] == true)) ad,
    ];
    var aracEksik = false;
    try {
      final r = await c.istemci.iste('araclar');
      final liste = (r['araclar'] as List).cast<Map>();
      for (final k in const ['node', 'git', 'gh', 'ssh']) {
        if (!liste.any((a) => a['komut'] == k && a['surum'] != null)) {
          aracEksik = true;
        }
      }
    } catch (_) {
      aracEksik = true;
    }
    return eksikAjan.isEmpty && !aracEksik ? null : eksikAjan;
  }

  void _kurulumDegisti() {
    if (!mounted) return;
    if (_adim == 3 &&
        !_ilerledi &&
        c.kurulum.basarili &&
        c.kurulum.asama == 'paketler') {
      _ilerledi = true;
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _adim == 3) _izinAdimina();
      });
    }
    setState(() {});
  }

  Future<void> _izinAdimina() async {
    final izin = await Termux.komutIzniVar();
    if (!mounted) return;
    setState(() {
      _izinVar = izin;
      _adim = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text('Atölye', style: t.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Telefonunda yerel geliştirme ortamı: Claude Code ve Codex, '
                  'Termux içinde senin hesabınla çalışır.',
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (Termux.destekleniyor) ...[
                  _AdimCubugu(adim: _adim),
                  const SizedBox(height: 20),
                ],
                if (!Termux.destekleniyor)
                  _ElleBaglan(calisma: c, bitti: widget.bitti)
                else
                  switch (_adim) {
                    0 => _hosgeldin(t),
                    1 => _termux(t),
                    2 => _kurulum(t),
                    3 => _paketler(t),
                    4 => _izin(t),
                    _ => _giris(t),
                  },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hosgeldin(ThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hangi ajanları kullanacaksın?', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (ad, baslik, aciklama) in const [
          (
            'claude',
            'Claude Code',
            'Anthropic · Claude hesabı ya da API anahtarı',
          ),
          ('codex', 'Codex', 'OpenAI · ChatGPT hesabı ya da API anahtarı'),
        ])
          CheckboxListTile(
            value: _secili.contains(ad),
            onChanged: (v) => setState(() {
              v == true ? _secili.add(ad) : _secili.remove(ad);
            }),
            title: Text(baslik),
            subtitle: Text(aciklama),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kurulacaklar', style: t.textTheme.titleSmall),
                const SizedBox(height: 6),
                const Text(
                  '• Termux (F-Droid ya da GitHub, resmi sürüm)\n'
                  '• Termux içinde: python, nodejs, git\n'
                  '• Seçtiğin ajanlar, resmi npm paketlerinden\n'
                  '• Atölye köprüsü (~/.atolye): uygulamanın ajanlarla '
                  'konuşmasını sağlar, yalnızca bu telefondan (127.0.0.1) '
                  'erişilir\n\n'
                  'Termux\'a yalnızca bir kez, kısa bir komut yapıştıracaksın; '
                  'kurulumun geri kalanı ve giriş Atölye\'nin içinde ilerler.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Giriş bilgilerini Atölye görmez; her ajan kendi giriş '
                  'ekranını açar.',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _secili.isEmpty
              ? null
              : () {
                  c.ayarlar.ajanlar = _secili.toList();
                  setState(() => _adim = _termuxVar == true ? 2 : 1);
                  if (_termuxVar == true) _kurulumaGec();
                },
          child: const Text('Onaylıyorum, devam et'),
        ),
      ],
    );
  }

  Widget _termux(ThemeData t) {
    final var_ = _termuxVar == true;
    final r = t.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Termux', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          var_
              ? 'Termux bu telefonda kurulu.'
              : 'Termux kurulu değil. Atölye resmi sürümü GitHub\'dan indirip '
                    'doğrular ve Android\'in yükleme ekranını açar; orada "Yükle"ye '
                    'basman yeterli. Kurulum bitince buraya dön.',
        ),
        const SizedBox(height: 16),
        if (!var_) ...[
          FilledButton.icon(
            icon: _indiriliyor
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            onPressed: _indiriliyor ? null : _termuxuKur,
            label: Text(
              _apkYolu == null
                  ? 'Termux\'u indir ve kur'
                  : 'Yükleme ekranını yeniden aç',
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _indirici.ilerleme,
            builder: (context, oran, _) => _indiriliyor || oran != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(value: oran),
                        const SizedBox(height: 6),
                        ValueListenableBuilder(
                          valueListenable: _indirici.durum,
                          builder: (context, d, _) => Text(
                            oran != null && oran < 1
                                ? '$d %${(oran * 100).round()}'
                                : d,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: r.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_indirmeHatasi != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_indirmeHatasi!, style: TextStyle(color: r.error)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(Termux.fdroidAdresi),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('F-Droid\'den kur'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _kontrol,
                child: const Text('Kurdum, kontrol et'),
              ),
            ],
          ),
          Text(
            'GitHub ve F-Droid sürümleri farklı imzalıdır; Termux eklentilerini aynı kaynaktan kur.',
            style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
          ),
        ] else
          FilledButton(onPressed: _kurulumaGec, child: const Text('Devam')),
      ],
    );
  }

  Widget _kurulum(ThemeData t) {
    final bagli = c.baglanti == BaglantiDurumu.bagli;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Termux içinde kurulum', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          '1. Aşağıdaki düğme komutu kopyalar ve Termux\'u açar.\n'
          '2. Termux\'u ilk kez açıyorsan "Installing…" yazısı bitene kadar bekle.\n'
          '3. Ekrana uzun bas → Paste (Yapıştır) → Enter.\n'
          '4. Komut depoları günceller ve köprüyü kurar; 2–4 dakika sürer, soru '
          'sormaz. Bitince Atölye\'ye kendiliğinden döner (dönmezse sen dön).\n\n'
          'Depo hatası alırsan Termux\'ta "termux-change-repo" yazıp başka bir '
          'ayna seç, sonra komutu yeniden yapıştır.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            _komut ?? '…',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.terminal),
          onPressed: _komut == null
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: _komut!));
                  await Termux.ac();
                },
          label: const Text('Kopyala ve Termux\'u aç'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!bagli)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bagli
                    ? 'Köprüye bağlandı.'
                    : c.baglanti == BaglantiDurumu.yetkisiz
                    ? 'Köprü çalışıyor ama anahtar eşleşmedi. Komutu yeniden çalıştır.'
                    : 'Termux\'ta kurulum sürüyor; köprü bekleniyor…',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Adım 3: paketler ve ajanlar, köprü üzerinden, canlı ilerlemeyle.
  Widget _paketler(ThemeData t) {
    final r = t.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Araçlar ve ajanlar', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Node.js, Git, GitHub CLI ve seçtiğin ajanlar kuruluyor. Termux\'u '
          'açmana gerek yok; burada izleyebilirsin. İlk kurulumda yüzlerce MB '
          'iner, birkaç dakika sürebilir.',
          style: t.textTheme.bodyMedium?.copyWith(color: r.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (c.kopruGuncelleniyor)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Köprü güncelleniyor…')),
            ],
          )
        else if (_paketHatasi != null) ...[
          Text(_paketHatasi!, style: TextStyle(color: r.error)),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: () {
              _paketlerBasladi = false;
              _paketlereGec();
            },
            child: const Text('Yeniden dene'),
          ),
        ] else
          KurulumPaneli(
            calisma: c,
            yenidenDene: () {
              _ilerledi = false;
              _paketlerBasladi = false;
              _paketlereGec();
            },
          ),
        const SizedBox(height: 12),
        if (c.kurulum.basarili)
          FilledButton(onPressed: _izinAdimina, child: const Text('Devam'))
        else
          TextButton(
            onPressed: _izinAdimina,
            child: const Text('Şimdilik geç'),
          ),
      ],
    );
  }

  /// Adım 4: bir kez verilecek izinler.
  Widget _izin(ThemeData t) {
    final r = t.colorScheme;
    Widget kart(IconData simge, String baslik, String aciklama, Widget son) =>
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(simge, color: r.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(baslik, style: t.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        aciklama,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: r.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                son,
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('İzinler', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'İki küçük ayar, uygulamanın Termux\'u senin yerine yönetebilmesi için.',
          style: t.textTheme.bodyMedium?.copyWith(color: r.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        kart(
          Icons.terminal,
          'Termux\'a komut gönderme',
          'Köprü kapanırsa (telefon yeniden başlayınca) Atölye onu kendisi açar.',
          _izinVar
              ? const Icon(Icons.check_circle, color: Color(0xFF22C55E))
              : FilledButton.tonal(
                  onPressed: () async {
                    final ok = await Termux.komutIzniIste();
                    if (mounted) setState(() => _izinVar = ok);
                  },
                  child: const Text('İzin ver'),
                ),
        ),
        const SizedBox(height: 8),
        kart(
          Icons.battery_saver_outlined,
          'Arka planda kesilmesin',
          'Termux ayarlarında Pil → "Kısıtlama yok" seç; yoksa Android uzun '
              'işleri öldürebilir.',
          OutlinedButton(
            onPressed: Termux.termuxAyarlariniAc,
            child: const Text('Aç'),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _adim = 5),
          child: const Text('Devam'),
        ),
      ],
    );
  }

  /// Adım 5: hesap girişi, uygulamanın içinde.
  Widget _giris(ThemeData t) {
    final ajanlar = {for (final a in c.ajanlar) a['ad']: a};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Giriş', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Hesabına tarayıcıda giriş yaparsın; Termux açılmaz. Atölye şifreni '
          'ya da anahtarlarını görmez. Daha önce giriş yaptıysan bu adımı '
          'atlayabilirsin: giriş bilgileri Termux\'ta saklanır, uygulama yeniden '
          'kurulsa da kaybolmaz.',
        ),
        const SizedBox(height: 12),
        for (final ad in _secili)
          Card(
            child: ListTile(
              leading: ajanlar[ad]?['giris'] == true
                  ? Icon(Icons.check_circle, color: t.colorScheme.tertiary)
                  : null,
              title: Text(ad == 'claude' ? 'Claude Code' : 'Codex'),
              subtitle: Text(
                ajanlar[ad]?['kurulu'] != true
                    ? 'kurulu görünmüyor — bir önceki adımda hata olmuş olabilir'
                    : ajanlar[ad]?['giris'] == true
                    ? 'Giriş yapılmış · ${ajanlar[ad]?['surum'] ?? ''}'
                    : (ajanlar[ad]?['surum'] as String? ?? 'kurulu'),
              ),
              trailing: ajanlar[ad]?['giris'] == true
                  ? TextButton(
                      onPressed: () => girisPenceresi(context, c, ad),
                      child: const Text('Yeniden'),
                    )
                  : FilledButton.tonal(
                      onPressed: ajanlar[ad]?['kurulu'] == true
                          ? () => girisPenceresi(context, c, ad)
                          : null,
                      child: const Text('Giriş yap'),
                    ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            c.ayarlar.kurulumBitti = true;
            widget.bitti();
          },
          child: const Text('Bitti, başla'),
        ),
      ],
    );
  }
}

class _AdimCubugu extends StatelessWidget {
  const _AdimCubugu({required this.adim});
  final int adim;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < 6; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i <= adim ? renk.primary : renk.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Android dışı (masaüstü, web): köprü elle başlatılır, buradan bağlanılır.
class _ElleBaglan extends StatefulWidget {
  const _ElleBaglan({required this.calisma, required this.bitti});
  final Calisma calisma;
  final VoidCallback bitti;

  @override
  State<_ElleBaglan> createState() => _ElleBaglanState();
}

class _ElleBaglanState extends State<_ElleBaglan> {
  late final _port = TextEditingController(
    text: '${widget.calisma.ayarlar.port}',
  );
  late final _token = TextEditingController(text: yerelKopruAnahtari() ?? '');
  String? _hata;
  bool _bekliyor = false;

  Future<void> _baglan() async {
    final c = widget.calisma;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    c.ayarlar
      ..port = int.tryParse(_port.text) ?? 8765
      ..token = _token.text.trim();
    await c.yenidenKur();
    for (var i = 0; i < 20 && c.baglanti == BaglantiDurumu.baglaniyor; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    if (c.baglanti == BaglantiDurumu.bagli) {
      c.ayarlar.kurulumBitti = true;
      widget.bitti();
    } else {
      setState(() {
        _bekliyor = false;
        _hata = c.baglanti == BaglantiDurumu.yetkisiz
            ? 'Anahtar yanlış.'
            : 'Köprüye ulaşılamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bu cihazda Termux yok. Köprüyü kendin başlat:\n'
          '  python3 kopru/atolye_kopru.py\n'
          'Anahtarı görmek için:\n'
          '  python3 kopru/atolye_kopru.py --token-goster',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _port,
          decoration: const InputDecoration(labelText: 'Port'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _token,
          decoration: const InputDecoration(labelText: 'Anahtar'),
          onSubmitted: (_) => _baglan(),
        ),
        if (_hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _hata!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _bekliyor ? null : _baglan,
          child: const Text('Bağlan'),
        ),
      ],
    );
  }
}
