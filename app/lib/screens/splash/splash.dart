import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appLogo.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/auth/login.dart';
import 'package:khanak/screens/auth/sessionRouter.dart';
import 'package:khanak/screens/settings/language.dart';
import 'package:khanak/screens/update/update.dart';

/// Picks up where Android's own splash leaves off: the same kiln, the same
/// size, in the same place, on the same dark colour, so the hand-over does
/// not show. The name and a warm glow then fade in while the app starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
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
    final glow = CurvedAnimation(parent: _reveal, curve: Curves.easeOut);
    final name = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: LogoColors.splash,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: glow,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, -0.75),
                    radius: 1.1,
                    colors: [Color(0x66E06234), Color(0x00E06234)],
                  ),
                ),
              ),
            ),
            // Where Android's splash put it: 288 × 288 in the middle.
            const Center(
              child: SizedBox.square(
                dimension: 288,
                child: CustomPaint(painter: LogoPainter(layer: LogoLayer.foreground, contentScale: 0.825)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 210),
                child: FadeTransition(
                  opacity: name,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(name),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'app_name'.tr(),
                          style: context.text.headlineLarge?.copyWith(
                            color: const Color(0xFFF6F2EC),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceXs),
                        Text(
                          'app_tagline'.tr(),
                          style: context.text.bodyMedium?.copyWith(color: const Color(0xFFB8B0A4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: FadeTransition(opacity: name, child: const _Dots()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots lighting up in turn while the app starts.
class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final lit = (_controller.value * 3).floor() % 3;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == lit ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == lit ? const Color(0xFFE8703F) : const Color(0xFF4A453E),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        );
      },
    );
  }
}
