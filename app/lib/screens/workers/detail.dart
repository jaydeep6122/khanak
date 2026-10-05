import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/balanceText.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/sectionHeader.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/core/modules/workerModule.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/whatsapp.dart';
import 'package:khanak/screens/entries/brickCountForm.dart';
import 'package:khanak/screens/entries/unloadingForm.dart';
import 'package:khanak/screens/entries/workEntryForm.dart';
import 'package:khanak/screens/workers/form.dart';
import 'package:khanak/screens/workers/transactionForm.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// One worker's account: what they earned, what they were paid, and what is
/// left. From here the owner gives an advance, settles up, adds day work and
/// sends the worker their own link.
class WorkerDetailScreen extends StatefulWidget {
  final String workerId;

  const WorkerDetailScreen({super.key, required this.workerId});

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    final module = context.read<Core>().worker;
    await Future.wait([
      module.fetchWorker(widget.workerId, refresh: refresh),
      module.fetchLedger(widget.workerId, refresh: refresh),
    ]);
  }

  Future<void> _push(Widget screen) async {
    final changed = await Navigator.of(context).push(getPageRoute(screen));
    if (changed != null && mounted) _load(refresh: true);
  }

  Future<void> _sendLink(Worker worker) async {
    final module = context.read<Core>().worker;
    final share = await module.share(worker.id);
    if (share == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    if (!share.enabled) return showErrorToast('link_is_off'.tr());
    final message = 'link_message'.tr(namedArgs: {'name': worker.name, 'url': share.url});
    if (whatsAppNumber(worker.phone) != null) {
      await openWhatsApp(worker.phone, message);
    } else {
      await SharePlus.instance.share(ShareParams(text: message));
    }
  }

  Future<void> _menu(String action, Worker worker) async {
    final core = context.read<Core>();
    final module = core.worker;
    switch (action) {
      case 'edit':
        await _push(WorkerFormScreen(worker: worker));
      case 'recovery':
        await _push(TransactionFormScreen(worker: worker, kind: TxnKind.recovery));
      case 'writeoff':
        await _push(TransactionFormScreen(worker: worker, kind: TxnKind.writeoff));
      case 'new_link':
        final ok = await showConfirmDialog(
          context,
          title: 'new_link_title'.tr(),
          message: 'new_link_message'.tr(),
          confirmText: 'new_link'.tr(),
        );
        if (!ok) return;
        final share = await module.regenerateShare(worker.id);
        if (share == null) return showErrorToast(module.error ?? 'error_generic'.tr());
        showSuccessToast('new_link_done'.tr());
      case 'link_off':
      case 'link_on':
        final share = await module.setShareEnabled(worker.id, action == 'link_on');
        if (share == null) return showErrorToast(module.error ?? 'error_generic'.tr());
        showSuccessToast(share.enabled ? 'link_on_done'.tr() : 'link_off_done'.tr());
        _load(refresh: true);
      case 'left':
        final ok = await showConfirmDialog(
          context,
          title: 'mark_left_title'.tr(),
          message: 'mark_left_message'.tr(),
          confirmText: 'mark_left'.tr(),
        );
        if (!ok) return;
        if (!await module.markLeft(worker.id, apiDate(DateTime.now()))) {
          return showErrorToast(module.error ?? 'error_generic'.tr());
        }
        _load(refresh: true);
      case 'returned':
        if (!await module.markReturned(worker.id)) return showErrorToast(module.error ?? 'error_generic'.tr());
        _load(refresh: true);
    }
  }

  Future<void> _openLine(LedgerLine line, Worker worker) async {
    final core = context.read<Core>();
    // A supervisor reading their own account only looks; the entries behind
    // it were mostly made by others.
    if (core.isSupervisor) return;
    if (line.brickCountId != null) {
      return _push(BrickCountFormScreen(countId: line.brickCountId));
    }
    if (line.kilnUnloadingId != null) {
      return _push(UnloadingFormScreen(unloadingId: line.kilnUnloadingId));
    }
    if (line.isWork && line.source == 'manual' && core.can(MemberRole.munim)) {
      return _push(
        WorkEntryFormScreen(
          entry: WorkEntry(
            id: line.entryId,
            workerId: worker.id,
            workerName: worker.name,
            workTypeId: line.workTypeId ?? '',
            workTypeCode: line.workTypeCode,
            workTypeName: line.workTypeName ?? '',
            entryDate: line.date,
            quantity: line.quantity,
            rate: line.rate,
            amount: line.credit,
            source: 'manual',
            note: line.note,
          ),
        ),
      );
    }
    if (!line.isWork) {
      final reason = await showReasonDialog(
        context,
        title: 'cancel_txn_title'.tr(namedArgs: {'kind': line.title}),
        message: 'cancel_txn_message'.tr(namedArgs: {'amount': Formatters.formatCurrency(line.debit + line.credit)}),
        confirmText: 'cancel_entry'.tr(),
      );
      if (reason == null || !mounted) return;
      final module = core.worker;
      if (!await module.cancelTransaction(line.entryId, reason: reason.isEmpty ? null : reason)) {
        return showErrorToast(module.error ?? 'error_generic'.tr());
      }
      showSuccessToast('entry_cancelled'.tr());
      _load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final module = core.worker;
    final detail = module.detail(widget.workerId);
    final account = module.account(widget.workerId);
    scheduleReload(detail.needsReload || account.lines.needsReload, () => _load(refresh: true));

    return LoadStateBody<Worker>(
      state: detail,
      onRetry: () => _load(refresh: true),
      builder: (context, worker) {
        final manager = core.can(MemberRole.munim);
        final isOwner = core.can(MemberRole.owner);
        final colors = context.colors;

        return Scaffold(
          appBar: AppBar(
            title: Text(worker.name),
            actions: [
              if (manager)
                PopupMenuButton<String>(
                  onSelected: (action) => _menu(action, worker),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('worker_edit'.tr())),
                    PopupMenuItem(value: 'recovery', child: Text('txn_recovery'.tr())),
                    if (isOwner) PopupMenuItem(value: 'writeoff', child: Text('txn_writeoff'.tr())),
                    PopupMenuItem(value: 'new_link', child: Text('new_link'.tr())),
                    PopupMenuItem(
                      value: worker.shareEnabled ? 'link_off' : 'link_on',
                      child: Text(worker.shareEnabled ? 'link_off'.tr() : 'link_on'.tr()),
                    ),
                    PopupMenuItem(
                      value: worker.isActive ? 'left' : 'returned',
                      child: Text(worker.isActive ? 'mark_left'.tr() : 'mark_returned'.tr()),
                    ),
                  ],
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.space2xl),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          InitialBadge(letter: worker.initial, size: 52, muted: !worker.isActive),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(worker.displayName, style: context.text.titleMedium),
                                if (!worker.isActive && worker.leftOn != null)
                                  Text(
                                    'left_on'.tr(namedArgs: {'date': Formatters.formatDate(worker.leftOn!)}),
                                    style: context.text.bodySmall?.copyWith(color: colors.warning),
                                  ),
                                Text(
                                  [
                                    worker.mainWork.displayName,
                                    if (worker.rate != null)
                                      'own_rate_line'.tr(namedArgs: {
                                        'rate': Formatters.formatCurrency(worker.rate!),
                                        'unit': worker.mainWork == MainWork.molder
                                            ? 'pay_unit_per_1000'.tr()
                                            : 'pay_unit_per_day'.tr(),
                                      }),
                                  ].join(' · '),
                                  style: context.text.bodySmall,
                                ),
                                if (worker.isSalaried)
                                  Text(
                                    'salary_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(worker.monthlySalary!)}),
                                    style: context.text.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          if (worker.phone != null)
                            IconButton(
                              tooltip: 'call'.tr(),
                              icon: Icon(Icons.call_rounded, color: colors.primary),
                              onPressed: () => launchUrl(Uri.parse('tel:${worker.phone}')),
                            ),
                        ],
                      ),
                      const Divider(height: AppTheme.space2xl),
                      Row(
                        children: [
                          Expanded(child: Text('balance'.tr(), style: context.text.titleMedium)),
                          BalanceText(balance: worker.balance ?? account.balance, large: true),
                        ],
                      ),
                    ],
                  ),
                ),
                if (manager) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.currency_rupee_rounded,
                        label: 'action_advance'.tr(),
                        onTap: () => _push(TransactionFormScreen(worker: worker, kind: TxnKind.advance)),
                      ),
                      _QuickAction(
                        icon: Icons.task_alt_rounded,
                        label: 'txn_settlement'.tr(),
                        onTap: () => _push(TransactionFormScreen(worker: worker, kind: TxnKind.settlement)),
                      ),
                      _QuickAction(
                        icon: Icons.handyman_rounded,
                        label: 'action_other_work'.tr(),
                        onTap: () => _push(WorkEntryFormScreen(worker: worker)),
                      ),
                      _QuickAction(
                        icon: Icons.send_rounded,
                        label: 'send_link'.tr(),
                        onTap: () => _sendLink(worker),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(child: _Total(label: 'earned'.tr(), amount: account.totals.earned)),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(child: _Total(label: 'advances_given'.tr(), amount: account.totals.advances)),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(child: _Total(label: 'settled'.tr(), amount: account.totals.settled)),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                SectionHeader(title: 'account_lines'.tr()),
                _Lines(account: account, worker: worker, onTap: (line) => _openLine(line, worker), onMore: () => module.fetchLedger(worker.id, more: true), onRetry: () => _load(refresh: true)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
        child: Material(
          color: colors.primarySoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd, horizontal: AppTheme.spaceXs),
              child: Column(
                children: [
                  Icon(icon, color: colors.primary, size: 26),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: context.text.labelMedium?.copyWith(color: colors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final double amount;

  const _Total({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Formatters.formatCurrency(amount), style: context.text.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  final WorkerAccount account;
  final Worker worker;
  final ValueChanged<LedgerLine> onTap;
  final VoidCallback onMore;
  final Future<void> Function() onRetry;

  const _Lines({required this.account, required this.worker, required this.onTap, required this.onMore, required this.onRetry});

  /// "22,000 × ₹550 / 1000", "6 days × ₹400", "share of ₹2,200 (2 workers)".
  String? _detail(LedgerLine line) {
    if (!line.isWork) return line.note;
    final parts = <String>[];
    final unit = line.payUnit;
    if (line.quantity != null && line.rate != null && unit != null && unit != PayUnit.perMonth) {
      parts.add(
        'line_qty_rate'.tr(
          namedArgs: {
            'quantity': Formatters.formatNumber(line.quantity!),
            'rate': Formatters.formatCurrency(line.rate!),
            'unit': 'pay_unit_${unit.value}'.tr(),
          },
        ),
      );
    }
    if (line.groupSize != null && line.groupSize! > 1) {
      parts.add(
        'line_share'.tr(
          namedArgs: {'total': Formatters.formatCurrency(line.groupTotal ?? 0), 'count': '${line.groupSize}'},
        ),
      );
    }
    if (line.note != null) parts.add(line.note!);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final state = account.lines;
    final colors = context.colors;
    if (state.isLoading && state.items.isEmpty) return const SizedBox(height: 200, child: LoadingIndicator());
    if (state.error != null && state.items.isEmpty) {
      return SizedBox(height: 260, child: AppErrorWidget(errorMessage: state.error!, onRetry: onRetry));
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.space2xl),
        child: Text('no_lines_yet'.tr(), textAlign: TextAlign.center, style: context.text.bodyMedium),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final line in state.items) ...[
            ListTile(
              onTap: () => onTap(line),
              title: Text(line.title),
              subtitle: Text(
                [Formatters.formatDate(line.date), ?_detail(line)].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${line.amount >= 0 ? '+' : '−'}${Formatters.formatCurrency(line.amount.abs())}',
                style: context.text.titleSmall?.copyWith(color: line.amount >= 0 ? colors.success : colors.danger),
              ),
            ),
            if (line != state.items.last) const Divider(indent: AppTheme.spaceLg),
          ],
          if (state.data.hasMore)
            TextButton(
              onPressed: state.isLoadingMore ? null : onMore,
              child: Text(state.isLoadingMore ? 'loading'.tr() : 'load_more'.tr()),
            ),
        ],
      ),
    );
  }
}
