import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours Material's ColorScheme has no names for. Read them with
/// `context.colors`.
///
/// The look: a warm light-grey page, white cards floating on soft shadows,
/// near-black ink, and fired-brick orange as the one accent. Each kind of
/// entry keeps its own tint (bricks, fire, money, truck, expenses) so it is
/// recognised at a glance.
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
    required this.onInk,
    required this.inkSecondary,
    required this.muted,
    required this.hero,
    required this.onHero,
    required this.heroMuted,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.violet,
    required this.violetSoft,
    required this.shadow,
  });

  /// The accent: fired brick.
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;

  /// The page behind the cards.
  final Color background;

  /// Cards and sheets.
  final Color surface;

  /// Segmented-control tracks, chips, wells inside cards.
  final Color surfaceAlt;

  /// Hairlines between rows.
  final Color border;

  /// Main text, and the fill of the main button.
  final Color ink;
  final Color onInk;

  /// Supporting text.
  final Color inkSecondary;

  /// Labels, captions, chevrons.
  final Color muted;

  /// The one dark card on a screen (today's numbers).
  final Color hero;
  final Color onHero;
  final Color heroMuted;

  /// Money in, advances, success.
  final Color success;
  final Color successSoft;

  /// Money owed or going out, errors.
  final Color danger;
  final Color dangerSoft;

  /// Fire (nikasi), attention.
  final Color warning;
  final Color warningSoft;

  /// Trucks and sales.
  final Color info;
  final Color infoSoft;

  /// Expenses.
  final Color violet;
  final Color violetSoft;

  /// Tint of every soft shadow.
  final Color shadow;

  @override
  AppColors copyWith() => this;

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
      onInk: mix(onInk, other.onInk),
      inkSecondary: mix(inkSecondary, other.inkSecondary),
      muted: mix(muted, other.muted),
      hero: mix(hero, other.hero),
      onHero: mix(onHero, other.onHero),
      heroMuted: mix(heroMuted, other.heroMuted),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      info: mix(info, other.info),
      infoSoft: mix(infoSoft, other.infoSoft),
      violet: mix(violet, other.violet),
      violetSoft: mix(violetSoft, other.violetSoft),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// The soft shadow cards float on: a hairline close in and a wide, faint
  /// one below.
  List<BoxShadow> get cardShadow => [
    BoxShadow(color: colors.shadow.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(
      color: colors.shadow.withValues(alpha: 0.10),
      blurRadius: 28,
      spreadRadius: -14,
      offset: const Offset(0, 14),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  // Fixed colours for places without a BuildContext (toasts).
  static const Color primary = Color(0xFFC64A1E);
  static const Color success = Color(0xFF1E7A50);
  static const Color error = Color(0xFFB4371F);
  static const Color warning = Color(0xFFB05E0E);
  static const Color info = Color(0xFF17140F);

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
  static const double radiusXs = 8;
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
  static const double radiusFull = 999;

  /// Space kept below scrolling content so the last row clears the floating
  /// tab bar or save bar.
  static const double fabClearance = 120;

  static const AppColors lightColors = AppColors(
    primary: Color(0xFFC64A1E),
    onPrimary: Colors.white,
    primarySoft: Color(0xFFFBE7DC),
    background: Color(0xFFF2F1EE),
    surface: Colors.white,
    surfaceAlt: Color(0xFFE7E4DE),
    border: Color(0x1A17140F),
    ink: Color(0xFF17140F),
    onInk: Color(0xFFF6F2EC),
    inkSecondary: Color(0xFF4A453E),
    muted: Color(0xFF6B665E),
    hero: Color(0xFF1C1915),
    onHero: Color(0xFFF6F2EC),
    heroMuted: Color(0xFFB8B0A4),
    success: Color(0xFF1E7A50),
    successSoft: Color(0xFFDDF1E6),
    danger: Color(0xFFB4371F),
    dangerSoft: Color(0xFFF8E2DD),
    warning: Color(0xFFB05E0E),
    warningSoft: Color(0xFFFCEBD6),
    info: Color(0xFF2D5FB0),
    infoSoft: Color(0xFFDCE7F7),
    violet: Color(0xFF5B48B8),
    violetSoft: Color(0xFFECE8FB),
    shadow: Color(0xFF17140F),
  );

  static const AppColors darkColors = AppColors(
    primary: Color(0xFFEE7A4C),
    onPrimary: Color(0xFF1C1915),
    primarySoft: Color(0xFF3A2116),
    background: Color(0xFF0F0D0B),
    surface: Color(0xFF1C1915),
    surfaceAlt: Color(0xFF2B2722),
    border: Color(0x1FF6F2EC),
    ink: Color(0xFFF4EFE8),
    onInk: Color(0xFF17140F),
    inkSecondary: Color(0xFFCFC7BC),
    muted: Color(0xFF9C948A),
    hero: Color(0xFF26211C),
    onHero: Color(0xFFF6F2EC),
    heroMuted: Color(0xFFB8B0A4),
    success: Color(0xFF5CC28F),
    successSoft: Color(0xFF12301F),
    danger: Color(0xFFF07560),
    dangerSoft: Color(0xFF3A1712),
    warning: Color(0xFFF0A050),
    warningSoft: Color(0xFF3A2710),
    info: Color(0xFF7AA7EE),
    infoSoft: Color(0xFF14263F),
    violet: Color(0xFFA99BF0),
    violetSoft: Color(0xFF241D45),
    shadow: Color(0xFF000000),
  );

  static ThemeData get lightTheme => _build(Brightness.light, lightColors);
  static ThemeData get darkTheme => _build(Brightness.dark, darkColors);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: brightness).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primary,
      secondary: c.ink,
      onSecondary: c.onInk,
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

    // Geist for numbers and Latin letters; Gujarati and Hindi letters fall
    // through to Noto Sans, which Geist does not carry. Fetched once, then
    // kept on the phone.
    final fallback = [GoogleFonts.notoSansGujarati().fontFamily!, GoogleFonts.notoSansDevanagari().fontFamily!];
    final base = GoogleFonts.geistTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: c.ink, displayColor: c.ink, fontFamilyFallback: fallback);

    TextStyle? tight(TextStyle? style, double size, FontWeight weight, double spacing) =>
        style?.copyWith(fontSize: size, fontWeight: weight, letterSpacing: spacing, height: 1.15);

    final text = base.copyWith(
      displaySmall: tight(base.displaySmall, 44, FontWeight.w600, -1.4),
      headlineLarge: tight(base.headlineLarge, 34, FontWeight.w700, -0.8),
      headlineMedium: tight(base.headlineMedium, 28, FontWeight.w700, -0.5),
      headlineSmall: tight(base.headlineSmall, 22, FontWeight.w700, -0.3),
      titleLarge: tight(base.titleLarge, 20, FontWeight.w700, -0.2),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, color: c.inkSecondary),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, color: c.muted),
      labelLarge: base.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted),
    );

    final fieldRadius = BorderRadius.circular(radiusSm);
    OutlineInputBorder inputBorder([Color? color, double width = 1]) => OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      // The thin iOS back chevron on every screen.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 0.6, space: 0.6),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(),
        enabledBorder: inputBorder(),
        disabledBorder: inputBorder(),
        focusedBorder: inputBorder(c.ink, 1.4),
        errorBorder: inputBorder(c.danger),
        focusedErrorBorder: inputBorder(c.danger, 1.4),
        labelStyle: text.bodyMedium?.copyWith(color: c.muted),
        floatingLabelStyle: TextStyle(color: c.inkSecondary, fontWeight: FontWeight.w600),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        errorMaxLines: 3,
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          minimumSize: const Size(64, 54),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          elevation: 0,
          minimumSize: const Size(64, 54),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.surface,
          side: BorderSide.none,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: fieldRadius),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary, textStyle: text.labelLarge?.copyWith(fontSize: 15)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.ink,
        foregroundColor: c.onInk,
        elevation: 3,
        highlightElevation: 6,
        shape: buttonShape,
        extendedTextStyle: text.labelLarge,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        disabledColor: c.surfaceAlt,
        side: BorderSide.none,
        labelStyle: text.labelLarge?.copyWith(color: c.ink, fontSize: 14),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: c.onInk, fontSize: 14),
        checkmarkColor: c.onInk,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.muted.withValues(alpha: 0.35),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: fieldRadius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        titleTextStyle: text.bodyLarge?.copyWith(color: c.ink, fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceLg),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.success : c.surfaceAlt,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.ink : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onInk),
        side: BorderSide(color: c.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.inkSecondary,
        indicator: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.14), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: text.labelLarge?.copyWith(fontSize: 14),
        unselectedLabelStyle: text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.primarySoft),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.hero,
        headerForegroundColor: c.onHero,
        rangeSelectionBackgroundColor: c.primarySoft,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
