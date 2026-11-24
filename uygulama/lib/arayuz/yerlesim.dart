import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

/// Ekran sınıfı: Material 3 pencere boyu sınıflarına göre.
///   dar    < 600  : telefon (dikey), kapalı katlanır telefon
///   orta   < 840  : açık katlanır telefon, küçük tablet, yatay telefon
///   genis  ≥ 840  : tablet, büyük katlanır telefon yatay
enum EkranSinifi { dar, orta, genis }

EkranSinifi ekranSinifi(double genislik) => genislik < 600
    ? EkranSinifi.dar
    : genislik < 840
    ? EkranSinifi.orta
    : EkranSinifi.genis;

/// Katlanır telefonun menteşesi ya da katlama çizgisi: dikey bir ayraçsa
/// konumunu döndürür (yatay ayraçları — masaüstü duruşu — yok sayarız).
Rect? dikeyMentese(BuildContext context) {
  final mq = MediaQuery.of(context);
  for (final f in mq.displayFeatures) {
    final dikey = f.bounds.height >= mq.size.height * .9;
    if (dikey &&
        (f.type == DisplayFeatureType.hinge ||
            f.type == DisplayFeatureType.fold) &&
        f.bounds.left > 0 &&
        f.bounds.right < mq.size.width) {
      return f.bounds;
    }
  }
  return null;
}

/// İki paneli yan yana dizer. Katlanır telefonda bölme menteşenin
/// üstüne denk gelir ve menteşenin kapladığı alan boş bırakılır; düz
/// ekranda [solGenislik] kullanılır.
class IkiPanel extends StatelessWidget {
  const IkiPanel({
    super.key,
    required this.sol,
    required this.sag,
    this.solGenislik = 320,
    this.solAcik = true,
  });

  /// Kapalıysa yalnız sağ panel görünür (menteşesiz ekranda).
  final bool solAcik;

  final Widget sol;
  final Widget sag;
  final double solGenislik;

  @override
  Widget build(BuildContext context) {
    final mentese = dikeyMentese(context);
    final ayrac = VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    if (mentese != null) {
      return Row(
        children: [
          SizedBox(width: mentese.left, child: sol),
          SizedBox(width: mentese.width),
          Expanded(child: sag),
        ],
      );
    }
    return Row(
      children: [
        Kayan(genislik: solAcik ? solGenislik : 0, child: sol),
        if (solAcik) ayrac,
        Expanded(child: sag),
      ],
    );
  }
}

/// Açılıp kapanan yan panel: genişliği yumuşakça değişir, içerik açık
/// genişliğinde kalır (kayarak gizlenir), kapalıyken çizilmez.
class Kayan extends StatefulWidget {
  const Kayan({
    super.key,
    required this.genislik,
    required this.child,
    this.sagda = false,
  });
  final double genislik;
  final Widget child;

  /// Sağdaki panel sağa, soldaki sola doğru kayar.
  final bool sagda;

  @override
  State<Kayan> createState() => _KayanState();
}

class _KayanState extends State<Kayan> {
  late double _acik = widget.genislik > 0 ? widget.genislik : 280;

  @override
  Widget build(BuildContext context) {
    if (widget.genislik > 0) _acik = widget.genislik;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.genislik),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, g, cocuk) => g < 1
          ? const SizedBox.shrink()
          : ClipRect(
              child: SizedBox(
                width: g,
                child: OverflowBox(
                  alignment: widget.sagda
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  minWidth: _acik,
                  maxWidth: _acik,
                  child: cocuk,
                ),
              ),
            ),
      child: widget.child,
    );
  }
}
