import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/sectionHeader.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/factory.dart';

/// Start and end the season. Every kiln starts at its own time, so it is a
/// button, not a date. Ending the season opens the off-season the same day;
/// balances, credit and stock carry over as they are.
class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().factory.fetchPeriods());
  }

  Future<void> _switch(bool start) async {
    final ok = await showConfirmDialog(
      context,
      title: start ? 'start_season'.tr() : 'end_season'.tr(),
      message: start ? 'start_season_message'.tr() : 'end_season_message'.tr(),
      confirmText: start ? 'start_season'.tr() : 'end_season'.tr(),
      isDestructive: !start,
    );
    if (!ok || !mounted) return;
    final module = context.read<Core>().factory;
    setState(() => _busy = true);
    final done = start ? await module.startSeason(startedOn: apiDate(_date)) : await module.endSeason(endedOn: apiDate(_date));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast(start ? 'season_started'.tr() : 'season_ended'.tr());
  }

  String _range(Period period) {
    final from = Formatters.formatDate(period.startedOn);
    return period.endedOn == null
        ? 'period_since'.tr(namedArgs: {'date': from})
        : '$from – ${Formatters.formatDate(period.endedOn!)}';
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final current = core.openFactory?.period;
    final inSeason = current?.kind == PeriodKind.season;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text('season'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          if (current != null)
            AppCard(
              color: inSeason ? colors.successSoft : colors.warningSoft,
              borderColor: inSeason ? colors.successSoft : colors.warningSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inSeason ? 'season_running'.tr() : 'off_season_running'.tr(),
                    style: context.text.titleLarge?.copyWith(color: inSeason ? colors.success : colors.warning),
                  ),
                  Text(_range(current), style: context.text.bodyLarge),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.spaceLg),
          DateField(label: inSeason ? 'season_end_date'.tr() : 'season_start_date'.tr(), value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: AppTheme.spaceMd),
          AppButton(
            text: inSeason ? 'end_season'.tr() : 'start_season'.tr(),
            icon: inSeason ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
            variant: inSeason ? AppButtonVariant.danger : AppButtonVariant.primary,
            isLoading: _busy,
            onPressed: () => _switch(!inSeason),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(inSeason ? 'end_season_help'.tr() : 'start_season_help'.tr(), style: context.text.bodySmall),
          SectionHeader(title: 'past_periods'.tr(), padding: const EdgeInsets.only(top: AppTheme.spaceLg)),
          for (final period in core.factory.periods.value ?? const <Period>[])
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: AppCard(
                child: Row(
                  children: [
                    Icon(
                      period.kind == PeriodKind.season ? Icons.wb_sunny_rounded : Icons.water_drop_rounded,
                      color: period.kind == PeriodKind.season ? colors.warning : colors.info,
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(period.name ?? period.kind.displayName, style: context.text.titleSmall),
                          Text(_range(period), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
