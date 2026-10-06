import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/appLogo.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';

/// Three big choices, each written in its own language, so anyone can find
/// theirs. Shown on the first launch, and from settings.
class LanguageScreen extends StatelessWidget {
  final bool firstLaunch;

  const LanguageScreen({super.key, this.firstLaunch = false});

  Future<void> _pick(BuildContext context, AppLanguage language) async {
    final settings = context.read<Core>().settings;
    final navigator = Navigator.of(context);
    await context.setLocale(Locale(language.code));
    await settings.setLanguage(language);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select<Core, AppLanguage?>((c) => c.settings.language);
    final colors = context.colors;

    return PopScope(
      // The first launch needs an answer before the app can go on.
      canPop: !firstLaunch,
      child: Scaffold(
        appBar: firstLaunch ? null : AppBar(title: Text('language'.tr())),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.space2xl),
            children: [
              if (firstLaunch) ...[
                const SizedBox(height: AppTheme.space2xl),
                const Align(alignment: Alignment.centerLeft, child: AppLogo()),
                const SizedBox(height: AppTheme.space2xl),
                // Asked in all three, since no language is chosen yet.
                Text('ભાષા પસંદ કરો', style: context.text.headlineSmall),
                Text('भाषा चुनें · Choose language', style: context.text.titleMedium?.copyWith(color: colors.inkSecondary)),
                const SizedBox(height: AppTheme.space2xl),
              ],
              for (final language in AppLanguage.values) ...[
                AppCard(
                  onTap: () => _pick(context, language),
                  borderColor: current == language ? colors.primary : null,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2xl, vertical: AppTheme.space2xl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(language.nativeName, style: context.text.headlineSmall),
                      ),
                      if (current == language) Icon(Icons.check_circle_rounded, color: colors.primary, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
