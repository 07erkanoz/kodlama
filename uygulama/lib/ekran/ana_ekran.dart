import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../arayuz/yerlesim.dart';
import '../model/calisma.dart';
import 'baslangic_ekrani.dart';
import 'dosya_paneli.dart';
import 'onizleme.dart';
import 'oturum_listesi.dart';
import 'sohbet_gorunumu.dart';

/// Uygulamanın ana düzeni. Ekran boyuna ve katlanır telefonun menteşesine
/// göre değişir; durum ([Calisma]) değişmediği için katlayıp açınca sohbet
/// kaldığı yerden sürer.
///
///   dar (telefon)       : tek panel; oturumlar soldan, dosyalar sağdan
///                         çekmece; önizleme tam sayfa
///   orta (açık katlanır,
///         küçük tablet) : kenar çubuğu | sohbet; dosyalar sağ çekmecede
///   menteşeli katlanır  : sohbet | dosyalar ya da önizleme (menteşeye göre)
///   geniş (tablet)      : kenar çubuğu | sohbet | dosyalar ya da önizleme
class AnaEkran extends StatelessWidget {
  const AnaEkran({super.key, required this.calisma});

  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calisma,
      builder: (context, _) => LayoutBuilder(
        builder: (context, kisit) {
          if (dikeyMentese(context) != null) return _Katlanir(calisma: calisma);
          return switch (ekranSinifi(kisit.maxWidth)) {
            EkranSinifi.dar => _Dar(calisma: calisma),
            EkranSinifi.orta => _Orta(calisma: calisma),
            EkranSinifi.genis => _Genis(calisma: calisma),
          };
        },
      ),
    );
  }
}

/// Sohbetin üst çubuğu: başlık, ajan ve proje; dosyalar ve menü.
PreferredSizeWidget _ustCubuk(
  BuildContext context,
  Calisma c, {
  bool menu = false,
  _DosyaDugmesi dosyalar = _DosyaDugmesi.yok,
}) {
  final s = c.secili;
  final t = Theme.of(context);
  final r = t.colorScheme;
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 56,
    titleSpacing: menu ? 0 : 20,
    leading: menu
        ? Builder(
            builder: (context) => IconButton(
              tooltip: 'Oturumlar',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          )
        : null,
    title: s == null
        ? Text(
            'Yeni oturum',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
        : Row(
            children: [
              AjanRozeti(ajan: s.ajan, boyut: 26, calisiyor: s.calisiyor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.baslik,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${ajanAdi(s.ajan)} · ${s.cwd.split('/').last}',
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
    actions: [
      if (s != null && dosyalar == _DosyaDugmesi.cekmece)
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Dosyalar',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.folder_open_outlined),
          ),
        ),
      if (s != null && dosyalar == _DosyaDugmesi.panel)
        IconButton(
          tooltip: c.dosyaPaneli
              ? 'Dosya panelini gizle'
              : 'Dosya panelini göster',
          isSelected: c.dosyaPaneli,
          onPressed: c.dosyaPaneliDegistir,
          icon: const Icon(Icons.view_sidebar_outlined),
          selectedIcon: Icon(Icons.view_sidebar, color: r.primary),
        ),
      if (s != null)
        PopupMenuButton<String>(
          tooltip: 'Diğer',
          icon: const Icon(Icons.more_horiz),
          onSelected: (v) async {
            if (v == 'yeni') c.baslangica();
            if (v == 'sil') {
              final evet = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Oturum silinsin mi?'),
                  content: const Text(
                    'Atölye kaydından silinir; klasördeki dosyalara dokunulmaz.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sil'),
                    ),
                  ],
                ),
              );
              if (evet == true) await c.oturumSil(s.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'yeni', child: Text('Yeni oturum')),
            PopupMenuItem(value: 'sil', child: Text('Oturumu sil')),
          ],
        ),
      const SizedBox(width: 6),
    ],
  );
}

enum _DosyaDugmesi { yok, cekmece, panel }

Widget _govde(Calisma c, {void Function(String)? dosyaAc}) {
  final s = c.secili;
  if (s == null) return BaslangicEkrani(calisma: c);
  return SohbetGorunumu(
    key: ValueKey(s.id),
    calisma: c,
    sohbet: s,
    dosyaAc: dosyaAc,
  );
}

/// Sağ panel: önizleme açıksa o, değilse dosyalar.
Widget _sagPanel(Calisma c) {
  final s = c.secili!;
  final yol = c.onizlenen;
  if (yol != null) {
    return OnizlemePaneli(calisma: c, yol: yol, kapat: () => c.onizle(null));
  }
  return DosyaPaneli(calisma: c, sohbet: s, ac: c.onizle);
}

void _tamSayfa(BuildContext context, Calisma c, String yol) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OnizlemeSayfasi(calisma: c, yol: yol),
    ),
  );
}

Widget? _dosyaCekmecesi(BuildContext context, Calisma c, double genislik) {
  final s = c.secili;
  if (s == null) return null;
  return Drawer(
    width: genislik,
    child: Builder(
      builder: (context) => DosyaPaneli(
        calisma: c,
        sohbet: s,
        ac: (yol) {
          Navigator.of(context).pop();
          _tamSayfa(context, c, yol);
        },
      ),
    ),
  );
}

class _Dar extends StatelessWidget {
  const _Dar({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final c = calisma;
    return Scaffold(
      appBar: _ustCubuk(
        context,
        c,
        menu: true,
        dosyalar: _DosyaDugmesi.cekmece,
      ),
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * .84,
        child: Builder(
          builder: (context) => OturumListesi(
            calisma: c,
            secildi: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      endDrawer: _dosyaCekmecesi(
        context,
        c,
        MediaQuery.sizeOf(context).width * .88,
      ),
      body: _govde(c),
    );
  }
}

class _Orta extends StatelessWidget {
  const _Orta({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final c = calisma;
    return Scaffold(
      endDrawer: _dosyaCekmecesi(context, c, 380),
      body: IkiPanel(
        solGenislik: 268,
        sol: OturumListesi(calisma: c),
        sag: Scaffold(
          appBar: _ustCubuk(context, c, dosyalar: _DosyaDugmesi.cekmece),
          body: _govde(c),
        ),
      ),
    );
  }
}

class _Katlanir extends StatelessWidget {
  const _Katlanir({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final c = calisma;
    return Scaffold(
      drawer: Drawer(
        child: Builder(
          builder: (context) => OturumListesi(
            calisma: c,
            secildi: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: IkiPanel(
        sol: Scaffold(
          appBar: _ustCubuk(context, c, menu: true),
          body: _govde(c, dosyaAc: c.onizle),
        ),
        sag: c.secili == null ? OturumListesi(calisma: c) : _sagPanel(c),
      ),
    );
  }
}

class _Genis extends StatelessWidget {
  const _Genis({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final c = calisma;
    final ayrac = VerticalDivider(
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    final sagAcik = c.secili != null && (c.dosyaPaneli || c.onizlenen != null);
    final sagGenislik = c.onizlenen != null
        ? (MediaQuery.sizeOf(context).width * .38).clamp(380.0, 680.0)
        : 320.0;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 280, child: OturumListesi(calisma: c)),
          ayrac,
          Expanded(
            child: Scaffold(
              appBar: _ustCubuk(context, c, dosyalar: _DosyaDugmesi.panel),
              body: _govde(c, dosyaAc: c.onizle),
            ),
          ),
          if (sagAcik) ...[
            ayrac,
            SizedBox(width: sagGenislik, child: _sagPanel(c)),
          ],
        ],
      ),
    );
  }
}
