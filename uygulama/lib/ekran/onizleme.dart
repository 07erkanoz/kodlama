import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'duzenleyici.dart';
import '../arayuz/markdown.dart';
import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../servis/dosya_disari.dart';

const _resim = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _ses = {'mp3', 'wav', 'ogg', 'oga', 'opus', 'm4a', 'aac', 'flac', 'weba'};
const _video = {'mp4', 'webm', 'mkv', 'mov', 'avi', 'm4v', '3gp'};
const _belge = {'docx', 'pptx', 'xlsx', 'xlsm', 'csv', 'tsv'};
const _metin = {
  'txt',
  'md',
  'markdown',
  'py',
  'dart',
  'js',
  'ts',
  'tsx',
  'jsx',
  'json',
  'yaml',
  'yml',
  'toml',
  'sh',
  'bash',
  'html',
  'htm',
  'css',
  'xml',
  'kt',
  'java',
  'c',
  'h',
  'cpp',
  'rs',
  'go',
  'rb',
  'php',
  'sql',
  'ini',
  'cfg',
  'conf',
  'log',
  'gradle',
  'kts',
  'lock',
  'env',
  'gitignore',
  'srt',
  'vtt',
};

String uzanti(String yol) {
  final ad = yol.split('/').last.toLowerCase();
  final i = ad.lastIndexOf('.');
  return i < 0 ? ad : ad.substring(i + 1);
}

IconData dosyaSimgesi(String yol) {
  final u = uzanti(yol);
  if (_resim.contains(u) || u == 'svg') return Icons.image_outlined;
  if (_ses.contains(u)) return Icons.audiotrack_outlined;
  if (_video.contains(u)) return Icons.movie_outlined;
  if (u == 'pdf') return Icons.picture_as_pdf_outlined;
  if (u == 'docx' || u == 'md' || u == 'txt') return Icons.article_outlined;
  if (u == 'xlsx' || u == 'xlsm' || u == 'csv' || u == 'tsv') {
    return Icons.table_chart_outlined;
  }
  if (u == 'pptx') return Icons.slideshow_outlined;
  if (u == 'html' || u == 'htm') return Icons.language;
  if (_metin.contains(u)) return Icons.code;
  return Icons.insert_drive_file_outlined;
}

/// Bir dosyanın önizlemesi. Dosya köprü üzerinden okunur; Termux'un
/// klasörüne doğrudan erişilmez. Tanınmayan türlerde "başka uygulamada
/// aç" önerilir.
class Onizleme extends StatelessWidget {
  const Onizleme({super.key, required this.calisma, required this.yol});

  final Calisma calisma;
  final String yol;

  @override
  Widget build(BuildContext context) {
    final u = uzanti(yol);
    final adres = calisma.istemci.dosyaAdresi(yol);
    if (_resim.contains(u)) {
      return InteractiveViewer(
        maxScale: 8,
        child: Center(
          child: Image.network(
            adres.toString(),
            errorBuilder: (_, e, _) => _Bilgi(
              simge: Icons.broken_image_outlined,
              metin: 'Resim açılamadı: $e',
            ),
          ),
        ),
      );
    }
    if (u == 'svg') {
      return InteractiveViewer(
        maxScale: 8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SvgPicture.network(adres.toString()),
          ),
        ),
      );
    }
    if (u == 'pdf') return PdfViewer.uri(adres);
    if (_ses.contains(u) || _video.contains(u)) {
      return _Oynatici(
        adres: adres,
        ses: _ses.contains(u),
        ad: yol.split('/').last,
      );
    }
    if (_belge.contains(u)) return _BelgeOnizleme(calisma: calisma, yol: yol);
    if (u == 'html' || u == 'htm') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: FilledButton.tonalIcon(
              onPressed: () => launchUrl(
                calisma.istemci.sayfaAdresi(yol),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Tarayıcıda aç'),
            ),
          ),
          Expanded(
            child: _MetinOnizleme(calisma: calisma, yol: yol, markdown: false),
          ),
        ],
      );
    }
    return _MetinOnizleme(
      calisma: calisma,
      yol: yol,
      markdown: u == 'md' || u == 'markdown',
    );
  }
}

// ---------------------------------------------------------------- ses, video

class _Oynatici extends StatefulWidget {
  const _Oynatici({required this.adres, required this.ses, required this.ad});
  final Uri adres;
  final bool ses;
  final String ad;

  @override
  State<_Oynatici> createState() => _OynaticiState();
}

class _OynaticiState extends State<_Oynatici> {
  late final Player _oynatici = Player();
  late final VideoController _video = VideoController(_oynatici);
  String? _hata;
  StreamSubscription? _hataAbone;

  @override
  void initState() {
    super.initState();
    _hataAbone = _oynatici.stream.error.listen(
      (e) => setState(() => _hata = e),
    );
    _oynatici.open(Media(widget.adres.toString()), play: false);
  }

