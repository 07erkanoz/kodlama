import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
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

import '../model/calisma.dart';

/// Uzantıya göre sözdizimi renklendirme kuralı (yoksa düz metin).
Mode? _dil(String yol) {
  final ad = yol.split('/').last.toLowerCase();
  if (ad == 'dockerfile') return langDockerfile;
  return switch (ad.split('.').last) {
    'dart' => langDart,
    'py' => langPython,
    'js' || 'mjs' || 'cjs' || 'jsx' => langJavascript,
    'ts' || 'tsx' => langTypescript,
    'json' || 'arb' => langJson,
    'yaml' || 'yml' => langYaml,
    'md' || 'markdown' => langMarkdown,
    'html' || 'htm' || 'xml' || 'svg' => langXml,
    'css' || 'scss' => langCss,
    'sh' || 'bash' || 'zsh' => langBash,
    'kt' || 'kts' => langKotlin,
    'java' => langJava,
    'go' => langGo,
    'rs' => langRust,
    'c' || 'h' => langC,
    'cpp' || 'cc' || 'hpp' => langCpp,
    'toml' || 'ini' || 'cfg' || 'properties' => langIni,
    'sql' => langSql,
    'gradle' => langGradle,
    'php' => langPhp,
    'rb' => langRuby,
    'swift' => langSwift,
    _ => null,
  };
}

/// Bir metin dosyasını düzenler ve köprü üzerinden kaydeder. Dosya okunduktan
/// sonra (örneğin ajan tarafından) değiştiyse kaydederken sorar.
class DosyaDuzenleyici extends StatefulWidget {
  const DosyaDuzenleyici({
    super.key,
    required this.calisma,
    required this.yol,
    required this.metin,
    required this.mtime,
  });

  final Calisma calisma;
  final String yol;
  final String metin;
  final double? mtime;

  @override
  State<DosyaDuzenleyici> createState() => _DosyaDuzenleyiciState();
}

class _DosyaDuzenleyiciState extends State<DosyaDuzenleyici> {
  late final _d = CodeLineEditingController.fromText(widget.metin);
  late String _kayitli = widget.metin;
  late double? _mtime = widget.mtime;
  bool _kaydediliyor = false;
  bool _kaydirma = false;

  bool get _degisti => _d.text != _kayitli;

  @override
  void initState() {
    super.initState();
    _d.addListener(_degisim);
  }

  bool _sonDurum = false;
  void _degisim() {
    final d = _degisti;
    if (d != _sonDurum) setState(() => _sonDurum = d);
  }

  @override
  void dispose() {
    _d.removeListener(_degisim);
    _d.dispose();
    super.dispose();
  }

  Future<bool> _kaydet({bool zorla = false}) async {
    if (_kaydediliyor) return false;
    setState(() => _kaydediliyor = true);
    final metin = _d.text;
    try {
      final r = await widget.calisma.istemci.iste('yaz', {
        'yol': widget.yol,
        'metin': metin,
        'once': _mtime,
        'zorla': zorla,
      });
      _kayitli = metin;
      _mtime = (r['mtime'] as num?)?.toDouble();
      _sonDurum = _degisti;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kaydedildi.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      if ('$e'.contains('degisti')) {
        final ustune = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Dosya değişti'),
            content: const Text(
              'Sen düzenlerken dosya başka biri (muhtemelen ajan) tarafından '
              'değiştirildi. Kendi halini üstüne yazarsan o değişiklikler kaybolur.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Üstüne yaz'),
              ),
            ],
          ),
        );
        if (ustune == true) {
          setState(() => _kaydediliyor = false);
          return _kaydet(zorla: true);
        }
        return false;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Future<void> _cikis() async {
    final secim = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text('Çıkmadan önce kaydedilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'at'),
            child: const Text('Kaydetme'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'kaydet'),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'kaydet' && !await _kaydet()) return;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final koyu = t.brightness == Brightness.dark;
    final dil = _dil(widget.yol);
    return PopScope(
      canPop: !_degisti,
      onPopInvokedWithResult: (bitti, _) {
        if (!bitti) _cikis();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${_degisti ? '• ' : ''}${widget.yol.split('/').last}',
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            ValueListenableBuilder(
              valueListenable: _d,
              builder: (context, _, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Geri al',
                    onPressed: _d.canUndo ? _d.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Yinele',
                    onPressed: _d.canRedo ? _d.redo : null,
                    icon: const Icon(Icons.redo),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _kaydirma ? 'Satırları kaydırma' : 'Satırları kaydır',
              isSelected: _kaydirma,
              onPressed: () => setState(() => _kaydirma = !_kaydirma),
              icon: const Icon(Icons.wrap_text),
            ),
            IconButton(
              tooltip: 'Kaydet (Ctrl+S)',
              onPressed: _degisti && !_kaydediliyor ? () => _kaydet() : null,
              icon: _kaydediliyor
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: CodeEditor(
            controller: _d,
            autofocus: false,
            // Ctrl+S düzenleyicinin kendi kısayolu: kaydet.
            shortcutOverrideActions: {
              CodeShortcutSaveIntent: CallbackAction<CodeShortcutSaveIntent>(
                onInvoke: (_) => _kaydet(),
              ),
            },
            wordWrap: _kaydirma,
            style: CodeEditorStyle(
              fontSize: 13.5,
              fontFamily: 'monospace',
              fontHeight: 1.5,
              backgroundColor: r.surface,
              textColor: r.onSurface,
              cursorColor: r.primary,
              selectionColor: r.primary.withValues(alpha: .25),
              cursorLineColor: r.onSurface.withValues(alpha: .04),
              codeTheme: CodeHighlightTheme(
                languages: {
                  if (dil != null) 'kod': CodeHighlightThemeMode(mode: dil),
                },
                theme: koyu ? atomOneDarkTheme : atomOneLightTheme,
              ),
            ),
            indicatorBuilder:
                (context, editingController, chunkController, notifier) => Row(
                  children: [
                    DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                    ),
                    DefaultCodeChunkIndicator(
                      width: 16,
                      controller: chunkController,
                      notifier: notifier,
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
