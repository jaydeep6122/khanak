import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/balanceText.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/searchBar.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/workers/detail.dart';
import 'package:khanak/screens/workers/form.dart';
import 'package:khanak/screens/workers/transactionForm.dart';
import 'package:khanak/types/worker.dart';

/// Every worker with what they are owed or owe. A supervisor sees names
/// only: tapping one gives an advance.
class WorkersTab extends StatefulWidget {
  const WorkersTab({super.key});

  @override
  State<WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<WorkersTab> {
  String _search = '';
  bool _showLeft = false;

  /// Null shows every kind of worker.
  MainWork? _work;

  void _open(Core core, Worker worker) {
    final Widget screen = core.isSupervisor && worker.id != core.openFactory?.workerId
        ? TransactionFormScreen(worker: worker, kind: TxnKind.advance)
        : WorkerDetailScreen(workerId: worker.id);
    Navigator.of(context).push(getPageRoute(screen));
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final module = core.worker;
    scheduleReload(module.workers.needsReload, () => module.fetchWorkers());

    final canAdd = core.can(MemberRole.munim);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LoadStateBody<List<Worker>>(
          state: module.workers,
          onRetry: () => module.fetchWorkers(refresh: true).then((_) {}),
          builder: (context, all) {
            final query = _search.toLowerCase();
            final left = all.where((w) => !w.isActive).length;
            final workers = all
                .where((w) => w.isActive != _showLeft)
                .where((w) => _work == null || w.mainWork == _work)
                .where((w) => query.isEmpty || w.displayName.toLowerCase().contains(query))
                .toList();
            // Only the kinds of work someone here does.
            final works = MainWork.values.where((m) => all.any((w) => w.mainWork == m)).toList();

            return RefreshIndicator(
              onRefresh: () => module.fetchWorkers(refresh: true).then((_) {}),
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppTheme.fabClearance),
                children: [
                  LargeTitle(
                    title: 'tab_workers'.tr(),
                    actions: [
                      if (canAdd)
                        CircleButton(
                          icon: Icons.add_rounded,
                          filled: true,
                          tooltip: 'worker_new'.tr(),
                          onTap: () => Navigator.of(context).push(getPageRoute(const WorkerFormScreen())),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSearchBar(hintText: 'search_worker'.tr(), onChanged: (v) => setState(() => _search = v)),
                        if (works.length > 1) ...[
                          const SizedBox(height: AppTheme.spaceMd),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: Row(
                              children: [
                                for (final work in <MainWork?>[null, ...works])
                                  Padding(
                                    padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                                    child: QuickChip(
                                      text: work?.displayName ?? 'all'.tr(),
                                      selected: _work == work,
                                      onTap: () => setState(() => _work = work),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (left > 0) ...[
                          const SizedBox(height: AppTheme.spaceMd),
                          SegmentedControl<bool>(
                            options: const [false, true],
                            selected: _showLeft,
                            label: (showLeft) =>
                                showLeft ? 'workers_left'.tr(namedArgs: {'count': '$left'}) : 'workers_working'.tr(),
                            onChanged: (v) => setState(() => _showLeft = v),
                          ),
                        ],
                        const SizedBox(height: AppTheme.spaceLg),
                        if (workers.isEmpty)
                          SizedBox(
                            height: 360,
                            child: EmptyState(
                              icon: Icons.groups_rounded,
                              title: all.isEmpty ? 'no_workers_title'.tr() : 'no_workers_found'.tr(),
                              description: all.isEmpty ? 'no_workers_help'.tr() : null,
                            ),
                          )
                        else
                          GroupedSection(
                            caption: 'workers_count'.tr(namedArgs: {'count': '${workers.length}'}),
                            children: [
                              for (final worker in workers)
                                GroupedRow(
                                  onTap: () => _open(core, worker),
                                  chevron: false,
                                  leading: InitialBadge(letter: worker.initial, muted: !worker.isActive, size: 40),
                                  title: worker.name,
                                  subtitle: [
                                    worker.mainWork.displayName,
                                    if (worker.displayName != worker.name)
                                      worker.displayName.substring(worker.name.length + 3),
                                  ].join(' · '),
                                  trailing: worker.balance == null ? null : BalanceText(balance: worker.balance!),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