  @override
  void dispose() {
    _hataAbone?.cancel();
    _oynatici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return _Bilgi(simge: Icons.error_outline, metin: 'Oynatılamadı: $_hata');
    }
    if (!widget.ses) {
      return ColoredBox(
        color: Colors.black,
        child: Video(controller: _video),
      );
    }
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: r.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.graphic_eq, size: 56, color: r.primary),
              ),
              const SizedBox(height: 18),
              Text(
                widget.ad,
                style: t.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              StreamBuilder(
                stream: _oynatici.stream.position,
                builder: (context, _) {
                  final s = _oynatici.state;
                  final sure = s.duration.inMilliseconds.toDouble();
                  final konum = s.position.inMilliseconds
                      .toDouble()
                      .clamp(0, sure > 0 ? sure : 1)
                      .toDouble();
                  return Column(
                    children: [
                      Slider(
                        value: konum,
                        max: sure > 0 ? sure : 1,
                        onChanged: sure > 0
                            ? (v) => _oynatici.seek(
                                Duration(milliseconds: v.round()),
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text(
                              _sure(s.position),
                              style: t.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            Text(
                              _sure(s.duration),
                              style: t.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder(
                stream: _oynatici.stream.playing,
                builder: (context, _) => IconButton.filled(
                  iconSize: 34,
                  onPressed: _oynatici.playOrPause,
                  icon: Icon(
                    _oynatici.state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sure(Duration d) {
    if (d.isNegative || d.inHours > 99) return '–:––';
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------- belgeler

class _BelgeOnizleme extends StatefulWidget {
  const _BelgeOnizleme({required this.calisma, required this.yol});
  final Calisma calisma;
  final String yol;

  @override
  State<_BelgeOnizleme> createState() => _BelgeOnizlemeState();
}

class _BelgeOnizlemeState extends State<_BelgeOnizleme> {
  late Future<Map<String, dynamic>> _veri = _oku();

  Future<Map<String, dynamic>> _oku() =>
      widget.calisma.istemci.iste('belge', {'yol': widget.yol});

  @override
  void didUpdateWidget(_BelgeOnizleme old) {
    super.didUpdateWidget(old);
    if (old.yol != widget.yol) _veri = _oku();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _veri,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Bilgi(
            simge: Icons.error_outline,
            metin: 'Belge okunamadı: ${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        if (d['tur'] == 'tablo') {
          final sayfalar = (d['sayfalar'] as List).cast<Map>();
          if (sayfalar.isEmpty) {
            return const _Bilgi(
              simge: Icons.table_chart_outlined,
              metin: 'Boş tablo.',
            );
          }
          return _Tablolar(sayfalar: sayfalar);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [Markdown(d['metin'] as String? ?? '', size: 15)],
        );
      },
    );
  }
}

class _Tablolar extends StatelessWidget {
  const _Tablolar({required this.sayfalar});
  final List<Map> sayfalar;

  @override
  Widget build(BuildContext context) {
    if (sayfalar.length == 1) {
      return _Tablo(
        satirlar: (sayfalar.first['satirlar'] as List).cast<List>(),
      );
    }
    return DefaultTabController(
      length: sayfalar.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final s in sayfalar) Tab(text: s['ad'] as String? ?? ''),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final s in sayfalar)
                  _Tablo(satirlar: (s['satirlar'] as List).cast<List>()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tablo extends StatelessWidget {
  const _Tablo({required this.satirlar});
  final List<List> satirlar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (satirlar.isEmpty) {
      return const _Bilgi(
        simge: Icons.table_chart_outlined,
        metin: 'Boş sayfa.',
      );
    }
    final sutun = satirlar
        .map((s) => s.length)
        .fold(0, (a, b) => a > b ? a : b);
    final kenar = BorderSide(color: r.outlineVariant);
    Widget hucre(String metin, {bool baslik = false, bool no = false}) =>
        Container(
          constraints: BoxConstraints(minWidth: no ? 44 : 80, maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: baslik || no ? r.surfaceContainer : null,
            border: Border(right: kenar, bottom: kenar),
          ),
          child: Text(
            metin,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: no ? TextAlign.right : TextAlign.start,
            style: (no ? t.textTheme.labelSmall : t.textTheme.bodySmall)
                ?.copyWith(
                  fontWeight: baslik ? FontWeight.w600 : null,
                  color: no ? r.onSurfaceVariant : r.onSurface,
                ),
          ),
        );
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: kenar, left: kenar),
            ),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                TableRow(
                  children: [
                    hucre('', no: true),
                    for (var j = 0; j < sutun; j++)
                      hucre(_sutunAdi(j), baslik: true),
                  ],
                ),
                for (var i = 0; i < satirlar.length; i++)
                  TableRow(
                    children: [
                      hucre('${i + 1}', no: true),
                      for (var j = 0; j < sutun; j++)
                        hucre(
                          j < satirlar[i].length ? '${satirlar[i][j]}' : '',
                          baslik: i == 0,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _sutunAdi(int n) {
    var s = '';
    n++;
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }
}

// ---------------------------------------------------------------- metin

class _MetinOnizleme extends StatefulWidget {
  const _MetinOnizleme({
    required this.calisma,
    required this.yol,
    required this.markdown,
  });

  final Calisma calisma;
  final String yol;
  final bool markdown;

  @override
  State<_MetinOnizleme> createState() => _MetinOnizlemeState();
}

class _MetinOnizlemeState extends State<_MetinOnizleme> {
  late Future<Map<String, dynamic>> _veri = _oku();
  bool _kaynak = false;

  Future<Map<String, dynamic>> _oku() =>
      widget.calisma.istemci.iste('oku', {'yol': widget.yol});

  @override
  void didUpdateWidget(_MetinOnizleme old) {
    super.didUpdateWidget(old);
    if (old.yol != widget.yol) _veri = _oku();
  }

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _veri,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Bilgi(simge: Icons.error_outline, metin: '${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        if (d['buyuk'] == true) {
          return _Bilgi(
            simge: Icons.insert_drive_file_outlined,
            metin:
                'Dosya önizleme için büyük (${d['boyut']} bayt). Başka uygulamada açabilirsin.',
          );
        }
        if (d['ikili'] == true) {
          return _Bilgi(
            simge: Icons.insert_drive_file_outlined,
            metin:
                'Bu dosya türü burada önizlenemiyor${(d['tur'] as String? ?? '').isEmpty ? '' : ' (${d['tur']})'}.\n'
                'Üstteki düğmeyle başka bir uygulamada açabilir ya da paylaşabilirsin.',
          );
        }
        final metin = d['metin'] as String? ?? '';
        final duzenle = widget.calisma.yetenek('duzenle')
            ? Positioned(
                right: 14,
                bottom: 14,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Düzenle',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DosyaDuzenleyici(
                          calisma: widget.calisma,
                          yol: widget.yol,
                          metin: metin,
                          mtime: (d['mtime'] as num?)?.toDouble(),
                        ),
                      ),
                    );
                    if (mounted) setState(() => _veri = _oku());
                  },
                  child: const Icon(Icons.edit_outlined),
                ),
              )
            : null;
        if (widget.markdown && !_kaynak) {
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [Markdown(metin, size: 15)],
              ),
              Positioned(
                right: 10,
                top: 10,
                child: IconButton.filledTonal(
                  tooltip: 'Kaynağı göster',
                  onPressed: () => setState(() => _kaynak = true),
                  icon: const Icon(Icons.code),
                ),
              ),
              ?duzenle,
            ],
          );
        }
        final satirlar = metin.split('\n');
        final genislik = '${satirlar.length}'.length;
        final kod = Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(
                TextSpan(
                  style: monospace.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                    color: r.onSurface,
                  ),
                  children: [
                    for (var i = 0; i < satirlar.length; i++) ...[
                      TextSpan(
                        text: '${'${i + 1}'.padLeft(genislik)}  ',
                        style: TextStyle(color: r.outline),
                      ),
                      TextSpan(text: '${satirlar[i]}\n'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
        return duzenle == null
            ? kod
            : Stack(fit: StackFit.expand, children: [kod, duzenle]);
      },
    );
  }
}

class _Bilgi extends StatelessWidget {
  const _Bilgi({required this.simge, required this.metin});
  final IconData simge;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(simge, size: 40, color: r.outline),
            const SizedBox(height: 12),
            Text(
              metin,
              textAlign: TextAlign.center,
              style: TextStyle(color: r.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- çerçeve

/// Başka uygulamada aç ve paylaş düğmeleri.
List<Widget> _disariDugmeleri(BuildContext context, Calisma c, String yol) {
  final ad = yol.split('/').last;
  Future<void> dene(Future<void> Function() is_) async {
    try {
      await is_();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  return [
    IconButton(
      tooltip: 'Başka uygulamada aç',
      onPressed: () =>
          dene(() => baskaUygulamadaAc(c.istemci.dosyaAdresi(yol), ad)),
      icon: const Icon(Icons.open_in_new),
    ),
    IconButton(
      tooltip: 'Paylaş',
      onPressed: () => dene(() => paylas(c.istemci.dosyaAdresi(yol), ad)),
      icon: const Icon(Icons.ios_share),
    ),
  ];
}

/// Dar ekranda tam sayfa önizleme.
class OnizlemeSayfasi extends StatelessWidget {
  const OnizlemeSayfasi({super.key, required this.calisma, required this.yol});

  final Calisma calisma;
  final String yol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(yol.split('/').last),
        actions: [
          ..._disariDugmeleri(context, calisma, yol),
          const SizedBox(width: 4),
        ],
      ),
      body: Onizleme(calisma: calisma, yol: yol),
    );
  }
}

/// Geniş ekranda yan panelin başlığıyla birlikte önizleme.
class OnizlemePaneli extends StatelessWidget {
  const OnizlemePaneli({
    super.key,
    required this.calisma,
    required this.yol,
    required this.kapat,
  });

  final Calisma calisma;
  final String yol;
  final VoidCallback kapat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: r.surface,
            border: Border(bottom: BorderSide(color: r.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(dosyaSimgesi(yol), size: 18, color: r.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  yol.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ..._disariDugmeleri(context, calisma, yol),
              IconButton(
                tooltip: 'Kapat',
                onPressed: kapat,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: Onizleme(key: ValueKey(yol), calisma: calisma, yol: yol),
        ),
      ],
    );
  }
}
