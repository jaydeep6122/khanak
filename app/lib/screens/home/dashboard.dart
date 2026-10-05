import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/sectionHeader.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/cash/detail.dart';
import 'package:khanak/screens/entries/brickCountForm.dart';
import 'package:khanak/screens/entries/unloadingForm.dart';
import 'package:khanak/screens/entries/workEntryForm.dart';
import 'package:khanak/screens/settings/rates.dart';
import 'package:khanak/screens/workers/detail.dart';
import 'package:khanak/screens/workers/transactionForm.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/report.dart';

/// Home: the big buttons for everyday entries, and for the owner and munim
/// today's numbers.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    final core = context.read<Core>();
    if (refresh) await core.factory.refreshSelected();
    if (!core.isSupervisor) await core.report.fetchSummary(refresh: refresh);
  }

  Future<void> _giveAdvance() async {
    final core = context.read<Core>();
    final worker = await pickWorker(
      context,
      title: 'advance_pick_worker'.tr(),
      // A supervisor never gives an advance to themselves.
      exclude: {if (core.isSupervisor && core.openFactory?.workerId != null) core.openFactory!.workerId!},
    );
    if (worker == null || !mounted) return;
    Navigator.of(context).push(getPageRoute(TransactionFormScreen(worker: worker, kind: TxnKind.advance)));
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final factory = core.openFactory!;
    final supervisor = core.isSupervisor;
    scheduleReload(!supervisor && core.report.summary.needsReload, () => core.report.fetchSummary());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(factory.name, style: context.text.titleLarge),
            if (factory.period != null) _PeriodLabel(period: factory.period!),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.space2xl),
          children: [
            if (!factory.canWrite) const _Banner(kind: _BannerKind.subscriptionEnded),
            if (factory.canWrite && factory.subscription!.isTrial && factory.subscription!.daysLeft <= 7)
              _Banner(kind: _BannerKind.trialEnding, days: factory.subscription!.daysLeft),
            if (core.can(MemberRole.owner) && core.factory.ratesMissing) const _Banner(kind: _BannerKind.ratesMissing),
            _ActionGrid(
              actions: [
                _Action(
                  icon: Icons.grid_view_rounded,
                  label: 'action_brick_count'.tr(),
                  onTap: () => Navigator.of(context).push(getPageRoute(const BrickCountFormScreen())),
                ),
                _Action(
                  icon: Icons.local_fire_department_rounded,
                  label: 'action_unloading'.tr(),
                  onTap: () => Navigator.of(context).push(getPageRoute(const UnloadingFormScreen())),
                ),
                _Action(icon: Icons.currency_rupee_rounded, label: 'action_advance'.tr(), onTap: _giveAdvance),
                if (!supervisor)
                  _Action(
                    icon: Icons.handyman_rounded,
                    label: 'action_other_work'.tr(),
                    onTap: () => Navigator.of(context).push(getPageRoute(const WorkEntryFormScreen())),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            if (supervisor) _SupervisorCards(factory: factory) else _Summary(core: core, onRetry: _load),
          ],
        ),
      ),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  final Period period;

  const _PeriodLabel({required this.period});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final season = period.kind == PeriodKind.season;
    return Text(
      season
          ? 'season_since'.tr(namedArgs: {'date': Formatters.formatDate(period.startedOn)})
          : 'off_season_since'.tr(namedArgs: {'date': Formatters.formatDate(period.startedOn)}),
      style: context.text.bodySmall?.copyWith(color: season ? colors.success : colors.warning),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap});
}

/// Big square buttons, two to a row: easy to hit and to read at the kiln.
class _ActionGrid extends StatelessWidget {
  final List<_Action> actions;

