import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../arayuz/markdown.dart';
import '../model/calisma.dart';

const _resim = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
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
  'csv',
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
  'svg',
  'gradle',
  'kts',
  'lock',
  'env',
  'gitignore',
};

String uzanti(String yol) {
  final ad = yol.split('/').last.toLowerCase();
  final i = ad.lastIndexOf('.');
  return i < 0 ? ad : ad.substring(i + 1);
}

IconData dosyaSimgesi(String yol) {
  final u = uzanti(yol);
  if (_resim.contains(u)) return Icons.image_outlined;
  if (u == 'pdf') return Icons.picture_as_pdf_outlined;
  if (u == 'md' || u == 'txt') return Icons.article_outlined;
  if (_metin.contains(u)) return Icons.code;
  return Icons.insert_drive_file_outlined;
}

/// Bir dosyanın önizlemesi: resim, PDF, Markdown, kod ya da düz metin.
/// Dosya köprü üzerinden okunur; Termux'un klasörüne doğrudan erişilmez.
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
            errorBuilder: (_, e, _) => _Hata(metin: 'Resim açılamadı: $e'),
          ),
        ),
      );
    }
    if (u == 'pdf') {
      return PdfViewer.uri(adres);
    }
    return _MetinOnizleme(calisma: calisma, yol: yol, markdown: u == 'md');
  }
}

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
    return FutureBuilder(
      future: _veri,
      builder: (context, snap) {
        if (snap.hasError) return _Hata(metin: '${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        if (d['buyuk'] == true) {
          return _Hata(
            metin: 'Dosya önizleme için büyük (${d['boyut']} bayt).',
          );
        }
        if (d['ikili'] == true) {
          return _Hata(metin: 'Bu dosya türü önizlenemiyor (${d['tur']}).');
        }
        final metin = d['metin'] as String? ?? '';
        if (widget.markdown && !_kaynak) {
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [Markdown(metin, size: 15)],
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Kaynağı göster',
                  onPressed: () => setState(() => _kaynak = true),
                  icon: const Icon(Icons.code),
                ),
              ),
            ],
          );
        }
        final satirlar = metin.split('\n');
        final genislik = '${satirlar.length}'.length;
        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(
                TextSpan(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                  children: [
                    for (var i = 0; i < satirlar.length; i++) ...[
                      TextSpan(
                        text: '${'${i + 1}'.padLeft(genislik)}  ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      TextSpan(text: '${satirlar[i]}\n'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hata extends StatelessWidget {
  const _Hata({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(metin, textAlign: TextAlign.center),
    ),
  );
}

/// Dar ekranda tam sayfa önizleme.
class OnizlemeSayfasi extends StatelessWidget {
  const OnizlemeSayfasi({super.key, required this.calisma, required this.yol});

  final Calisma calisma;
  final String yol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(yol.split('/').last)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: t.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Icon(dosyaSimgesi(yol), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    yol.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: kapat,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Onizleme(key: ValueKey(yol), calisma: calisma, yol: yol),
        ),
      ],
    );
  }
}
