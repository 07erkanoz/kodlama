import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'arayuz/tema.dart';
import 'ekran/ana_ekran.dart';
import 'ekran/kurulum_ekrani.dart';
import 'ekran/paylasim_yoneticisi.dart';
import 'model/bildirim_yoneticisi.dart';
import 'model/calisma.dart';
import 'model/widget_yoneticisi.dart';
import 'servis/ayarlar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final ayarlar = await Ayarlar.yukle();
  final calisma = Calisma(ayarlar);
  // Ajan çalışırken kalıcı bildirim, onay/sonuç bildirimleri; uygulama boyunca yaşar.
  final bildirim = BildirimYoneticisi(calisma);
  final gezgin = GlobalKey<NavigatorState>();
  // Ana ekran widget'ı: durumu gönderir, düğmelerini karşılar.
  WidgetYoneticisi(calisma, bildirim, gezgin);
  // Paylaş menüsünden gelenler (kurulum bitmişse).
  if (ayarlar.kurulumBitti) PaylasimYoneticisi(calisma, gezgin);
  runApp(AtolyeUygulamasi(calisma: calisma, gezgin: gezgin));
}

class AtolyeUygulamasi extends StatefulWidget {
  const AtolyeUygulamasi({
    super.key,
    required this.calisma,
    required this.gezgin,
  });
  final Calisma calisma;
  final GlobalKey<NavigatorState> gezgin;

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
        navigatorKey: widget.gezgin,
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
