import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'arayuz/tema.dart';
import 'ekran/ana_ekran.dart';
import 'ekran/kurulum_ekrani.dart';
import 'model/calisma.dart';
import 'servis/ayarlar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final ayarlar = await Ayarlar.yukle();
  final calisma = Calisma(ayarlar);
  runApp(AtolyeUygulamasi(calisma: calisma));
}

class AtolyeUygulamasi extends StatefulWidget {
  const AtolyeUygulamasi({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<AtolyeUygulamasi> createState() => _AtolyeUygulamasiState();
}

class _AtolyeUygulamasiState extends State<AtolyeUygulamasi> {
  late bool _kurulumBitti = widget.calisma.ayarlar.kurulumBitti;

  @override
  void initState() {
    super.initState();
    if (_kurulumBitti) widget.calisma.baslat();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.calisma,
      builder: (context, _) => MaterialApp(
        title: 'Atölye',
        debugShowCheckedModeBanner: false,
        theme: Tema.acik(),
        darkTheme: Tema.koyu(),
        themeMode: switch (widget.calisma.tema) {
          ThemeModeSecimi.acik => ThemeMode.light,
          ThemeModeSecimi.koyu => ThemeMode.dark,
          ThemeModeSecimi.sistem => ThemeMode.system,
        },
        home: _kurulumBitti
            ? AnaEkran(calisma: widget.calisma)
            : KurulumEkrani(
                calisma: widget.calisma,
                bitti: () {
                  setState(() => _kurulumBitti = true);
                  widget.calisma.baslat();
                },
              ),
      ),
    );
  }
}
