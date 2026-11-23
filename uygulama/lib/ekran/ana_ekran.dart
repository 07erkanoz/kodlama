import 'package:flutter/material.dart';

import '../arayuz/yerlesim.dart';
import '../model/calisma.dart';
import '../model/sohbet.dart';
import '../servis/kopru_istemci.dart';
import 'dosya_paneli.dart';
import 'onizleme.dart';
import 'oturum_listesi.dart';
import 'sohbet_gorunumu.dart';

/// Uygulamanın ana düzeni. Ekran boyuna ve katlanır telefonun menteşesine
/// göre değişir; durum ([Calisma]) değişmediği için katlayıp açınca sohbet
/// kaldığı yerden sürer.
///
///   dar (telefon)       : sohbet tam ekran; oturumlar soldan, dosyalar
///                         sağdan çekmece; önizleme tam sayfa
///   orta (açık katlanır,
///         küçük tablet) : oturumlar | sohbet; dosyalar ve önizleme sağ
///                         çekmecede / tam sayfada
///   menteşeli katlanır  : sohbet | dosyalar ya da önizleme (menteşeye göre
///                         bölünür), oturumlar soldan çekmece
///   geniş (tablet)      : oturumlar | sohbet | dosyalar ya da önizleme
class AnaEkran extends StatelessWidget {
  const AnaEkran({super.key, required this.calisma});

  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calisma,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, kisit) {
            final sinif = ekranSinifi(kisit.maxWidth);
            final mentese = dikeyMentese(context);
            if (mentese != null) return _Katlanir(calisma: calisma);
            return switch (sinif) {
              EkranSinifi.dar => _Dar(calisma: calisma),
              EkranSinifi.orta => _Orta(calisma: calisma),
              EkranSinifi.genis => _Genis(calisma: calisma),
            };
          },
        );
      },
    );
  }
}

PreferredSizeWidget _ustCubuk(
  BuildContext context,
  Calisma c, {
  bool menu = false,
  bool dosyalar = false,
}) {
  final s = c.secili;
  return AppBar(
    automaticallyImplyLeading: false,
    leading: menu
        ? Builder(
            builder: (context) => IconButton(
              tooltip: 'Oturumlar',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
            ),
          )
        : null,
    title: s == null
        ? const Text('Atölye')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.baslik, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${s.ajan == 'claude' ? 'Claude Code' : 'Codex'} · ${s.cwd.split('/').last}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
    actions: [
      if (s != null) _ModSecici(sohbet: s),
      if (s != null && dosyalar)
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Dosyalar',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.folder_open_outlined),
          ),
        ),
    ],
  );
}

Widget _sohbetAlani(Calisma c, {void Function(String)? dosyaAc}) {
  final s = c.secili;
  if (s == null) return _Karsilama(calisma: c);
  return SohbetGorunumu(
    key: ValueKey(s.id),
    calisma: c,
    sohbet: s,
    dosyaAc: dosyaAc,
  );
}

/// Sağ panel: önizleme açıksa o, değilse dosyalar.
Widget _sagPanel(Calisma c) {
  final s = c.secili;
  if (s == null) return const SizedBox.shrink();
  final yol = c.onizlenen;
  if (yol != null) {
    return OnizlemePaneli(calisma: c, yol: yol, kapat: () => c.onizle(null));
  }
  return DosyaPaneli(calisma: c, sohbet: s, ac: c.onizle);
}

class _Dar extends StatelessWidget {
  const _Dar({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final c = calisma;
    final s = c.secili;
    return Scaffold(
      appBar: _ustCubuk(context, c, menu: true, dosyalar: true),
      drawer: Drawer(
        child: Builder(
          builder: (context) => OturumListesi(
            calisma: c,
            secildi: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      endDrawer: s == null
          ? null
          : Drawer(
              width: MediaQuery.sizeOf(context).width * .86,
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
            ),
      body: _sohbetAlani(c),
    );
  }
}

void _tamSayfa(BuildContext context, Calisma c, String yol) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OnizlemeSayfasi(calisma: c, yol: yol),
    ),
  );
}

class _Orta extends StatelessWidget {
  const _Orta({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final c = calisma;
    final s = c.secili;
    return Scaffold(
      endDrawer: s == null
          ? null
          : Drawer(
              width: 360,
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
            ),
      body: IkiPanel(
        solGenislik: 280,
        sol: OturumListesi(calisma: c),
        sag: Scaffold(
          appBar: _ustCubuk(context, c, dosyalar: true),
          body: _sohbetAlani(c),
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
          body: _sohbetAlani(c, dosyaAc: c.onizle),
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
    final sagGenislik = c.onizlenen != null
        ? (MediaQuery.sizeOf(context).width * .38).clamp(360.0, 640.0)
        : 340.0;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 300, child: OturumListesi(calisma: c)),
          ayrac,
          Expanded(
            child: Scaffold(
              appBar: _ustCubuk(context, c),
              body: _sohbetAlani(c, dosyaAc: c.onizle),
            ),
          ),
          if (c.secili != null) ...[
            ayrac,
            SizedBox(width: sagGenislik, child: _sagPanel(c)),
          ],
        ],
      ),
    );
  }
}

class _ModSecici extends StatelessWidget {
  const _ModSecici({required this.sohbet});
  final Sohbet sohbet;

  static const _modlar = {
    'sor': ('Sor', Icons.back_hand_outlined),
    'duzenle': ('Düzenle', Icons.edit_note),
    'plan': ('Plan', Icons.map_outlined),
    'serbest': ('Serbest', Icons.bolt),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sohbet,
      builder: (context, _) {
        final (ad, simge) = _modlar[sohbet.mod] ?? _modlar['sor']!;
        return PopupMenuButton<String>(
          tooltip: 'Çalışma biçimi',
          enabled: !sohbet.calisiyor,
          onSelected: sohbet.modDegistir,
          itemBuilder: (_) => [
            for (final MapEntry(key: k, value: (a, i)) in _modlar.entries)
              CheckedPopupMenuItem(
                value: k,
                checked: k == sohbet.mod,
                child: Row(
                  children: [
                    Icon(i, size: 18),
                    const SizedBox(width: 8),
                    Text(a),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: Icon(simge, size: 16),
              label: Text(ad),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}

class _Karsilama extends StatelessWidget {
  const _Karsilama({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bagli = calisma.baglanti == BaglantiDurumu.bagli;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handyman_outlined,
              size: 48,
              color: t.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              bagli
                  ? 'Bir oturum seç ya da yenisini aç.'
                  : 'Köprüye bağlanılıyor…',
              style: t.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!bagli) ...[
              const SizedBox(height: 8),
              Text(
                'Termux\'ta "atolye-kopru" çalışıyor olmalı.',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
