import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import 'ortak.dart';

/// Kod bloğunun dil etiketi (```python) ya da dosya uzantısı (py) →
/// renklendirme kuralının adı ve kuralı. Bilinmeyen: null.
(String, Mode)? kodDili(String etiket) => switch (etiket.trim().toLowerCase()) {
  'dart' => ('dart', langDart),
  'py' || 'python' || 'python3' => ('python', langPython),
  'js' ||
  'mjs' ||
  'cjs' ||
  'jsx' ||
  'javascript' ||
  'node' => ('javascript', langJavascript),
  'ts' || 'tsx' || 'typescript' => ('typescript', langTypescript),
  'json' || 'jsonc' || 'json5' || 'arb' => ('json', langJson),
  'yaml' || 'yml' => ('yaml', langYaml),
  'md' || 'markdown' => ('markdown', langMarkdown),
  'html' || 'htm' || 'xml' || 'svg' || 'xhtml' || 'plist' => ('xml', langXml),
  'css' || 'scss' || 'less' => ('css', langCss),
  'sh' ||
  'bash' ||
  'zsh' ||
  'shell' ||
  'console' ||
  'terminal' ||
  'shellscript' => ('bash', langBash),
  'kt' || 'kts' || 'kotlin' => ('kotlin', langKotlin),
  'java' => ('java', langJava),
  'go' || 'golang' => ('go', langGo),
  'rs' || 'rust' => ('rust', langRust),
  'c' || 'h' => ('c', langC),
  'cpp' || 'cc' || 'cxx' || 'hpp' || 'c++' => ('cpp', langCpp),
  'toml' ||
  'ini' ||
  'cfg' ||
  'conf' ||
  'properties' ||
  'env' => ('ini', langIni),
  'sql' || 'sqlite' || 'postgresql' || 'mysql' => ('sql', langSql),
  'gradle' || 'groovy' => ('gradle', langGradle),
  'php' => ('php', langPhp),
  'rb' || 'ruby' => ('ruby', langRuby),
  'swift' => ('swift', langSwift),
  'dockerfile' || 'docker' => ('dockerfile', langDockerfile),
  _ => null,
};

final _vurgulayici = Highlight();

/// Akış sırasında aynı blok her parçada yeniden çizilir; son sonuçları tut.
final _onbellek = <(String, String, bool), TextSpan>{};
const _onbellekBoyu = 64;

/// Bundan uzun kod renklendirilmez (telefonda takılmasın).
const _enUzun = 20000;

/// [kod]'u [etiket] diline göre renkli olarak verir; dil bilinmiyorsa ya da
/// kod çok uzunsa null.
TextSpan? kodRenklendir(
  String kod,
  String etiket,
  TextStyle taban, {
  required bool koyu,
}) {
  final dil = kodDili(etiket);
  if (dil == null || kod.length > _enUzun) return null;
  final anahtar = (dil.$1, kod, koyu);
  final eski = _onbellek.remove(anahtar);
  if (eski != null) return _onbellek[anahtar] = eski;
  final tema = koyu ? atomOneDarkTheme : atomOneLightTheme;
  try {
    _vurgulayici.registerLanguage(dil.$1, dil.$2);
    final sonuc = _vurgulayici.highlight(code: kod, language: dil.$1);
    final cizici = TextSpanRenderer(
      taban.copyWith(color: tema['root']?.color),
      tema,
    );
    sonuc.render(cizici);
    final span = cizici.span;
    if (span == null) return null;
    if (_onbellek.length >= _onbellekBoyu) {
      _onbellek.remove(_onbellek.keys.first);
    }
    return _onbellek[anahtar] = span;
  } catch (_) {
    return null; // bozuk ya da yarım kod: düz göster
  }
}

/// Yanıttaki kod bloğu: dil adı ve Kopyala düğmesi olan başlık, renkli kod,
/// uzun satırlar kaydırılarak (alt satıra kaymaz).
class KodBlogu extends StatefulWidget {
  const KodBlogu({
    super.key,
    required this.metin,
    this.dil = '',
    this.boyut = 13.5,
  });

  final String metin;
  final String dil;
  final double boyut;

  @override
  State<KodBlogu> createState() => _KodBloguState();
}

class _KodBloguState extends State<KodBlogu> {
  bool _kopyalandi = false;
  Timer? _sayac;

  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  Future<void> _kopyala() async {
    await Clipboard.setData(ClipboardData(text: widget.metin));
    if (!mounted) return;
    setState(() => _kopyalandi = true);
    _sayac?.cancel();
    _sayac = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _kopyalandi = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final koyu = t.brightness == Brightness.dark;
    final taban = monospace.copyWith(
      fontSize: widget.boyut - 1.5,
      height: 1.55,
      color: r.onSurface,
    );
    final renkli = kodRenklendir(widget.metin, widget.dil, taban, koyu: koyu);
    final etiket = widget.dil.trim().isEmpty ? 'kod' : widget.dil.trim();
    final soluk = t.textTheme.labelMedium?.copyWith(color: r.onSurfaceVariant);
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: r.surfaceContainerLow,
        border: Border.all(color: r.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık seçime girmesin: kopyalanan metne "python Kopyala" karışmaz.
          SelectionContainer.disabled(
            child: Container(
              color: r.surfaceContainerHigh,
              padding: const EdgeInsets.only(left: 12, right: 4),
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      etiket,
                      style: soluk,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _kopyala,
                    style: TextButton.styleFrom(
                      foregroundColor: r.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: t.textTheme.labelMedium,
                    ),
                    icon: Icon(
                      _kopyalandi ? Icons.check_rounded : Icons.copy_rounded,
                      size: 15,
                    ),
                    label: Text(_kopyalandi ? 'Kopyalandı' : 'Kopyala'),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Text.rich(
              renkli ?? TextSpan(text: widget.metin, style: taban),
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}