  const _ActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.spaceMd,
      crossAxisSpacing: AppTheme.spaceMd,
      childAspectRatio: 1.25,
      children: [
        for (final action in actions)
          Material(
            color: colors.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              onTap: action.onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(action.icon, color: colors.onPrimary, size: 34),
                    Text(
                      action.label,
                      maxLines: 2,
                      style: context.text.titleLarge?.copyWith(color: colors.onPrimary, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final Core core;
  final Future<void> Function({bool refresh}) onRetry;

  const _Summary({required this.core, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LoadStateSection<HomeSummary>(
      state: core.report.summary,
      onRetry: () => onRetry(refresh: true),
      builder: (context, summary) {
        final colors = context.colors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: 'today'.tr()),
            Row(
              children: [
                Expanded(child: _Figure(label: 'bricks_made_today'.tr(), value: Formatters.formatNumber(summary.madeToday.toDouble()))),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(child: _Figure(label: 'advances_today'.tr(), value: Formatters.formatCurrency(summary.advancesToday))),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            SectionHeader(title: 'workers_money'.tr()),
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: 'to_pay_workers'.tr(),
                    value: Formatters.formatCurrency(summary.payable),
                    color: colors.danger,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: _Figure(
                    label: 'to_get_from_workers'.tr(),
                    value: Formatters.formatCurrency(summary.receivable),
                    color: colors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            SectionHeader(title: 'brick_stock'.tr()),
            Row(
              children: [
                Expanded(child: _Figure(label: 'stock_raw'.tr(), value: Formatters.formatNumber(summary.stock.raw.toDouble()))),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(child: _Figure(label: 'stock_kiln'.tr(), value: Formatters.formatNumber(summary.stock.kiln.toDouble()))),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(child: _Figure(label: 'stock_fired'.tr(), value: Formatters.formatNumber(summary.stock.fired.toDouble()))),
              ],
            ),
            // With more than one kiln, what is in each.
            if (summary.stock.kilns.length > 1) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppCard(
                child: Column(
                  children: [
                    for (final kiln in summary.stock.kilns)
                      _Line(label: kiln.name, value: Formatters.formatNumber(kiln.quantity.toDouble())),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceSm),
            SectionHeader(title: summary.period?.kind == PeriodKind.offSeason ? 'this_off_season'.tr() : 'this_season'.tr()),
            AppCard(
              child: Column(
                children: [
                  _Line(label: 'bricks_made'.tr(), value: Formatters.formatNumber(summary.madeInPeriod.toDouble())),
                  _Line(label: 'bricks_unloaded'.tr(), value: Formatters.formatNumber(summary.unloadedInPeriod.toDouble())),
                  _Line(label: 'wages_earned'.tr(), value: Formatters.formatCurrency(summary.wagesInPeriod)),
                  _Line(label: 'advances_given'.tr(), value: Formatters.formatCurrency(summary.advancesInPeriod)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Figure({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.bodySmall, maxLines: 2),
          const SizedBox(height: AppTheme.spaceXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs + 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyLarge)),
          Text(value, style: context.text.titleMedium),
        ],
      ),
    );
  }
}

/// A supervisor sees their cash in hand and their own account, not totals.
class _SupervisorCards extends StatelessWidget {
  final Factory factory;

  const _SupervisorCards({required this.factory});

  @override
  Widget build(BuildContext context) {
    final core = context.read<Core>();
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          onTap: () => Navigator.of(context).push(
            getPageRoute(CashDetailScreen(holderId: core.auth.user!.id, holderName: core.auth.user!.name)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: colors.primary, size: 30),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(child: Text('my_cash'.tr(), style: context.text.titleMedium)),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
        if (factory.workerId != null) ...[
          const SizedBox(height: AppTheme.spaceSm),
          AppCard(
            onTap: () => Navigator.of(context).push(getPageRoute(WorkerDetailScreen(workerId: factory.workerId!))),
            child: Row(
              children: [
                Icon(Icons.badge_rounded, color: colors.primary, size: 30),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(child: Text('my_account'.tr(), style: context.text.titleMedium)),
                Icon(Icons.chevron_right_rounded, color: colors.muted),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

enum _BannerKind { subscriptionEnded, trialEnding, ratesMissing }

class _Banner extends StatelessWidget {
  final _BannerKind kind;
  final int days;

  const _Banner({required this.kind, this.days = 0});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (text, color, soft) = switch (kind) {
      _BannerKind.subscriptionEnded => ('subscription_ended_banner'.tr(), colors.danger, colors.dangerSoft),
      _BannerKind.trialEnding => (
        'trial_ending_banner'.tr(namedArgs: {'days': '${days < 0 ? 0 : days}'}),
        colors.warning,
        colors.warningSoft,
      ),
      _BannerKind.ratesMissing => ('rates_missing_banner'.tr(), colors.warning, colors.warningSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: AppCard(
        color: soft,
        borderColor: soft,
        onTap: kind == _BannerKind.ratesMissing
            ? () => Navigator.of(context).push(getPageRoute(const RatesScreen()))
            : null,
        child: Row(
          children: [
            Icon(Icons.info_rounded, color: color),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(child: Text(text, style: context.text.bodyLarge?.copyWith(color: color))),
          ],
        ),
      ),
    );
  }
}
