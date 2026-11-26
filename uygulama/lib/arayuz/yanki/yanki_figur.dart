import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../model/sesli_konusma.dart';
import '../tema.dart';
import 'figurler.dart';
import 'hareket.dart';

/// Sesli konuşmanın görünüm seçenekleri: sade ya da LifeOS Yankı'nın
/// figürlerinden biri.
const sesGorunumleri = [
  ('sade', 'Sade', 'Yalnız durum ve yazı'),
  ('yanki', 'Yankı', 'Dalga, enerji küresi ve ağ'),
  ('ag', 'Ağ', 'Geodezik küre'),
  ('dalga', 'Dalga', 'Işık halkası'),
];

/// Figürlerin arka planı: ışıkla çizilirler, koyu zeminde görünürler.
const yankiZemini = Color(0xFF05070D);

AjanMood _ruh(SesDurumu d) => switch (d) {
  SesDurumu.kapali => AjanMood.idle,
  SesDurumu.dinliyor => AjanMood.listening,
  SesDurumu.konusuyor => AjanMood.speaking,
  SesDurumu.baglaniyor || SesDurumu.calisiyor => AjanMood.working,
};

/// Yankı'nın figürü: sesin gerçek yüksekliğiyle ve konuşmanın durumuyla
/// oynar. [gorunum] 'yanki', 'ag' ya da 'dalga'.
class YankiFiguru extends StatefulWidget {
  const YankiFiguru({super.key, required this.ses, required this.gorunum});

  final SesliKonusma ses;
  final String gorunum;

  /// Figürün eninin yüksekliğine oranı.
  static double oran(String gorunum) => gorunum == 'yanki' ? 2.6 : 2.4;

  @override
  State<YankiFiguru> createState() => _YankiFiguruState();
}

class _YankiFiguruState extends State<YankiFiguru>
    with SingleTickerProviderStateMixin {
  final _saat = ValueNotifier<double>(0);
  final _hareket = AjanMotion();
  late final Ticker _ticker;
  double _son = 0;

  @override
  void initState() {
    super.initState();
    // Kare kare çizim: zamanlayıcı hemen başlar (geç başlatılırsa figür donar).
    _ticker = createTicker(_tik)..start();
  }

  void _tik(Duration gecen) {
    final t = gecen.inMicroseconds / 1e6;
    final dt = (t - _son).clamp(0.0, .1);
    _son = t;
    _hareket.step(t, dt * 60, _ruh(widget.ses.durum), widget.ses.seviye.value);
    _saat.value = t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _saat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: switch (widget.gorunum) {
        'ag' => LatticePainter(_saat, _hareket),
        'dalga' => AperturePainter(_saat, _hareket),
        _ => EchoPainter(_saat, _hareket),
      },
      child: const SizedBox.expand(),
    ),
  );
}

/// Sesli konuşmanın tam ekranı: ortada figür, altında son satırlar.
/// [ek] figürün altında çizilir (bekleyen onaylar); [ekDinle] değişince
/// yeniden çizilir. Ek varken figür küçülür, ek hep görünür kalır.
class YankiEkrani extends StatefulWidget {
  const YankiEkrani({
    super.key,
    required this.ses,
    required this.gorunum,
    this.ek,
    this.ekDinle,
  });

  final SesliKonusma ses;
  final String gorunum;
  final WidgetBuilder? ek;
  final Listenable? ekDinle;

  @override
  State<YankiEkrani> createState() => _YankiEkraniState();
}

class _YankiEkraniState extends State<YankiEkrani> {
  SesliKonusma get ses => widget.ses;
  String get gorunum => widget.gorunum;

  @override
  void initState() {
    super.initState();
    // Gerçek tam ekran: saat/bildirim ve gezinme çubukları gizlenir,
    // kenardan kaydırınca bir an görünür.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yazi = Color(0xFFD6F7FF);
    return Scaffold(
      backgroundColor: yankiZemini,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([ses, ?widget.ekDinle]),
          builder: (context, _) {
            if (!ses.acik && ses.hata == null) {
              // Konuşma bitti: tam ekran kendiliğinden kapansın.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).maybePop();
              });
            }
            final son = ses.satirlar.length > 3
                ? ses.satirlar.sublist(ses.satirlar.length - 3)
                : ses.satirlar;
            final durum = switch (ses.durum) {
              SesDurumu.kapali => 'Kapalı',
              SesDurumu.baglaniyor => 'Bağlanıyor…',
              SesDurumu.dinliyor => ses.sessiz ? 'Sessizde' : 'Dinliyor',
              SesDurumu.konusuyor => 'Konuşuyor',
              SesDurumu.calisiyor => 'Çalışıyor',
            };
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Küçült',
                    color: yazi,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: YankiFiguru.oran(gorunum),
                      child: YankiFiguru(ses: ses, gorunum: gorunum),
                    ),
                  ),
                ),
                if (widget.ek != null)
                  // Figürün koyu zemininde açık temalı kart sırıtmasın.
                  Theme(
                    data: Tema.koyu(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Builder(builder: widget.ek!),
                        ),
                      ),
                    ),
                  ),
                Text(
                  durum,
                  style: const TextStyle(
                    color: yazi,
                    letterSpacing: 2,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (ses.hata != null)
                        Text(
                          ses.hata!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFF8A8A)),
                        ),
                      for (final s in son)
                        if (s.metin.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              s.metin.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: yazi.withValues(
                                  alpha: s.kullanici ? .6 : .95,
                                ),
                                fontStyle: s.kullanici
                                    ? FontStyle.italic
                                    : null,
                                fontSize: 15,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      tooltip: ses.sessiz ? 'Mikrofonu aç' : 'Sessize al',
                      iconSize: 28,
                      onPressed: ses.acik ? ses.sessizeAl : null,
                      icon: Icon(
                        ses.sessiz ? Icons.mic_off_rounded : Icons.mic_rounded,
                      ),
                    ),
                    const SizedBox(width: 28),
                    IconButton.filled(
                      tooltip: 'Bitir',
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE5484D),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (ses.acik) {
                          ses.bitir();
                        } else {
                          ses.hatayiKapat();
                          Navigator.of(context).maybePop();
                        }
                      },
                      icon: const Icon(Icons.call_end_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            );
          },
        ),
      ),
    );
  }
}
