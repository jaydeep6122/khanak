import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/pagedList.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/entries/brickCountForm.dart';
import 'package:khanak/screens/entries/unloadingForm.dart';
import 'package:khanak/screens/entries/workEntryForm.dart';
import 'package:khanak/types/work.dart';

/// Every entry, newest first: brick counts, unloadings and work typed in by
/// hand. A supervisor sees only their own counts and unloadings.
class EntriesTab extends StatefulWidget {
  const EntriesTab({super.key});

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
      if (!core.isSupervisor) core.entry.fetchWorkEntries();
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
    if (!supervisor) scheduleReload(entry.workEntries.needsReload, () => entry.fetchWorkEntries());

    return DefaultTabController(
      length: supervisor ? 2 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('tab_entries'.tr()),
          bottom: TabBar(
            tabs: [
              Tab(text: 'tab_counts'.tr()),
              Tab(text: 'tab_unloadings'.tr()),
              if (!supervisor) Tab(text: 'tab_other_work'.tr()),
            ],
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
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              emptyState: EmptyState(icon: Icons.grid_view_rounded, title: 'no_counts_yet'.tr()),
              itemBuilder: (context, count) => _EntryRow(
                icon: Icons.grid_view_rounded,
                title: '${Formatters.formatNumber(count.quantity.toDouble())} · ${count.reason.displayName}',
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
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              emptyState: EmptyState(icon: Icons.local_fire_department_rounded, title: 'no_unloadings_yet'.tr()),
              itemBuilder: (context, unloading) => _EntryRow(
                icon: Icons.local_fire_department_rounded,
                title: 'unloading_row'.tr(namedArgs: {'bricks': Formatters.formatNumber(unloading.quantity.toDouble())}),
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
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                emptyState: EmptyState(icon: Icons.handyman_rounded, title: 'no_work_yet'.tr()),
                itemBuilder: (context, work) => _EntryRow(
                  icon: Icons.handyman_rounded,
                  title: '${work.workerName} · ${work.label}',
                  subtitle: [
                    Formatters.formatDate(work.entryDate),
                    if (work.quantity != null) Formatters.formatNumber(work.quantity!),
                    if (work.note != null) work.note!,
                  ].join(' · '),
                  amount: work.amount,
                  cancelled: work.isCancelled,
                  onTap: core.can(MemberRole.munim) ? () => _open(WorkEntryFormScreen(entry: work)) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double? amount;
  final bool cancelled;
  final VoidCallback? onTap;

  const _EntryRow({
    required this.icon,
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
          Icon(icon, color: cancelled ? colors.muted : colors.primary),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall?.copyWith(decoration: strike)),
                Text(subtitle, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (cancelled)
                  Text('cancelled'.tr(), style: context.text.labelMedium?.copyWith(color: colors.danger)),
              ],
            ),
          ),
          if (amount != null)
            Text(
              Formatters.formatCurrency(amount!),
              style: context.text.titleSmall?.copyWith(decoration: strike, color: cancelled ? colors.muted : null),
            ),
        ],
      ),
    );
  }
}
