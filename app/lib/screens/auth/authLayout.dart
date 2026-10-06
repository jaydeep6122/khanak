import 'package:flutter/material.dart';
import 'package:khanak/components/appLogo.dart';
import 'package:khanak/global/themes.dart';

/// Shared frame for sign-in screens: logo, heading and a centred form.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showLogo;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canPop ? AppBar() : null,
      body: SafeArea(
        top: !canPop,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space2xl,
              vertical: AppTheme.space2xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showLogo) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: AppLogo(),
                      ),
                      const SizedBox(height: AppTheme.space2xl),
                    ],
                    Text(title, style: context.text.headlineLarge),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(subtitle, style: context.text.bodyLarge?.copyWith(
                      color: context.colors.inkSecondary,
                    )),
                    const SizedBox(height: AppTheme.space3xl),
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: AppTheme.space2xl),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Question? Action" line under a form.
class AuthFooterLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: context.text.bodyMedium),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}
