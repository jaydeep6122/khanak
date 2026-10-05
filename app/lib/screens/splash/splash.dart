import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/auth/login.dart';
import 'package:khanak/screens/auth/sessionRouter.dart';
import 'package:khanak/screens/settings/language.dart';
import 'package:khanak/screens/update/update.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final core = context.read<Core>();
    if (await blockIfUnavailable() || !mounted) return;

    // The very first launch asks for the language before anything else.
    if (core.settings.language == null) {
      await Navigator.of(context).push(getPageRoute(const LanguageScreen(firstLaunch: true)));
      if (!mounted) return;
    }

    var signedIn = false;
    try {
      signedIn = await core.auth.tryAutoLogin();
    } catch (_) {}
    if (!mounted) return;

    if (signedIn) {
      await openAfterSignIn(context);
    } else {
      Navigator.of(context).pushReplacement(getPageRoute(const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrickMark(size: 112),
            SizedBox(height: AppTheme.space3xl),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
