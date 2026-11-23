import 'package:flutter/material.dart';

import 'ekran/ana_ekran.dart';
import 'ekran/kurulum_ekrani.dart';
import 'model/calisma.dart';
import 'servis/ayarlar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  static ThemeData _tema(Brightness parlaklik) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFB4652F),
      brightness: parlaklik,
    ),
    visualDensity: VisualDensity.standard,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atölye',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      home: _kurulumBitti
          ? AnaEkran(calisma: widget.calisma)
          : KurulumEkrani(
              calisma: widget.calisma,
              bitti: () {
                setState(() => _kurulumBitti = true);
                widget.calisma.baslat();
              },
            ),
    );
  }
}
