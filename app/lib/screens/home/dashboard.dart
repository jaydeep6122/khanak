import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/cash/detail.dart';
import 'package:khanak/screens/entries/list.dart';
import 'package:khanak/screens/factory/list.dart';
import 'package:khanak/screens/home/newEntrySheet.dart';
import 'package:khanak/screens/trade/parties.dart';
import 'package:khanak/screens/workers/detail.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/report.dart';

/// Home: today's numbers on a dark card, the everyday entries one tap away,
/// and where the money and the bricks are. A supervisor sees the entries,
/// their cash and their own account, not totals.
class DashboardTab extends StatefulWidget {
  /// Switches to another tab: 1 is workers, 2 is credit.
  final ValueChanged<int> onOpenTab;

  const DashboardTab({super.key, required this.onOpenTab});

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

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final factory = core.openFactory!;
    final supervisor = core.isSupervisor;
    final colors = context.colors;
    scheduleReload(!supervisor && core.report.summary.needsReload, () => core.report.fetchSummary());
    final canSwitch = core.factory.factories.length > 1 || core.can(MemberRole.owner);
    // Four quick buttons: the three everyday entries and, for the owner and
    // munim, a sale. The rest are behind "+".
    final quick = entryActions(core).take(4).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppTheme.fabClearance),
            children: [
              LargeTitle(
                title: 'today'.tr(),
                overline: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canSwitch ? () => Navigator.of(context).push(getPageRoute(const FactoryListScreen())) : null,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          factory.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                      ),
                      if (canSwitch) Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: colors.muted),
                    ],
                  ),
                ),
                badge: factory.period == null ? null : _PeriodPill(period: factory.period!),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!factory.canWrite) const _Banner(kind: _BannerKind.subscriptionEnded),
                    if (factory.canWrite && factory.subscription!.isTrial && factory.subscription!.daysLeft <= 7)
                      _Banner(kind: _BannerKind.trialEnding, days: factory.subscription!.daysLeft),
                    if (supervisor) ...[
                      _QuickActions(actions: quick),
                      const SizedBox(height: AppTheme.space2xl),
                      _SupervisorCards(factory: factory),
                    ] else
                      LoadStateSection<HomeSummary>(
                        state: core.report.summary,
                        onRetry: () => _load(refresh: true),
                        builder: (context, summary) =>
                            _Summary(summary: summary, quick: quick, onOpenTab: widget.onOpenTab),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final Period period;

  const _PeriodPill({required this.period});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final season = period.kind == PeriodKind.season;
    final date = Formatters.formatDateShort(period.startedOn);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Pill(
        text: season ? 'season_since'.tr(namedArgs: {'date': date}) : 'off_season_since'.tr(namedArgs: {'date': date}),
        color: season ? colors.success : colors.warning,
        background: season ? colors.successSoft : colors.warningSoft,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final HomeSummary summary;
  final List<EntryAction> quick;
  final ValueChanged<int> onOpenTab;

  const _Summary({required this.summary, required this.quick, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    void open(Widget screen) => Navigator.of(context).push(getPageRoute(screen));
    final offSeason = summary.period?.kind == PeriodKind.offSeason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodayCard(summary: summary),
        const SizedBox(height: AppTheme.space2xl),
        _QuickActions(actions: quick),
        const SizedBox(height: AppTheme.space3xl),

        // Where the money is.
        SectionTitle('accounts'.tr(), action: 'all_entries'.tr(), onAction: () => open(const EntriesTab())),
        Row(
          children: [
            Expanded(
              child: _MoneyCard(
                label: 'to_pay_workers'.tr(),
                value: Formatters.formatCurrency(summary.payable),
                note: 'workers_count'.tr(namedArgs: {'count': '${summary.activeWorkers}'}),
                onTap: () => onOpenTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoneyCard(
                label: 'market_credit_total'.tr(),
                value: Formatters.formatCurrency(summary.marketCredit),
                valueColor: colors.success,
                note: 'customers'.tr(),
                onTap: () => onOpenTab(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GroupedSection(
          dividerIndent: AppTheme.spaceLg,
          children: [
            GroupedRow(
              title: 'to_get_from_workers'.tr(),
              value: Formatters.formatCurrency(summary.receivable),
              valueColor: summary.receivable > 0 ? colors.success : null,
              onTap: () => onOpenTab(1),
            ),
            GroupedRow(
              title: 'suppliers_total'.tr(),
              value: Formatters.formatCurrency(summary.owedToSuppliers),
              valueColor: summary.owedToSuppliers > 0 ? colors.danger : null,
              onTap: () => open(const PartiesScreen(kind: 'supplier')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StockCard(stock: summary.stock),
        const SizedBox(height: AppTheme.space3xl),

        // The season so far.
        GroupedSection(
          caption: offSeason ? 'this_off_season'.tr() : 'this_season'.tr(),
          children: [
            GroupedRow(
              leading: const TintIcon(tint: Tint.bricks, size: 34),
              title: 'bricks_made'.tr(),
              value: Formatters.formatCount(summary.madeInPeriod),
            ),
            GroupedRow(
              leading: const TintIcon(tint: Tint.fire, size: 34),
              title: 'bricks_unloaded'.tr(),
              value: Formatters.formatCount(summary.unloadedInPeriod),
            ),
            GroupedRow(
              leading: const TintIcon(tint: Tint.work, size: 34),
              title: 'wages_earned'.tr(),
              value: Formatters.formatCurrency(summary.wagesInPeriod),
            ),
            GroupedRow(
              leading: const TintIcon(tint: Tint.money, size: 34),
              title: 'advances_given'.tr(),
              value: Formatters.formatCurrency(summary.advancesInPeriod),
            ),
            GroupedRow(
              leading: const TintIcon(tint: Tint.truck, size: 34),
              title: 'sales_amount'.tr(),
              subtitle: 'bricks_sold_count'.tr(
                namedArgs: {'count': Formatters.formatCount(summary.bricksSoldInPeriod)},
              ),
              value: Formatters.formatCurrency(summary.salesInPeriod),
            ),
            GroupedRow(
              leading: const TintIcon(tint: Tint.expense, size: 34),
              title: 'expenses_amount'.tr(),
              value: Formatters.formatCurrency(summary.expensesInPeriod),
            ),
          ],
        ),
      ],
    );
  }
}

/// The dark card: bricks counted today, large, with today's advances, sales
/// and expenses below. A warm glow sits in the corner.
class _TodayCard extends StatelessWidget {
  final HomeSummary summary;

  const _TodayCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppTheme.radiusXl);
    return Container(
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.hero.withValues(alpha: 0.55),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x8CE06234), Color(0x00E06234)], stops: [0, 0.7]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('bricks_made_today'.tr(), style: context.text.bodySmall?.copyWith(color: colors.heroMuted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formatters.formatCount(summary.madeToday),
                    style: context.text.displaySmall?.copyWith(color: colors.onHero, fontSize: 46),
                  ),
                ),
                if (summary.bricksSoldToday > 0)
                  Text(
                    'bricks_sold_today_line'.tr(
                      namedArgs: {'count': Formatters.formatCount(summary.bricksSoldToday)},
                    ),
                    style: context.text.bodySmall?.copyWith(color: const Color(0xFF8FD3AE)),
                  ),
                const SizedBox(height: AppTheme.spaceLg),
                Row(
                  children: [
                    _HeroFigure(label: 'advance'.tr(), value: summary.advancesToday),
                    const SizedBox(width: AppTheme.spaceSm),
                    _HeroFigure(label: 'action_sale'.tr(), value: summary.salesToday),
                    const SizedBox(width: AppTheme.spaceSm),
                    _HeroFigure(label: 'action_expense'.tr(), value: summary.expensesToday),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final String label;
  final double value;

  const _HeroFigure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.onHero.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: colors.heroMuted, fontSize: 12),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.formatCurrency(value),
                style: context.text.titleSmall?.copyWith(color: colors.onHero, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round-cornered icon buttons in a row, named underneath.
class _QuickActions extends StatelessWidget {
  final List<EntryAction> actions;

  const _QuickActions({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final action in actions)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => action.open(context),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: context.cardShadow),
                    child: Material(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 62,
                        height: 62,
                        child: Icon(action.tint.icon, color: action.tint.color(context), size: 27),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(color: context.colors.ink),
                  ),
                ],
              ),
            ),
          ),
        // Keep buttons the same size when there are fewer than four.
        for (var i = actions.length; i < 4; i++) const Expanded(child: SizedBox()),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String note;
  final VoidCallback onTap;

  const _MoneyCard({
    required this.label,
    required this.value,
    this.valueColor,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: context.cardShadow),
      child: Material(
        color: context.colors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(note, style: context.text.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Raw, in-kiln and fired bricks as one bar, with each kiln listed when
/// there is more than one.
class _StockCard extends StatelessWidget {
  final BrickStock stock;

  const _StockCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = stock.raw + stock.kiln + stock.fired;
    const rawColor = Color(0xFFD9C3A5);
    const kilnColor = Color(0xFFE8703F);
    const firedColor = Color(0xFF8A3A1F);
    String n(int value) => Formatters.formatCount(value);

    final parts = [(stock.raw, rawColor), (stock.kiln, kilnColor), (stock.fired, firedColor)].where((p) => p.$1 > 0);
    Widget legend(Color color, String label, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('$label ${n(value)}', style: context.text.bodySmall?.copyWith(color: colors.inkSecondary, fontSize: 12)),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('brick_stock'.tr(), style: context.text.bodySmall)),
              Text(n(total), style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 8,
            child: parts.isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                  )
                : Row(
                    spacing: 3,
                    children: [
                      for (final (value, color) in parts)
                        Expanded(
                          flex: value,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              legend(rawColor, 'stock_raw'.tr(), stock.raw),
              legend(kilnColor, 'stock_kiln'.tr(), stock.kiln),
              legend(firedColor, 'stock_fired'.tr(), stock.fired),
            ],
          ),
          if (stock.kilns.length > 1) ...[
            const SizedBox(height: AppTheme.spaceMd),
            const Divider(),
            for (final kiln in stock.kilns)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 16, color: colors.warning),
                    const SizedBox(width: 6),
                    Expanded(child: Text(kiln.name, style: context.text.bodyMedium)),
                    Text(n(kiln.quantity), style: context.text.titleSmall),
                  ],
                ),
              ),
          ],
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
    void open(Widget screen) => Navigator.of(context).push(getPageRoute(screen));
    return GroupedSection(
      children: [
        GroupedRow(
          leading: const TintIcon(tint: Tint.money, icon: Icons.account_balance_wallet_rounded),
          title: 'my_cash'.tr(),
          onTap: () => open(CashDetailScreen(holderId: core.auth.user!.id, holderName: core.auth.user!.name)),
        ),
        if (factory.workerId != null)
          GroupedRow(
            leading: const TintIcon(tint: Tint.bricks, icon: Icons.badge_rounded),
            title: 'my_account'.tr(),
            onTap: () => open(WorkerDetailScreen(workerId: factory.workerId!)),
          ),
      ],
    );
  }
}

enum _BannerKind { subscriptionEnded, trialEnding }

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
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLg),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: color),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(text, style: context.text.bodyLarge?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
