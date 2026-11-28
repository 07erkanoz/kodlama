import 'package:flutter/material.dart';

import '../model/calisma.dart';
import '../model/widget_yoneticisi.dart';
import '../servis/bildirim.dart';

/// Ana ekran widget'ının ayarları, canlı önizlemeyle. Önizleme gerçek
/// oturumları gösterir; her değişiklik ana ekrandaki widget'a hemen gider.
class WidgetAyarlari extends StatefulWidget {
  const WidgetAyarlari({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<WidgetAyarlari> createState() => _WidgetAyarlariState();
}

class _WidgetAyarlariState extends State<WidgetAyarlari>
    with WidgetsBindingObserver {
  bool? _ekli;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bak();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Başlatıcıdan ("ana ekrana ekle") dönünce yeniden bak.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _bak();
  }

  Future<void> _bak() async {
    final v = await Bildirim.widgetVar();
    if (mounted) setState(() => _ekli = v);
  }

  void _degisti(VoidCallback f) {
    setState(f);
    WidgetYoneticisi.ornek?.guncelle();
  }

  Future<void> _ekle(bool buyuk) async {
    final ok = await Bildirim.widgetEkle(buyuk: buyuk);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Başlatıcın bunu desteklemiyor. Ana ekranda boş bir yere uzun bas › '
            'Widget\'lar › Atölye.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final a = c.ayarlar;
    return Scaffold(
      appBar: AppBar(title: const Text('Ana ekran widget\'ı')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          c,
          if (WidgetYoneticisi.ornek != null)
            WidgetYoneticisi.ornek!.bildirim.onayDegisti,
        ]),
        builder: (context, _) {
          final veri = WidgetYoneticisi.ozet(
            c,
            WidgetYoneticisi.ornek?.bildirim.onaylar ?? const {},
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _Onizleme(veri: veri),
              const SizedBox(height: 8),
              Text(
                'Widget\'ı kenarlarından çekerek istediğin boya getirebilirsin; '
                'içerik sığdığı kadar genişler. Ayarlar bütün Atölye widget\'larına uygulanır.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: r.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _baslik(t, 'Saydamlık', '%${a.widgetSaydamlik}'),
              Slider(
                value: a.widgetSaydamlik.toDouble(),
                max: 100,
                divisions: 20,
                label: '%${a.widgetSaydamlik}',
                onChanged: (v) => _degisti(() => a.widgetSaydamlik = v.round()),
              ),
              if (a.widgetSaydamlik > 50)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Saydamlık yüksekken yazılar duvar kâğıdına göre zor okunabilir; '
                    'koyu duvar kâğıdında koyu, açıkta açık tema daha iyi durur.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: r.onSurfaceVariant,
                    ),
                  ),
                ),
              _baslik(t, 'Köşe yuvarlaklığı', '${a.widgetKose}'),
              Slider(
                value: a.widgetKose.toDouble(),
                max: 32,
                divisions: 8,
                label: '${a.widgetKose}',
                onChanged: (v) => _degisti(() => a.widgetKose = v.round()),
              ),
              const SizedBox(height: 8),
              _baslik(t, 'Tema', null),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'koyu', label: Text('Koyu')),
                  ButtonSegment(value: 'acik', label: Text('Açık')),
                  ButtonSegment(value: 'sistem', label: Text('Sistem')),
                  ButtonSegment(value: 'duvar', label: Text('Duvar kâğıdı')),
                ],
                selected: {a.widgetTema},
                onSelectionChanged: (s) =>
                    _degisti(() => a.widgetTema = s.first),
              ),
              if (a.widgetTema == 'duvar')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Android 12 ve üstünde renkler duvar kâğıdından gelir; '
                    'önizleme yaklaşıktır. Daha eski sürümlerde sistem teması kullanılır.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: r.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _baslik(t, 'Gösterilen oturum', null),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Sığdığı kadar')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {a.widgetOturum},
                onSelectionChanged: (s) =>
                    _degisti(() => a.widgetOturum = s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Onay kartı'),
                subtitle: const Text(
                  'Bekleyen onay widget\'ta düğmeleriyle görünür; uygulamayı açmadan karar verirsin.',
                ),
                value: a.widgetOnay,
                onChanged: (v) => _degisti(() => a.widgetOnay = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kullanım sınırları'),
                subtitle: const Text('Claude ve Codex kota çubukları.'),
                value: a.widgetKota,
                onChanged: (v) => _degisti(() => a.widgetKota = v),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Icon(
                    _ekli == true
                        ? Icons.check_circle_outline
                        : Icons.widgets_outlined,
                    size: 20,
                    color: _ekli == true ? r.primary : r.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ekli == null
                          ? '…'
                          : _ekli!
                          ? 'Ana ekranda Atölye widget\'ı var.'
                          : 'Ana ekranda henüz Atölye widget\'ı yok.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _ekle(false),
                    icon: const Icon(Icons.add),
                    label: const Text('Küçüğü ekle'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _ekle(true),
                    icon: const Icon(Icons.add),
                    label: const Text('Ayrıntılıyı ekle'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _baslik(ThemeData t, String metin, String? deger) => Row(
    children: [
      Expanded(child: Text(metin, style: t.textTheme.titleSmall)),
      if (deger != null)
        Text(
          deger,
          style: t.textTheme.labelLarge?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
    ],
  );
}

// --- önizleme: AtolyeWidget.kt'nin çizdiğinin Flutter karşılığı

class _Renk {
  const _Renk(this.arka, this.yazi, this.yazi2, this.vurgu, this.koyu);
  final Color arka, yazi, yazi2, vurgu;
  final bool koyu;

  Color get onay => koyu ? const Color(0xFFFAC775) : const Color(0xFF854F0B);
  Color get yesil => koyu ? const Color(0xFF5DCAA5) : const Color(0xFF0F6E56);
  Color get dugme => koyu ? const Color(0x16FFFFFF) : const Color(0x10000000);

  static const koyuTema = _Renk(
    Color(0xFF14141C),
    Color(0xFFECEBFF),
    Color(0xFFC4C3DE),
    Color(0xFF8B8CF8),
    true,
  );
  static const acikTema = _Renk(
    Color(0xFFFAFAFC),
    Color(0xFF1B1B24),
    Color(0xFF3E3D4C),
    Color(0xFF534AB7),
    false,
  );

  static _Renk sec(BuildContext context, String tema) {
    final gece = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    switch (tema) {
      case 'acik':
        return acikTema;
      case 'sistem':
        return gece ? koyuTema : acikTema;
      case 'duvar':
        final r = Theme.of(context).colorScheme;
        return _Renk(
          r.surface,
          r.onSurface,
          r.onSurfaceVariant,
          r.primary,
          Theme.of(context).brightness == Brightness.dark,
        );
      default:
        return koyuTema;
    }
  }
}

const _claude = Color(0xFFD97757);

class _Onizleme extends StatelessWidget {
  const _Onizleme({required this.veri});
  final Map<String, dynamic> veri;

  @override
  Widget build(BuildContext context) {
    final ayar = (veri['ayar'] as Map).cast<String, dynamic>();
    final r = _Renk.sec(context, ayar['tema'] as String);
    final opaklik = 1 - (ayar['saydamlik'] as int) / 100;
    final kose = (ayar['kose'] as int).toDouble();
    Widget kutu(double g, double y, Widget icerik, {double dolgu = 14}) =>
        Container(
          width: g,
          height: y,
          padding: EdgeInsets.all(dolgu),
          decoration: BoxDecoration(
            color: r.arka.withValues(alpha: opaklik),
            borderRadius: BorderRadius.circular(kose),
          ),
          child: icerik,
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF2B3A55),
        child: Stack(
          children: [
            // Saydamlığı görmek için düz renkli "duvar kâğıdı".
            const Positioned(left: -60, top: 120, child: _Daire(260, _claude)),
            const Positioned(
              right: 30,
              top: -60,
              child: _Daire(200, Color(0xFF5DCAA5)),
            ),
            const Positioned(
              right: -30,
              bottom: -30,
              child: _Daire(140, Color(0xFFEF9F27)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  kutu(150, 150, _Kucuk(veri: veri, r: r), dolgu: 12),
                  kutu(316, 56, _Serit(veri: veri, r: r), dolgu: 10),
                  kutu(316, 300, _Buyuk(veri: veri, r: r, ayar: ayar)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Daire extends StatelessWidget {
  const _Daire(this.cap, this.renk);
  final double cap;
  final Color renk;

  @override
  Widget build(BuildContext context) => Container(
    width: cap,
    height: cap,
    decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
  );
}

TextStyle _s(Color c, double boy, {bool kalin = false}) => TextStyle(
  color: c,
  fontSize: boy,
  fontWeight: kalin ? FontWeight.w600 : FontWeight.w400,
  height: 1.25,
);

Color _nokta(Map<String, dynamic> v, _Renk r) => (v['onaySayisi'] as int) > 0
    ? r.onay
    : v['bagli'] == true
    ? r.yesil
    : const Color(0xFFF09595);

Widget _dugme(_Renk r, IconData simge, [String? yazi]) => Container(
  height: 34,
  decoration: BoxDecoration(
    color: r.dugme,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(simge, size: 16, color: r.yazi),
      if (yazi != null) ...[
        const SizedBox(width: 4),
        Text(yazi, style: _s(r.yazi, 12)),
      ],
    ],
  ),
);

Widget _ust(Map<String, dynamic> v, _Renk r, {String? alt}) => SizedBox(
  height: 22,
  child: Row(
    children: [
      Icon(Icons.terminal_rounded, size: 16, color: r.vurgu),
      const SizedBox(width: 6),
      Text('Atölye', style: _s(r.yazi, 14, kalin: true)),
      if (alt != null) ...[
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            alt,
            style: _s(r.yazi2, 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ] else
        const Spacer(),
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _nokta(v, r), shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Icon(Icons.refresh, size: 15, color: r.yazi2),
    ],
  ),
);

class _Kucuk extends StatelessWidget {
  const _Kucuk({required this.veri, required this.r});
  final Map<String, dynamic> veri;
  final _Renk r;

  @override
  Widget build(BuildContext context) {
    final n = veri['calisan'] as int;
    final onay = veri['onaySayisi'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ust(veri, r),
        const SizedBox(height: 4),
        Text('$n', style: _s(r.yazi, 24)),
        Text(n > 0 ? 'ajan çalışıyor' : 'boşta', style: _s(r.yazi2, 11)),
        if (onay > 0)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x38EF9F27),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$onay onay bekliyor', style: _s(r.onay, 11)),
          ),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _dugme(r, Icons.mic_none)),
            const SizedBox(width: 6),
            Expanded(child: _dugme(r, Icons.add)),
          ],
        ),
      ],
    );
  }
}

class _Serit extends StatelessWidget {
  const _Serit({required this.veri, required this.r});
  final Map<String, dynamic> veri;
  final _Renk r;

  @override
  Widget build(BuildContext context) {
    final n = veri['calisan'] as int;
    final onay = veri['onaySayisi'] as int;
    final parca = [if (n > 0) '$n çalışıyor', if (onay > 0) '$onay onay'];
    return Row(
      children: [
        Icon(Icons.terminal_rounded, size: 16, color: r.vurgu),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _nokta(veri, r),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            parca.isEmpty ? 'Boşta · köprü bağlı' : parca.join(' · '),
            style: _s(r.yazi, 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 44, child: _dugme(r, Icons.mic_none)),
        const SizedBox(width: 6),
        SizedBox(width: 44, child: _dugme(r, Icons.add)),
      ],
    );
  }
}

class _Buyuk extends StatelessWidget {
  const _Buyuk({required this.veri, required this.r, required this.ayar});
  final Map<String, dynamic> veri;
  final _Renk r;
  final Map<String, dynamic> ayar;

  @override
  Widget build(BuildContext context) {
    final n = veri['calisan'] as int;
    final onay = ayar['onay'] == true ? veri['onay'] as Map? : null;
    final kota = ayar['kota'] == true ? veri['kota'] as Map? : null;
    final oturumlar = (veri['oturumlar'] as List).cast<Map>();
    // AtolyeWidget.kt ile aynı yer hesabı (önizleme 300 dp yüksekliğinde).
    var kalan = 300.0 - 28 - 22;
    if (onay != null) kalan -= 100;
    kalan -= 42;
    final kotaGoster = kota != null && kalan >= 42 + 26 * 2;
    if (kotaGoster) kalan -= 42;
    final sinir = (ayar['oturum'] as int) > 0 ? ayar['oturum'] as int : 8;
    final satir = [
      ((kalan - 8) / 26).floor(),
      sinir,
      oturumlar.length,
    ].reduce((a, b) => a < b ? a : b).clamp(0, 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ust(veri, r, alt: n > 0 ? '· $n çalışıyor' : '· köprü bağlı'),
        if (onay != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x29EF9F27),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${onay['ajanAdi']} · ${onay['baslik']}',
                  style: _s(r.onay, 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${onay['metin']}',
                  style: _s(r.yazi, 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: r.vurgu,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'İzin ver',
                          style: _s(
                            r.koyu ? const Color(0xFF14141C) : Colors.white,
                            12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: _dugmeYazi(r, 'Bu oturumda hep')),
                    const SizedBox(width: 6),
                    Expanded(child: _dugmeYazi(r, 'Reddet')),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (oturumlar.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Henüz oturum yok · + ile başlat',
              style: _s(r.yazi2, 12),
            ),
          ),
        for (final o in oturumlar.take(satir))
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: o['ajan'] == 'claude' ? _claude : r.vurgu,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${o['ajanAdi']} · ${(o['baslik'] as String?)?.isNotEmpty == true ? o['baslik'] : 'Yeni oturum'}',
                    style: _s(r.yazi, 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  o['onay'] == true
                      ? 'onay bekliyor'
                      : o['durum'] == 'calisiyor'
                      ? 'çalışıyor'
                      : _once(o['zaman'] as num?),
                  style: _s(
                    o['onay'] == true
                        ? r.onay
                        : o['durum'] == 'calisiyor'
                        ? r.yesil
                        : r.yazi2,
                    11,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        if (kotaGoster)
          for (final a in const ['claude', 'codex'])
            if (kota[a] is Map)
              SizedBox(
                height: 18,
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        a == 'claude' ? 'Claude' : 'Codex',
                        style: _s(r.yazi2, 11),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ((kota[a]['yuzde'] as num?) ?? 0) / 100,
                          minHeight: 4,
                          color: a == 'claude' ? _claude : r.vurgu,
                          backgroundColor: const Color(0x40888780),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('%${kota[a]['yuzde']}', style: _s(r.yazi2, 11)),
                  ],
                ),
              ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _dugme(r, Icons.mic_none, 'Konuş')),
            const SizedBox(width: 6),
            Expanded(child: _dugme(r, Icons.add, 'Yeni')),
            const SizedBox(width: 6),
            Expanded(child: _dugme(r, Icons.search, 'Ara')),
          ],
        ),
      ],
    );
  }
}

Widget _dugmeYazi(_Renk r, String yazi) => Container(
  height: 34,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: r.dugme,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    yazi,
    style: _s(r.yazi, 12),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
);

String _once(num? zaman) {
  if (zaman == null || zaman <= 0) return '';
  final d = DateTime.now().millisecondsSinceEpoch ~/ 1000 - zaman.toInt();
  if (d < 60) return 'az önce';
  if (d < 3600) return '${d ~/ 60} dk önce';
  if (d < 86400) return '${d ~/ 3600} sa önce';
  if (d < 172800) return 'dün';
  return '${d ~/ 86400} g önce';
}
