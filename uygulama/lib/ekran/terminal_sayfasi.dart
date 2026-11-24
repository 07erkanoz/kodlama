import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../model/calisma.dart';
import '../model/terminal_oturumu.dart';

/// Proje klasöründe gerçek bir kabuk. Telefon klavyesinde olmayan tuşlar
/// (Esc, Tab, Ctrl+C, oklar…) alttaki çubuktadır.
class TerminalSayfasi extends StatefulWidget {
  const TerminalSayfasi({super.key, required this.calisma, required this.cwd});

  final Calisma calisma;
  final String cwd;

  @override
  State<TerminalSayfasi> createState() => _TerminalSayfasiState();
}

class _TerminalSayfasiState extends State<TerminalSayfasi> {
  late final TerminalOturumu t = widget.calisma.terminal(widget.cwd);
  final _odak = FocusNode();

  @override
  void initState() {
    super.initState();
    t.baslat();
  }

  @override
  void dispose() {
    _odak.dispose();
    super.dispose();
  }

  static const _tema = TerminalTheme(
    cursor: Color(0xFFE5E7EB),
    selection: Color(0x664F46E5),
    foreground: Color(0xFFE5E7EB),
    background: Color(0xFF0F1117),
    black: Color(0xFF1F2937),
    red: Color(0xFFF87171),
    green: Color(0xFF4ADE80),
    yellow: Color(0xFFFACC15),
    blue: Color(0xFF60A5FA),
    magenta: Color(0xFFC084FC),
    cyan: Color(0xFF22D3EE),
    white: Color(0xFFE5E7EB),
    brightBlack: Color(0xFF6B7280),
    brightRed: Color(0xFFFCA5A5),
    brightGreen: Color(0xFF86EFAC),
    brightYellow: Color(0xFFFDE68A),
    brightBlue: Color(0xFF93C5FD),
    brightMagenta: Color(0xFFD8B4FE),
    brightCyan: Color(0xFF67E8F9),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFFACC15),
    searchHitBackgroundCurrent: Color(0xFFF97316),
    searchHitForeground: Color(0xFF000000),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tema.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terminal'),
            Text(
              widget.cwd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: t,
            builder: (context, _) => t.canli
                ? IconButton(
                    tooltip: 'Kabuğu kapat',
                    onPressed: () async {
                      await t.kapat();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.power_settings_new),
                  )
                : IconButton(
                    tooltip: 'Yeni kabuk',
                    onPressed: t.baslat,
                    icon: const Icon(Icons.refresh),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ListenableBuilder(
              listenable: t,
              builder: (context, _) => t.hata == null
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      content: Text('Terminal açılamadı: ${t.hata}'),
                      actions: [
                        TextButton(
                          onPressed: t.baslat,
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: TerminalView(
                t.terminal,
                theme: _tema,
                focusNode: _odak,
                autofocus: true,
                deleteDetection: true,
                keyboardType: TextInputType.visiblePassword,
                padding: const EdgeInsets.all(6),
                textStyle: const TerminalStyle(fontSize: 13),
              ),
            ),
            _TusCubugu(t: t, odak: _odak),
          ],
        ),
      ),
    );
  }
}

class _TusCubugu extends StatelessWidget {
  const _TusCubugu({required this.t, required this.odak});
  final TerminalOturumu t;
  final FocusNode odak;

  @override
  Widget build(BuildContext context) {
    const tuslar = [
      ('Esc', '\x1b'),
      ('Tab', '\t'),
      ('Ctrl+C', '\x03'),
      ('Ctrl+D', '\x04'),
      ('Ctrl+Z', '\x1a'),
      ('Ctrl+L', '\x0c'),
      ('↑', '\x1b[A'),
      ('↓', '\x1b[B'),
      ('←', '\x1b[D'),
      ('→', '\x1b[C'),
      ('|', '|'),
      ('~', '~'),
      ('/', '/'),
      ('-', '-'),
    ];
    return Container(
      height: 42,
      color: const Color(0xFF181B24),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        children: [
          for (final (ad, veri) in tuslar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE5E7EB),
                  backgroundColor: const Color(0xFF262A36),
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  t.yaz(veri);
                  odak.requestFocus();
                },
                child: Text(ad, style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
