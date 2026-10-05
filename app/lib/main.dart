import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/screens/auth/login.dart';
import 'package:khanak/helpers/crashReporting.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/splash/splash.dart';
import 'package:khanak/screens/update/update.dart';
import 'package:khanak/services/appUpdateService.dart';
import 'package:khanak/storage/hive.dart';
import 'package:khanak/api/dio.dart';
import 'package:khanak/api/api.dart';
import 'package:khanak/core/Core.dart';

void main() {
  // Everything runs inside the guarded zone so startup failures are reported
  // too, not just errors raised once the app is running.
  CrashReporting.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Hive.initFlutter();
    await openAllBoxes();
    await EasyLocalization.ensureInitialized();

    final dioInstance = await DioInstance.init(baseURL: AppConstants.apiBaseUrl);
    Api.initialize(dioInstance.dio);

    final core = Core();
    core.settings.load();

    // Until a language is picked on the first launch, Gujarati. The choice
    // lives in PreferencesBox, so easy_localization's own saving stays off.
    final language = core.settings.language ?? AppLanguage.gujarati;

    runApp(
      EasyLocalization(
        supportedLocales: [for (final language in AppLanguage.values) Locale(language.code)],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: Locale(language.code),
        useOnlyLangCode: true,
        saveLocale: false,
        child: ChangeNotifierProvider.value(value: core, child: const KhanakApp()),
      ),
    );
  });
}

class KhanakApp extends StatefulWidget {
  const KhanakApp({super.key});

  @override
  State<KhanakApp> createState() => _KhanakAppState();
}

class _KhanakAppState extends State<KhanakApp> with WidgetsBindingObserver {
  Locale? _builtLocale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DioInstance.onSessionExpired = () {
      if (!mounted) return;
      context.read<Core>().auth.handleSessionExpired();
      // Clearing state rebuilds the screens that are open; navigating in the
      // same breath would run while Navigator is still busy with that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          getPageRoute(const LoginScreen()),
          (route) => false,
        );
      });
    };
    // Every request is refused during maintenance; whichever screen made it,
    // the maintenance screen takes over once.
    DioInstance.onMaintenance = () {
      if (!mounted || AppUpdateService.blocked) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!AppUpdateService.blocked) showBlock(const UnderMaintenance());
      });
      // A failed background request may not schedule a frame of its own.
      WidgetsBinding.instance.scheduleFrame();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // A phone can keep the app open for days; the splash check alone would
  // miss a minimum raised in between.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) blockIfUnavailable();
  }

  /// `'key'.tr()` reads no inherited widget, so screens already open would
  /// keep the old language until something else happened to rebuild them.
  void _rebuildEverything() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<Core, ThemeMode>((c) => c.settings.themeMode);
    final locale = context.locale;
    if (_builtLocale != null && _builtLocale != locale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildEverything();
      });
    }
    _builtLocale = locale;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: locale,
      home: const SplashScreen(),
    );
  }
}
