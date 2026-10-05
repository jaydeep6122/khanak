import 'package:flutter/material.dart';

/// Colours Material's ColorScheme has no names for: money in and out, soft
/// status backgrounds and text tiers. Read them with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.muted,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
  });

  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;

  /// Main text.
  final Color ink;

  /// Supporting text.
  final Color inkSecondary;

  /// Hints, captions, disabled text.
  final Color muted;

  /// Money received, paid, success.
  final Color success;
  final Color successSoft;

  /// Money owed or going out, errors, cancelled.
  final Color danger;
  final Color dangerSoft;

  /// Partly paid, low stock, attention.
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? ink,
    Color? inkSecondary,
    Color? muted,
    Color? success,
    Color? successSoft,
    Color? danger,
    Color? dangerSoft,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      muted: muted ?? this.muted,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primarySoft: mix(primarySoft, other.primarySoft),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      border: mix(border, other.border),
      ink: mix(ink, other.ink),
      inkSecondary: mix(inkSecondary, other.inkSecondary),
      muted: mix(muted, other.muted),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      info: mix(info, other.info),
      infoSoft: mix(infoSoft, other.infoSoft),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  // Fixed colours for places without a BuildContext (toasts).
  static const Color primary = Color(0xFFA23B22);
  static const Color success = Color(0xFF248A3D);
  static const Color error = Color(0xFFE0342B);
  static const Color warning = Color(0xFFC75C00);
  static const Color info = Color(0xFF007AFF);

  // ── Spacing ──
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;
  static const double space3xl = 32;
  static const double space4xl = 48;

  // ── Corner radius ──
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusFull = 999;

  /// Space kept below scrolling content so the last row clears a floating
  /// button.
  static const double fabClearance = 96;

  // Grouped grey page and white surfaces, with fired-brick red as the accent
  // and iOS system colours for money (darkened in light mode so text stays
  // readable).
  static const AppColors lightColors = AppColors(
    primary: Color(0xFFA23B22),
    onPrimary: Colors.white,
    primarySoft: Color(0xFFF6E3DC),
    background: Color(0xFFF2F2F7),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF2F2F7),
    border: Color(0xFFE5E5EA),
    ink: Color(0xFF1C1C1E),
    inkSecondary: Color(0xFF48484A),
    muted: Color(0xFF8E8E93),
    success: Color(0xFF248A3D),
    successSoft: Color(0xFFE8F6EC),
    danger: Color(0xFFE0342B),
    dangerSoft: Color(0xFFFDECEB),
    warning: Color(0xFFC75C00),
    warningSoft: Color(0xFFFFF3E3),
    info: Color(0xFF007AFF),
    infoSoft: Color(0xFFE6F1FF),
  );

  static const AppColors darkColors = AppColors(
    primary: Color(0xFFE8876A),
    onPrimary: Color(0xFF1C1C1E),
    primarySoft: Color(0xFF3A231C),
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceAlt: Color(0xFF2C2C2E),
    border: Color(0xFF38383A),
    ink: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFD1D1D6),
    muted: Color(0xFF8E8E93),
    success: Color(0xFF30D158),
    successSoft: Color(0xFF0F2E19),
    danger: Color(0xFFFF453A),
    dangerSoft: Color(0xFF3A1513),
    warning: Color(0xFFFF9F0A),
    warningSoft: Color(0xFF3A2A0A),
    info: Color(0xFF0A84FF),
    infoSoft: Color(0xFF0A2540),
  );

  static ThemeData get lightTheme => _build(Brightness.light, lightColors);
  static ThemeData get darkTheme => _build(Brightness.dark, darkColors);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primary,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSecondary,
      surfaceContainerHighest: c.surfaceAlt,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainer: c.surface,
      error: c.danger,
      onError: Colors.white,
      outline: c.border,
      outlineVariant: c.border,
    );

    // The phone's own font: it has Gujarati and Hindi letters, and nothing
    // has to be downloaded. Sizes run a little large for reading at the kiln.
    final base = ThemeData(
      brightness: brightness,
    ).textTheme.apply(bodyColor: c.ink, displayColor: c.ink);

    final text = base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 17),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, color: c.inkSecondary),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, color: c.muted),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.muted,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.muted,
        letterSpacing: 0.4,
      ),
    );

    final smallRadius = BorderRadius.circular(radiusSm);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: spaceLg,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: inputBorder(c.border),
        enabledBorder: inputBorder(c.border),
        disabledBorder: inputBorder(c.border.withValues(alpha: 0.5)),
        focusedBorder: inputBorder(c.primary, 1.6),
        errorBorder: inputBorder(c.danger),
        focusedErrorBorder: inputBorder(c.danger, 1.6),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        errorMaxLines: 3,
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.border),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.primary : c.muted,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? c.primary : c.muted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primarySoft,
        disabledColor: c.surfaceAlt,
        side: BorderSide(color: c.border),
        labelStyle: text.labelLarge?.copyWith(color: c.ink, fontSize: 13),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: c.primary, fontSize: 13),
        checkmarkColor: c.primary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        titleTextStyle: text.titleSmall?.copyWith(color: c.ink),
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceLg),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onPrimary : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primary : c.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primary : c.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXs)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.muted,
        indicatorColor: c.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        dividerColor: c.border,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.primarySoft,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.primary,
        headerForegroundColor: c.onPrimary,
        rangeSelectionBackgroundColor: c.primarySoft,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
