import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arayuz/ortak.dart';
import '../arayuz/yerlesim.dart';
import '../model/calisma.dart';
import '../servis/guncelleme.dart';
import '../servis/termux.dart';
import 'canli_onizleme.dart';
import 'baslangic_ekrani.dart';
import 'dosya_paneli.dart';
import 'onizleme.dart';
import 'oturum_listesi.dart';
import 'sohbet_gorunumu.dart';
import 'terminal_sayfasi.dart';

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
class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key, required this.calisma});

  final Calisma calisma;

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  Calisma get calisma => widget.calisma;
  DateTime? _sonGeri;

  /// Android geri tuşu uygulamayı hemen kapatmasın: önce açık çekmece,
  /// sonra önizleme, sonra oturumdan başlangıca döner; başlangıçta iki kez
  /// basınca çıkar.
  void _geri(BuildContext context) {
    final rota = ModalRoute.of(context);
    if (rota != null && rota.willHandlePopInternally) {
      // Açık çekmece (oturumlar ya da dosyalar): onu kapat.
      Navigator.of(context).pop();
      return;
    }
    final c = calisma;
    if (c.onizlenen != null) {
      c.onizle(null);
      return;
    }
    if (c.secili != null) {
      c.baslangica();
      return;
    }
    final simdi = DateTime.now();
    if (_sonGeri != null &&
        simdi.difference(_sonGeri!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _sonGeri = simdi;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Çıkmak için bir kez daha geri bas'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _guncellemeyeBak());
  }

  /// Açılışta (günde en çok bir kez) GitHub'da yeni sürüm var mı; varsa söyle.
  Future<void> _guncellemeyeBak() async {
    final a = calisma.ayarlar;
    if (!Termux.destekleniyor || !a.guncellemeDenetle) return;
    final simdi = DateTime.now().millisecondsSinceEpoch;
    if (simdi - a.sonGuncellemeDenetimi <
        const Duration(hours: 20).inMilliseconds) {
      return;
    }
    try {
      await guncellemeDenetle(); // bulunursa yeniSurum'a yazar; şerit onu dinler
      a.sonGuncellemeDenetimi = simdi;
    } catch (_) {
      // Ağ yoksa sessiz geç; Ayarlar'dan elle denetlenebilir.
    }
  }

  /// Güncelleme şeridi bu açılışta kapatıldı mı ("Sonra").
  bool _seritKapali = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bitti, _) {
        if (!bitti) _geri(context);
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([yeniSurum, guncellemeIndirmesi]),
        builder: (context, _) {
          final yeni = yeniSurum.value;
          final ind = guncellemeIndirmesi.value;
          final serit =
              yeni != null &&
              (!_seritKapali || ind.calisiyor || ind.hata != null);
          final duzen = ListenableBuilder(
            listenable: calisma,
            builder: (context, _) => LayoutBuilder(
              builder: (context, kisit) {
                if (dikeyMentese(context) != null) {
                  return _Katlanir(calisma: calisma);
                }
                return switch (ekranSinifi(kisit.maxWidth)) {
                  EkranSinifi.dar => _Dar(calisma: calisma),
                  EkranSinifi.orta => _Orta(calisma: calisma),
                  EkranSinifi.genis => _Genis(calisma: calisma),
                };
              },
            ),
          );
          if (!serit) return duzen;
          return Column(
            children: [
              _GuncellemeSeridi(
                surum: yeni,
                durum: ind,
                kapat: () => setState(() => _seritKapali = true),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: duzen,
                ),
              ),
            ],
          );
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
  bool kenar = false,
  _DosyaDugmesi dosyalar = _DosyaDugmesi.yok,
}) {
  final s = c.secili;
  final t = Theme.of(context);
  final r = t.colorScheme;
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 56,
    titleSpacing: menu || kenar ? 0 : 20,
    leading: kenar
        ? IconButton(
            tooltip: c.kenarCubugu
                ? 'Oturum listesini gizle'
                : 'Oturum listesini göster',
            onPressed: c.kenarCubuguDegistir,
            icon: Icon(
              c.kenarCubugu ? Icons.menu_open_rounded : Icons.menu_rounded,
            ),
          )
        : menu
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
            if (v == 'terminal') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TerminalSayfasi(calisma: c, cwd: s.cwd),
                ),
              );
            }
            if (v == 'onizle') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CanliOnizleme(calisma: c)),
              );
            }
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
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'yeni', child: Text('Yeni oturum')),
            if (s.sunucu == null && c.yetenek('terminal'))
              const PopupMenuItem(value: 'terminal', child: Text('Terminal')),
            const PopupMenuItem(
              value: 'onizle',
              child: Text('Yerel sunucuyu önizle'),
            ),
            const PopupMenuItem(value: 'sil', child: Text('Oturumu sil')),
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
        solAcik: c.kenarCubugu,
        sol: OturumListesi(calisma: c),
        sag: Scaffold(
          appBar: _ustCubuk(
            context,
            c,
            kenar: true,
            dosyalar: _DosyaDugmesi.cekmece,
          ),
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
          Kayan(
            genislik: c.kenarCubugu ? 280 : 0,
            child: OturumListesi(calisma: c),
          ),
          if (c.kenarCubugu) ayrac,
          Expanded(
            child: Scaffold(
              appBar: _ustCubuk(
                context,
                c,
                kenar: true,
                dosyalar: _DosyaDugmesi.panel,
              ),
              body: _govde(c, dosyaAc: c.onizle),
            ),
          ),
          if (sagAcik) ayrac,
          Kayan(
            sagda: true,
            genislik: sagAcik ? sagGenislik : 0,
            child: c.secili == null ? const SizedBox.shrink() : _sagPanel(c),
          ),
        ],
      ),
    );
  }
}

/// Yeni sürüm var: ana ekranın üstünde, kapatılana dek duran şerit. "İndir ve
/// kur" Ayarlar'dakiyle aynı indirmeyi başlatır, ilerleme burada da görünür.
class _GuncellemeSeridi extends StatelessWidget {
  const _GuncellemeSeridi({
    required this.surum,
    required this.durum,
    required this.kapat,
  });

  final Surum surum;
  final IndirmeDurumu durum;
  final VoidCallback kapat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final oran = durum.oran;
    return Material(
      color: r.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.system_update_alt_rounded,
                    color: r.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          durum.calisiyor
                              ? 'Güncelleme indiriliyor'
                              : 'Yeni sürüm var: ${surum.ad}',
                          style: t.textTheme.titleSmall?.copyWith(
                            color: r.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          durum.calisiyor
                              ? [
                                  if (oran != null)
                                    '%${(oran * 100).toStringAsFixed(0)}',
                                  if (surum.boyut > 0)
                                    '${(surum.boyut / 1e6).toStringAsFixed(0)} MB',
                                ].join(' · ')
                              : durum.hata ??
                                    [
                                      'yapı ${surum.kod}',
                                      if (surum.boyut > 0)
                                        '${(surum.boyut / 1e6).toStringAsFixed(0)} MB',
                                    ].join(' · '),
                          style: t.textTheme.bodySmall?.copyWith(
                            color: durum.hata != null && !durum.calisiyor
                                ? r.error
                                : r.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!durum.calisiyor) ...[
                    TextButton(onPressed: kapat, child: const Text('Sonra')),
                    FilledButton(
                      onPressed: () => guncellemeyiBaslat(surum),
                      child: Text(
                        durum.hata != null ? 'Yeniden dene' : 'İndir ve kur',
                      ),
                    ),
                  ],
                ],
              ),
              if (durum.calisiyor) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LinearProgressIndicator(value: oran),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
