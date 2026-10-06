import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/pagedList.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/entries/brickCountForm.dart';
import 'package:khanak/screens/entries/unloadingForm.dart';
import 'package:khanak/screens/entries/workEntryForm.dart';
import 'package:khanak/screens/trade/expenseForm.dart';
import 'package:khanak/screens/trade/saleForm.dart';
import 'package:khanak/types/trade.dart';
import 'package:khanak/types/work.dart';

/// Every entry, newest first: brick counts, unloadings and work typed in by
/// hand. A supervisor sees only their own counts and unloadings.
class EntriesTab extends StatefulWidget {
  /// Shown as a tab of the home screen, under the floating tab bar, rather
  /// than opened on its own.
  final bool asTab;

  const EntriesTab({super.key, this.asTab = false});

  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<EntriesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final core = context.read<Core>();
      core.entry.fetchCounts();
      core.entry.fetchUnloadings();
      if (!core.isSupervisor) {
        core.entry.fetchWorkEntries();
        core.trade.fetchSales();
        core.trade.fetchExpenses();
      }
    });
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.of(context).push(getPageRoute(screen));
    if (changed != null && mounted) context.read<Core>().markBooksChanged();
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final entry = core.entry;
    final supervisor = core.isSupervisor;
    scheduleReload(entry.counts.needsReload, () => entry.fetchCounts());
    scheduleReload(entry.unloadings.needsReload, () => entry.fetchUnloadings());
    final trade = core.trade;
    if (!supervisor) {
      scheduleReload(entry.workEntries.needsReload, () => entry.fetchWorkEntries());
      scheduleReload(trade.sales.needsReload, () => trade.fetchSales());
      scheduleReload(trade.expenses.needsReload, () => trade.fetchExpenses());
    }

    // The last row clears the floating tab bar.
    final padding = EdgeInsets.fromLTRB(
      AppTheme.spaceXl,
      AppTheme.spaceMd,
      AppTheme.spaceXl,
      widget.asTab ? AppTheme.fabClearance : AppTheme.space2xl,
    );

    return DefaultTabController(
      length: supervisor ? 2 : 5,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.asTab,
          title: Text('tab_entries'.tr()),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _SegmentTabs(
              scrollable: !supervisor,
              tabs: [
                Tab(text: 'tab_counts'.tr()),
                Tab(text: 'tab_unloadings'.tr()),
                if (!supervisor) ...[
                  Tab(text: 'tab_other_work'.tr()),
                  Tab(text: 'tab_sales'.tr()),
                  Tab(text: 'tab_expenses'.tr()),
                ],
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            PagedListView<BrickCount>(
              items: entry.counts.items,
              isLoading: entry.counts.isLoading,
              isLoadingMore: entry.counts.isLoadingMore,
              hasMore: entry.counts.data.hasMore,
              error: entry.counts.error,
              onRefresh: () => entry.fetchCounts(refresh: true),
              onLoadMore: () => entry.fetchCounts(more: true),
              padding: padding,
              emptyState: EmptyState(icon: Icons.grid_view_rounded, title: 'no_counts_yet'.tr()),
              itemBuilder: (context, count) => _EntryRow(
                tint: Tint.bricks,
                title: '${Formatters.formatCount(count.quantity)} · ${count.reason.displayName}',
                subtitle: [
                  Formatters.formatDate(count.countedOn),
                  if (count.molderName != null) count.molderName!,
                  if (count.kilnName != null) count.kilnName!,
                  if (count.alreadyCounted) 'already_counted_short'.tr(),
                  if (supervisor == false && count.createdByName != null) count.createdByName!,
                ].join(' · '),
                amount: supervisor ? null : count.pay,
                cancelled: count.isCancelled,
                onTap: () => _open(BrickCountFormScreen(countId: count.id)),
              ),
            ),
            PagedListView<KilnUnloading>(
              items: entry.unloadings.items,
              isLoading: entry.unloadings.isLoading,
              isLoadingMore: entry.unloadings.isLoadingMore,
              hasMore: entry.unloadings.data.hasMore,
              error: entry.unloadings.error,
              onRefresh: () => entry.fetchUnloadings(refresh: true),
              onLoadMore: () => entry.fetchUnloadings(more: true),
              padding: padding,
              emptyState: EmptyState(icon: Icons.local_fire_department_rounded, title: 'no_unloadings_yet'.tr()),
              itemBuilder: (context, unloading) => _EntryRow(
                tint: Tint.fire,
                title: 'unloading_row'.tr(namedArgs: {'bricks': Formatters.formatCount(unloading.quantity)}),
                subtitle: [
                  Formatters.formatDate(unloading.unloadedOn),
                  if (unloading.kilnName != null) unloading.kilnName!,
                  if (supervisor == false && unloading.createdByName != null) unloading.createdByName!,
                ].join(' · '),
                amount: supervisor ? null : unloading.pay,
                cancelled: unloading.isCancelled,
                onTap: () => _open(UnloadingFormScreen(unloadingId: unloading.id)),
              ),
            ),
            if (!supervisor)
              PagedListView<WorkEntry>(
                items: entry.workEntries.items,
                isLoading: entry.workEntries.isLoading,
                isLoadingMore: entry.workEntries.isLoadingMore,
                hasMore: entry.workEntries.data.hasMore,
                error: entry.workEntries.error,
                onRefresh: () => entry.fetchWorkEntries(refresh: true),
                onLoadMore: () => entry.fetchWorkEntries(more: true),
                padding: padding,
                emptyState: EmptyState(icon: Icons.handyman_rounded, title: 'no_work_yet'.tr()),
                itemBuilder: (context, work) => _EntryRow(
                  tint: Tint.work,
                  title: '${work.workerName} · ${work.label}',
                  subtitle: [
                    Formatters.formatDate(work.entryDate),
                    if (work.quantity != null) Formatters.formatCount(work.quantity!),
                    if (work.note != null) work.note!,
                  ].join(' · '),
                  amount: work.amount,
                  cancelled: work.isCancelled,
                  onTap: core.can(MemberRole.munim) ? () => _open(WorkEntryFormScreen(entry: work)) : null,
                ),
              ),
            if (!supervisor)
              PagedListView<Sale>(
                items: trade.sales.items,
                isLoading: trade.sales.isLoading,
                isLoadingMore: trade.sales.isLoadingMore,
                hasMore: trade.sales.data.hasMore,
                error: trade.sales.error,
                onRefresh: () => trade.fetchSales(refresh: true),
                onLoadMore: () => trade.fetchSales(more: true),
                padding: padding,
                emptyState: EmptyState(icon: Icons.local_shipping_rounded, title: 'no_sales_yet'.tr()),
                itemBuilder: (context, sale) => _EntryRow(
                  tint: Tint.truck,
                  title: [
                    'sale_row'.tr(namedArgs: {'bricks': Formatters.formatCount(sale.quantity)}),
                    ?sale.buyer,
                  ].join(' · '),
                  subtitle: [
                    Formatters.formatDate(sale.soldOn),
                    sale.delivery.displayName,
                    if (sale.due > 0.004) 'credit_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(sale.due)}),
                  ].join(' · '),
                  amount: sale.total,
                  cancelled: sale.isCancelled,
                  onTap: () => _open(SaleFormScreen(saleId: sale.id)),
                ),
              ),
            if (!supervisor)
              PagedListView<Expense>(
                items: trade.expenses.items,
                isLoading: trade.expenses.isLoading,
                isLoadingMore: trade.expenses.isLoadingMore,
                hasMore: trade.expenses.data.hasMore,
                error: trade.expenses.error,
                onRefresh: () => trade.fetchExpenses(refresh: true),
                onLoadMore: () => trade.fetchExpenses(more: true),
                padding: padding,
                emptyState: EmptyState(icon: Icons.receipt_rounded, title: 'no_expenses_yet'.tr()),
                itemBuilder: (context, expense) => _EntryRow(
                  tint: Tint.expense,
                  title: [expense.category.displayName, ?expense.partyName, ?expense.truckNumber].join(' · '),
                  subtitle: [
                    Formatters.formatDate(expense.spentOn),
                    if (expense.quantity != null)
                      '${Formatters.formatCount(expense.quantity!)} ${expense.unit ?? ''}'.trim(),
                    if (expense.due > 0.004)
                      'expense_due_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(expense.due)}),
                  ].join(' · '),
                  amount: expense.amount,
                  cancelled: expense.isCancelled,
                  onTap: () => _open(ExpenseFormScreen(expenseId: expense.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The kinds of entry as a segmented track under the title; scrolls
/// sideways when there are more than fit.
class _SegmentTabs extends StatelessWidget {
  final List<Tab> tabs;
  final bool scrollable;

  const _SegmentTabs({required this.tabs, required this.scrollable});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spaceXl, AppTheme.spaceXs, AppTheme.spaceXl, AppTheme.spaceSm),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: TabBar(
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.start : null,
          labelPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
          tabs: tabs,
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final Tint tint;
  final String title;
  final String subtitle;
  final double? amount;
  final bool cancelled;
  final VoidCallback? onTap;

  const _EntryRow({
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.cancelled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strike = cancelled ? TextDecoration.lineThrough : null;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
      child: Row(
        children: [
          TintIcon(tint: cancelled ? Tint.neutral : tint, icon: tint.icon),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500, decoration: strike),
                ),
                Text(subtitle, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (cancelled) Text('cancelled'.tr(), style: context.text.labelMedium?.copyWith(color: colors.danger)),
              ],
            ),
          ),
          if (amount != null)
            Text(
              Formatters.formatCurrency(amount!),
              style: context.text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: strike,
                color: cancelled ? colors.muted : null,
              ),
            ),
        ],
      ),
    );
  }
}
