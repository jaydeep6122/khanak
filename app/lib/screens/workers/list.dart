import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/balanceText.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/searchBar.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text('tab_workers'.tr())),
      floatingActionButton: core.can(MemberRole.munim)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(getPageRoute(const WorkerFormScreen())),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('worker_new'.tr()),
            )
          : null,
      body: LoadStateBody<List<Worker>>(
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

          return RefreshIndicator(
            onRefresh: () => module.fetchWorkers(refresh: true).then((_) {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.fabClearance),
              children: [
                AppSearchBar(hintText: 'search_worker'.tr(), onChanged: (v) => setState(() => _search = v)),
                const SizedBox(height: AppTheme.spaceSm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final work in <MainWork?>[null, ...MainWork.values])
                        Padding(
                          padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                          child: ChoiceChip(
                            label: Text(work?.displayName ?? 'all'.tr()),
                            selected: _work == work,
                            onSelected: (_) => setState(() => _work = work),
                          ),
                        ),
                    ],
                  ),
                ),
                if (left > 0) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  Wrap(
                    spacing: AppTheme.spaceSm,
                    children: [
                      ChoiceChip(
                        label: Text('workers_working'.tr()),
                        selected: !_showLeft,
                        onSelected: (_) => setState(() => _showLeft = false),
                      ),
                      ChoiceChip(
                        label: Text('workers_left'.tr(namedArgs: {'count': '$left'})),
                        selected: _showLeft,
                        onSelected: (_) => setState(() => _showLeft = true),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.spaceMd),
                if (workers.isEmpty)
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      icon: Icons.groups_rounded,
                      title: all.isEmpty ? 'no_workers_title'.tr() : 'no_workers_found'.tr(),
                      description: all.isEmpty ? 'no_workers_help'.tr() : null,
                    ),
                  ),
                for (final worker in workers) ...[
                  AppCard(
                    onTap: () => _open(core, worker),
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
                    child: Row(
                      children: [
                        InitialBadge(letter: worker.initial, muted: !worker.isActive),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(worker.name, style: context.text.titleMedium),
                              Text(
                                [
                                  worker.mainWork.displayName,
                                  if (worker.displayName != worker.name) worker.displayName.substring(worker.name.length + 3),
                                ].join(' · '),
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (worker.balance != null) BalanceText(balance: worker.balance!),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
