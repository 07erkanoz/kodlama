import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mesaj yazma kutusu: üstte ekler, ortada geniş metin alanı, altta tek
/// satırda ekle, seçim çipleri ve gönder/durdur. Çipler alt satıra taşmaz,
/// sığmazsa kısalır. Fiziksel klavyesi olan cihazlarda (masaüstü, web)
/// Enter gönderir, Shift+Enter yeni satır açar.
class MesajKutusu extends StatefulWidget {
  const MesajKutusu({
    super.key,
    required this.denetleyici,
    required this.gonder,
    this.durdur,
    this.calisiyor = false,
    this.ekle,
    this.ekler = const [],
    this.ekKaldir,
    this.ekYukleniyor = false,
    this.cipler = const [],
    this.sagda = const [],
    this.ipucu = 'Mesaj yaz',
    this.gonderilebilir = true,
    this.odak,
    this.otomatikOdak = false,
    this.enAzSatir = 2,
  });

  final TextEditingController denetleyici;
  final VoidCallback gonder;
  final VoidCallback? durdur;
  final bool calisiyor;
  final VoidCallback? ekle;
  final List<String> ekler;
  final void Function(String)? ekKaldir;
  final bool ekYukleniyor;
  /// Araç satırının solundaki düğmeler (model seçici gibi); sığmazsa kısalır.
  final List<Widget> cipler;

  /// Gönder düğmesinin hemen solundaki düğmeler (onay biçimi gibi).
  final List<Widget> sagda;
  final String ipucu;
  final bool gonderilebilir;
  final FocusNode? odak;
  final bool otomatikOdak;

  /// Boşken metin alanının yüksekliği (satır).
  final int enAzSatir;

  @override
  State<MesajKutusu> createState() => _MesajKutusuState();
}

class _MesajKutusuState extends State<MesajKutusu> {
  late final FocusNode _odak = widget.odak ?? FocusNode();
  bool _odakta = false;

  bool get _enterGonderir =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _odak.addListener(_odakDegisti);
    _odak.onKeyEvent = (node, e) {
      if (_enterGonderir &&
          e is KeyDownEvent &&
          e.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (widget.gonderilebilir) widget.gonder();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    widget.denetleyici.addListener(_yenile);
  }

  void _odakDegisti() => setState(() => _odakta = _odak.hasFocus);
  void _yenile() => setState(() {});

  @override
  void dispose() {
    widget.denetleyici.removeListener(_yenile);
    _odak.removeListener(_odakDegisti);
    if (widget.odak == null) _odak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final dolu =
        widget.denetleyici.text.trim().isNotEmpty || widget.ekler.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: r.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _odakta ? r.primary.withValues(alpha: .5) : r.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: r.brightness == Brightness.dark ? .25 : .05,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.ekler.isNotEmpty || widget.ekYukleniyor)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in widget.ekler)
                    InputChip(
                      avatar: const Icon(Icons.attach_file, size: 14),
                      label: Text(e.split('/').last),
                      onDeleted: () => widget.ekKaldir?.call(e),
                    ),
                  if (widget.ekYukleniyor)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          TextField(
            controller: widget.denetleyici,
            focusNode: _odak,
            autofocus: widget.otomatikOdak,
            minLines: widget.enAzSatir,
            maxLines: 12,
            textInputAction: TextInputAction.newline,
            style: t.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
            decoration: InputDecoration(
              hintText: widget.ipucu,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 8, 8),
            child: Row(
              children: [
                if (widget.ekle != null)
                  _Yuvarlak(
                    ipucu: 'Dosya ekle',
                    onTap: widget.ekle,
                    child: Icon(Icons.add, size: 22, color: r.onSurfaceVariant),
                  )
                else
                  const SizedBox(width: 4),
                Expanded(
                  child: Row(
                    children: [
                      for (final c in widget.cipler) Flexible(child: c),
                    ],
                  ),
                ),
                ...widget.sagda,
                const SizedBox(width: 4),
                if (widget.calisiyor && widget.durdur != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Yuvarlak(
                      ipucu: 'Durdur',
                      onTap: widget.durdur,
                      cerceve: r.outline.withValues(alpha: .5),
                      zemin: r.surface,
                      child: Icon(Icons.stop_rounded, size: 18, color: r.onSurface),
                    ),
                  ),
                _Yuvarlak(
                  ipucu: _enterGonderir ? 'Gönder (Enter)' : 'Gönder',
                  onTap: dolu && widget.gonderilebilir ? widget.gonder : null,
                  zemin: dolu && widget.gonderilebilir
                      ? r.onSurface
                      : r.surfaceContainerHighest,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: dolu && widget.gonderilebilir ? r.surface : r.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Yuvarlak extends StatelessWidget {
  const _Yuvarlak({
    required this.child,
    required this.onTap,
    required this.ipucu,
    this.zemin,
    this.cerceve,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String ipucu;
  final Color? zemin;
  final Color? cerceve;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ipucu,
    child: Material(
      color: zemin ?? Colors.transparent,
      shape: CircleBorder(
        side: cerceve == null ? BorderSide.none : BorderSide(color: cerceve!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    ),
  );
}

/// Mesaj kutusunun üstündeki bağlam seçicisi (proje, çalışma yeri).
class SecimCipi<T> extends StatelessWidget {
  const SecimCipi({
    super.key,
    required this.simge,
    required this.etiket,
    required this.secenekler,
    required this.secildi,
    this.secili,
    this.ipucu,
    this.etkin = true,
  });

  final Widget simge;
  final String etiket;
  final List<(T deger, String ad, String? aciklama, bool etkin)> secenekler;
  final void Function(T) secildi;
  final T? secili;
  final String? ipucu;
  final bool etkin;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return PopupMenuButton<T>(
      tooltip: ipucu ?? '',
      enabled: etkin,
      onSelected: secildi,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final (d, ad, aciklama, e) in secenekler)
          PopupMenuItem<T>(
            value: d,
            enabled: e,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: d == secili
                      ? Icon(Icons.check, size: 16, color: r.primary)
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad),
                      if (aciklama != null)
                        Text(
                          aciklama,
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
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: r.surface,
          border: Border.all(color: r.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(size: 15, color: r.onSurfaceVariant),
              child: simge,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.labelLarge?.copyWith(color: r.onSurface, fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: r.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Çalışma biçimleri: CLI'ların onay ayarlarına karşılık gelir.
const calismaBicimleri = <(String, String, String, IconData)>[
  (
    'otomatik',
    'Otomatik',
    'Güvenli işleri kendisi onaylar, yalnız riskli olanları sorar',
    Icons.auto_mode,
  ),
  ('sor', 'Sor', 'Her değişiklik ve komut için onay', Icons.back_hand_outlined),
  (
    'duzenle',
    'Düzenle',
    'Dosya düzenlemeleri serbest, komutlarda sor',
    Icons.edit_note,
  ),
  ('plan', 'Plan', 'Yalnız okur ve plan yapar', Icons.map_outlined),
  ('serbest', 'Serbest', 'Sormadan çalışır', Icons.bolt),
];

(String, String, String, IconData) bicim(String kod) => calismaBicimleri
    .firstWhere((b) => b.$1 == kod, orElse: () => calismaBicimleri.first);
