import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';
import '../servis/kurulum_sunucusu.dart';
import '../servis/termux.dart';
import '../servis/yerel_token.dart';

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
  final _sunucu = KurulumSunucusu();
  String? _komut;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secili
      ..clear()
      ..addAll(c.ayarlar.ajanlar);
    c.istemci.durum.addListener(_baglantiDegisti);
    _kontrol();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.istemci.durum.removeListener(_baglantiDegisti);
    _sunucu.durdur();
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
    if (_adim == 2) c.istemci.baglan();
  }

  void _baglantiDegisti() {
    if (!mounted) return;
    if (c.baglanti == BaglantiDurumu.bagli && _adim == 2) {
      _sunucu.durdur();
      setState(() => _adim = _izinVar ? 4 : 3);
    } else {
      setState(() {});
    }
  }

  Future<void> _kurulumaGec() async {
    await _sunucu.baslat();
    setState(() {
      _adim = 2;
      _komut = _sunucu.komut(token: c.ayarlar.token, ajanlar: _secili.toList());
    });
    c.istemci.baglan();
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
                    3 => _izin(t),
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
                  'erişilir',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Termux', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          var_
              ? 'Termux bu telefonda kurulu.'
              : 'Termux kurulu değil. Resmi sürümü indir, Android\'in kurulum '
                    'ekranında onayla, sonra buraya dön. Google Play\'deki '
                    'eski sürümü kullanma.',
        ),
        const SizedBox(height: 16),
        if (!var_) ...[
          FilledButton.icon(
            icon: const Icon(Icons.download),
            onPressed: () => launchUrl(
              Uri.parse(Termux.fdroidAdresi),
              mode: LaunchMode.externalApplication,
            ),
            label: const Text('F-Droid\'den indir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.code),
            onPressed: () => launchUrl(
              Uri.parse(Termux.githubAdresi),
              mode: LaunchMode.externalApplication,
            ),
            label: const Text('GitHub sürümlerinden indir'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _kontrol,
            child: const Text('Kurdum, tekrar kontrol et'),
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
          '2. Termux\'u ilk kez açıyorsan hazırlanmasını bekle.\n'
          '3. Ekrana uzun bas → Yapıştır → Enter.\n'
          '4. Kurulum bitince buraya dön; Atölye köprüyü kendisi bulur.',
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
                    : 'Köprü bekleniyor…',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _izin(ThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Termux\'a komut gönderme izni', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Bu izinle Atölye, köprü kapandığında onu Termux\'ta yeniden '
          'başlatabilir ve giriş ekranlarını açabilir. İzin vermezsen köprüyü '
          'Termux\'ta "atolye-kopru" yazarak sen başlatırsın.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final ok = await Termux.komutIzniIste();
            setState(() {
              _izinVar = ok;
              _adim = 4;
            });
          },
          child: const Text('İzin ver'),
        ),
        TextButton(
          onPressed: () => setState(() => _adim = 4),
          child: const Text('Şimdilik geç'),
        ),
      ],
    );
  }

  Widget _giris(ThemeData t) {
    final ajanlar = {for (final a in c.ajanlar) a['ad']: a};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Giriş', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Her ajan kendi giriş ekranını Termux\'ta açar. Tarayıcıda hesabına '
          'gir; Claude için giriş bitince /exit yaz. Sonra buraya dön.',
        ),
        const SizedBox(height: 12),
        for (final ad in _secili)
          Card(
            child: ListTile(
              title: Text(ad == 'claude' ? 'Claude Code' : 'Codex'),
              subtitle: Text(
                ajanlar[ad]?['kurulu'] == true
                    ? (ajanlar[ad]?['surum'] as String? ?? 'kurulu')
                    : 'kurulu görünmüyor — Termux\'taki çıktıya bak',
              ),
              trailing: FilledButton.tonal(
                onPressed: _izinVar
                    ? () => Termux.girisAc(ad)
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: ad == 'codex' ? 'codex login' : 'claude',
                          ),
                        );
                        await Termux.ac();
                      },
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
        for (var i = 0; i < 5; i++)
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
