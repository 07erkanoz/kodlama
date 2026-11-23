import 'package:flutter/material.dart';

/// Bir ayar bölümünün nasıl çizileceği: açıklamalı satırlar ya da
/// düşük → yüksek sıralı bir seviye seçici.
enum AyarBicimi { liste, seviye }

/// Ayar panelinde bir bölüm. Seçenekler (değer, ad, açıklama, etkin).
class AyarBolumu {
  const AyarBolumu({
    required this.baslik,
    required this.secenekler,
    required this.secili,
    required this.secildi,
    this.bicim = AyarBicimi.liste,
    this.simgeler = const {},
    this.rozetler = const {},
  });

  final String baslik;
  final List<(String deger, String ad, String? aciklama, bool etkin)>
  secenekler;
  final String? secili;
  final void Function(String) secildi;
  final AyarBicimi bicim;

  /// Liste satırlarının solundaki simgeler (değere göre).
  final Map<String, IconData> simgeler;

  /// Adın yanındaki küçük etiket (ör. "varsayılan").
  final Map<String, String> rozetler;
}

/// Alttan açılan ayar paneli. [bolumler] her seçimden ve [dinle] her
/// değiştiğinde yeniden çağrılır; böylece panel güncel durumu gösterir.
Future<void> ayarPaneliAc(
  BuildContext context, {
  required String baslik,
  String? altBaslik,
  Widget? onde,
  required List<AyarBolumu> Function() bolumler,
  Listenable? dinle,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _AyarPaneli(
    baslik: baslik,
    altBaslik: altBaslik,
    onde: onde,
    bolumler: bolumler,
    dinle: dinle,
  ),
);

class _AyarPaneli extends StatefulWidget {
  const _AyarPaneli({
    required this.baslik,
    required this.bolumler,
    this.altBaslik,
    this.onde,
    this.dinle,
  });

  final String baslik;
  final String? altBaslik;
  final Widget? onde;
  final List<AyarBolumu> Function() bolumler;
  final Listenable? dinle;

  @override
  State<_AyarPaneli> createState() => _AyarPaneliState();
}

class _AyarPaneliState extends State<_AyarPaneli> {
  @override
  void initState() {
    super.initState();
    widget.dinle?.addListener(_yenile);
  }

  @override
  void dispose() {
    widget.dinle?.removeListener(_yenile);
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _sec(AyarBolumu b, String d) {
    b.secildi(d);
    _yenile();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final bolumler = widget.bolumler();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                if (widget.onde != null) ...[
                  widget.onde!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.baslik,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.altBaslik != null)
                        Text(
                          widget.altBaslik!,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: r.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: r.outlineVariant),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final b in bolumler) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 6),
                      child: Text(
                        b.baslik.toUpperCase(),
                        style: t.textTheme.labelSmall?.copyWith(
                          color: r.outline,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    switch (b.bicim) {
                      AyarBicimi.liste => _Liste(
                        bolum: b,
                        sec: (d) => _sec(b, d),
                      ),
                      AyarBicimi.seviye => _Seviye(
                        bolum: b,
                        sec: (d) => _sec(b, d),
                      ),
                    },
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.bolum, required this.sec});
  final AyarBolumu bolum;
  final void Function(String) sec;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final s = bolum.secenekler;
    return Column(
      children: [
        for (final (i, (d, ad, aciklama, etkin)) in s.indexed)
          Opacity(
            opacity: etkin ? 1 : .45,
            child: InkWell(
              onTap: etkin ? () => sec(d) : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: i == s.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: r.outlineVariant)),
                ),
                child: Row(
                  children: [
                    if (bolum.simgeler[d] case final simge?) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: d == bolum.secili
                              ? r.primaryContainer
                              : r.surfaceContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          simge,
                          size: 18,
                          color: d == bolum.secili
                              ? r.primary
                              : r.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  ad,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.bodyLarge?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (bolum.rozetler[d] case final rozet?) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: r.surfaceContainer,
                                    border: Border.all(color: r.outlineVariant),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    rozet,
                                    style: t.textTheme.labelSmall?.copyWith(
                                      color: r.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (aciklama != null)
                            Text(
                              aciklama,
                              style: t.textTheme.bodySmall?.copyWith(
                                color: r.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: d == bolum.secili ? 1 : 0,
                      child: Icon(Icons.check_rounded, color: r.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Seviye extends StatelessWidget {
  const _Seviye({required this.bolum, required this.sec});
  final AyarBolumu bolum;
  final void Function(String) sec;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final s = bolum.secenekler;
    final secili = s.where((x) => x.$1 == bolum.secili).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: r.surfaceContainer,
            border: Border.all(color: r.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (i, (d, ad, _, etkin)) in s.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: etkin ? () => sec(d) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: d == bolum.secili ? r.surface : null,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: d == bolum.secili
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .08),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          EforCubugu(
                            seviye: seviyeCubugu(i, s.length),
                            vurgu: d == bolum.secili,
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              ad,
                              maxLines: 1,
                              style: t.textTheme.labelSmall?.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: d == bolum.secili
                                    ? r.onSurface
                                    : r.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (secili?.$3 case final aciklama?)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Text(
              aciklama,
              style: t.textTheme.bodySmall?.copyWith(
                color: r.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// [sira]. seçeneğin (0 = varsayılan) kaç çubukla gösterileceği; en
/// yükseği 4 çubuk.
int seviyeCubugu(int sira, int toplam) =>
    sira <= 0 || toplam <= 1 ? 0 : ((sira * 4) / (toplam - 1)).ceil();

/// Düşünme gücünü gösteren dört küçük çubuk.
class EforCubugu extends StatelessWidget {
  const EforCubugu({super.key, required this.seviye, this.vurgu = true});
  final int seviye;
  final bool vurgu;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: 3,
            height: 3.0 + i * 2.25,
            margin: EdgeInsets.only(left: i == 1 ? 0 : 2),
            decoration: BoxDecoration(
              color: i <= seviye
                  ? (vurgu ? r.primary : r.onSurfaceVariant)
                  : r.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

/// Mesaj kutusunun araç satırındaki yuvarlak, zeminsiz düğme.
class AracDugmesi extends StatelessWidget {
  const AracDugmesi({
    super.key,
    required this.cocuklar,
    required this.onTap,
    this.ipucu,
    this.renk,
  });

  final List<Widget> cocuklar;
  final VoidCallback? onTap;
  final String? ipucu;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final renk = this.renk ?? r.onSurface;
    final govde = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: DefaultTextStyle.merge(
              style: t.textTheme.labelLarge?.copyWith(
                color: renk,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: renk),
                child: Row(mainAxisSize: MainAxisSize.min, children: cocuklar),
              ),
            ),
          ),
        ),
      ),
    );
    return ipucu == null ? govde : Tooltip(message: ipucu!, child: govde);
  }
}
