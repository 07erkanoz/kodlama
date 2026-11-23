import 'package:flutter/material.dart';

/// Atölye'nin teması: nötr gri yüzeyler, tek bir vurgu rengi (indigo).
/// Renk tohumundan üretilen pastel tonlar yerine elle seçilmiş renkler;
/// bir geliştirme aracında içerik öne çıksın, arayüz geri planda kalsın.
abstract final class Tema {
  static const _koyu = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8B8CF8),
    onPrimary: Color(0xFF0E0E12),
    primaryContainer: Color(0xFF25254A),
    onPrimaryContainer: Color(0xFFDCDCFF),
    secondary: Color(0xFFA1A1AA),
    onSecondary: Color(0xFF0E0E12),
    secondaryContainer: Color(0xFF2A2A31),
    onSecondaryContainer: Color(0xFFE4E4E7),
    tertiary: Color(0xFF5EEAD4),
    onTertiary: Color(0xFF0E0E12),
    error: Color(0xFFF87171),
    onError: Color(0xFF0E0E12),
    errorContainer: Color(0xFF3A1D1F),
    onErrorContainer: Color(0xFFFECACA),
    surface: Color(0xFF111114),
    onSurface: Color(0xFFE6E6E9),
    onSurfaceVariant: Color(0xFFA1A1AA),
    surfaceContainerLowest: Color(0xFF0B0B0D),
    surfaceContainerLow: Color(0xFF16161A),
    surfaceContainer: Color(0xFF1B1B20),
    surfaceContainerHigh: Color(0xFF222228),
    surfaceContainerHighest: Color(0xFF2A2A31),
    outline: Color(0xFF52525B),
    outlineVariant: Color(0xFF2B2B32),
    inverseSurface: Color(0xFFE6E6E9),
    onInverseSurface: Color(0xFF16161A),
    inversePrimary: Color(0xFF4F46E5),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static const _acik = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF4F46E5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEEF0FF),
    onPrimaryContainer: Color(0xFF26236B),
    secondary: Color(0xFF52525B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFEDEDF0),
    onSecondaryContainer: Color(0xFF18181B),
    tertiary: Color(0xFF0F766E),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEF2F2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF18181B),
    onSurfaceVariant: Color(0xFF5B5B64),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F7F8),
    surfaceContainer: Color(0xFFF2F2F4),
    surfaceContainerHigh: Color(0xFFECECEF),
    surfaceContainerHighest: Color(0xFFE4E4E7),
    outline: Color(0xFFA1A1AA),
    outlineVariant: Color(0xFFE4E4E7),
    inverseSurface: Color(0xFF18181B),
    onInverseSurface: Color(0xFFF7F7F8),
    inversePrimary: Color(0xFF8B8CF8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static ThemeData koyu() => _kur(_koyu);
  static ThemeData acik() => _kur(_acik);

  static ThemeData _kur(ColorScheme r) {
    final yuvarlak = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return ThemeData(
      colorScheme: r,
      scaffoldBackgroundColor: r.surface,
      canvasColor: r.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(color: r.outlineVariant, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: r.surface,
        foregroundColor: r.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: r.outlineVariant)),
        titleTextStyle: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: r.onSurface,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: r.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        endShape: const RoundedRectangleBorder(),
      ),
      cardTheme: CardThemeData(
        color: r.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: r.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: r.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: r.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: r.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: r.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: yuvarlak,
          minimumSize: const Size(0, 42),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: yuvarlak,
          minimumSize: const Size(0, 42),
          foregroundColor: r.onSurface,
          side: BorderSide(color: r.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: yuvarlak),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: r.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: r.surfaceContainer,
        side: BorderSide(color: r.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(fontSize: 12.5, color: r.onSurface),
        iconTheme: IconThemeData(color: r.onSurfaceVariant, size: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: r.surfaceContainer,
        isDense: true,
        hintStyle: TextStyle(color: r.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: r.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: r.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: r.primary, width: 1.4),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedTileColor: r.surfaceContainerHigh,
        selectedColor: r.onSurface,
        iconColor: r.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: r.onSurface,
        unselectedLabelColor: r.onSurfaceVariant,
        indicatorColor: r.primary,
        dividerColor: r.outlineVariant,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: r.primaryContainer,
          selectedForegroundColor: r.onPrimaryContainer,
          side: BorderSide(color: r.outlineVariant),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.inverseSurface,
        contentTextStyle: TextStyle(color: r.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: r.primary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: r.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: r.onInverseSurface, fontSize: 12),
      ),
    );
  }

  /// Ajanların küçük kimlik renkleri (yalnız rozet harfinde).
  static Color ajanRengi(String ajan) =>
      ajan == 'claude' ? const Color(0xFFD97757) : const Color(0xFF10A37F);
}
