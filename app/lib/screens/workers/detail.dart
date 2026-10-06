import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/components/tint.dart';
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

/// Which lines of the account to show.
enum _Filter { all, work, money }

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  _Filter _filter = _Filter.all;

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
      case 'other_work':
        await _push(WorkEntryFormScreen(worker: worker));
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

    return Scaffold(
      appBar: AppBar(),
      body: LoadStateBody<Worker>(
        state: detail,
        onRetry: () => _load(refresh: true),
        builder: (context, worker) {
          final manager = core.can(MemberRole.munim);
          final isOwner = core.can(MemberRole.owner);
          final colors = context.colors;
          final lines = account.lines.items.where(
            (line) => switch (_filter) {
              _Filter.all => true,
              _Filter.work => line.isWork,
              _Filter.money => !line.isWork,
            },
          );

          return RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceXl, 0, AppTheme.spaceXl, AppTheme.space3xl),
              children: [
                Row(
                  children: [
                    InitialBadge(letter: worker.initial, size: 60, muted: !worker.isActive),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker.name, style: context.text.headlineMedium),
                          Text(
                            [
                              worker.mainWork.displayName,
                              ?worker.village,
                              if (worker.rate != null && worker.rateUnit != null)
                                '${Formatters.formatCurrency(worker.rate!)} ${'rate_unit_${worker.rateUnit!.value}'.tr()}',
                              if (worker.isSalaried)
                                'salary_line'.tr(
                                  namedArgs: {'amount': Formatters.formatCurrency(worker.monthlySalary!)},
                                ),
                            ].join(' · '),
                            style: context.text.bodyMedium?.copyWith(color: colors.muted, fontSize: 14),
                          ),
                          if (!worker.isActive && worker.leftOn != null)
                            Text(
                              'left_on'.tr(namedArgs: {'date': Formatters.formatDate(worker.leftOn!)}),
                              style: context.text.bodySmall?.copyWith(color: colors.warning),
                            ),
                        ],
                      ),
                    ),
                    if (worker.phone != null)
                      CircleButton(
                        icon: Icons.call_rounded,
                        tooltip: 'call'.tr(),
                        onTap: () => launchUrl(Uri.parse('tel:${worker.phone}')),
                      ),
                    if (manager)
                      Padding(
                        padding: const EdgeInsets.only(left: AppTheme.spaceSm),
                        child: PopupMenuButton<String>(
                          onSelected: (action) => _menu(action, worker),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text('worker_edit'.tr())),
                            PopupMenuItem(value: 'other_work', child: Text('action_other_work'.tr())),
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
                          child: const CircleButton(icon: Icons.more_horiz_rounded),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXl),
                _BalanceCard(
                  balance: worker.balance ?? account.balance,
                  account: account,
                  actions: manager
                      ? [
                          _CardAction(
                            label: 'advance'.tr(),
                            background: colors.ink,
                            foreground: colors.onInk,
                            onTap: () => _push(TransactionFormScreen(worker: worker, kind: TxnKind.advance)),
                          ),
                          _CardAction(
                            label: 'txn_settlement'.tr(),
                            background: colors.background,
                            foreground: colors.ink,
                            onTap: () => _push(TransactionFormScreen(worker: worker, kind: TxnKind.settlement)),
                          ),
                          _CardAction(
                            label: 'link'.tr(),
                            icon: Icons.send_rounded,
                            background: colors.successSoft,
                            foreground: colors.success,
                            onTap: () => _sendLink(worker),
                          ),
                        ]
                      : const [],
                ),
                const SizedBox(height: AppTheme.spaceXl),
                SegmentedControl<_Filter>(
                  options: _Filter.values,
                  selected: _filter,
                  label: (f) => switch (f) {
                    _Filter.all => 'all'.tr(),
                    _Filter.work => 'filter_work'.tr(),
                    _Filter.money => 'filter_money'.tr(),
                  },
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                _Lines(
                  account: account,
                  lines: lines.toList(),
                  onTap: (line) => _openLine(line, worker),
                  onMore: () => module.fetchLedger(worker.id, more: true),
                  onRetry: () => _load(refresh: true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardAction {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _CardAction({
    required this.label,
    this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
}

/// What is left, large, with what was earned, given and settled below and
/// the everyday buttons.
class _BalanceCard extends StatelessWidget {
  final double balance;
  final WorkerAccount account;
  final List<_CardAction> actions;

  const _BalanceCard({required this.balance, required this.account, required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = balance > 0.004
        ? ('to_pay'.tr(), colors.danger)
        : balance < -0.004
        ? ('to_get'.tr(), colors.success)
        : ('settled_up'.tr(), colors.muted);

    Widget total(String label, double amount) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(fontSize: 12),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Formatters.formatCurrency(amount), style: context.text.titleSmall),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: context.text.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.formatCurrency(balance.abs()),
              style: context.text.displaySmall?.copyWith(fontSize: 40, color: color),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Row(
            children: [
              total('earned'.tr(), account.totals.earned),
              const SizedBox(width: AppTheme.spaceSm),
              total('advances_given'.tr(), account.totals.advances),
              const SizedBox(width: AppTheme.spaceSm),
              total('settled'.tr(), account.totals.settled),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceLg),
            Row(
              spacing: AppTheme.spaceSm,
              children: [
                for (final action in actions)
                  Expanded(
                    child: Material(
                      color: action.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        onTap: action.onTap,
                        child: SizedBox(
                          height: 46,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (action.icon != null) ...[
                                Icon(action.icon, size: 17, color: action.foreground),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  action.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelLarge?.copyWith(color: action.foreground, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  final WorkerAccount account;
  final List<LedgerLine> lines;
  final ValueChanged<LedgerLine> onTap;
  final VoidCallback onMore;
  final Future<void> Function() onRetry;

  const _Lines({
    required this.account,
    required this.lines,
    required this.onTap,
    required this.onMore,
    required this.onRetry,
  });

  /// "22,000 × ₹550 / 1000", "6 days × ₹400", "share of ₹2,200 (2 workers)".
  String? _detail(LedgerLine line) {
    if (!line.isWork) return line.note;
    final parts = <String>[];
    final unit = line.payUnit;
    if (line.quantity != null && line.rate != null && unit != null && unit != PayUnit.perMonth) {
      parts.add(
        'line_qty_rate'.tr(
          namedArgs: {
            'quantity': Formatters.formatCount(line.quantity!),
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

  Tint _tint(LedgerLine line) {
    if (line.brickCountId != null) return Tint.bricks;
    if (line.kilnUnloadingId != null) return Tint.fire;
    if (line.source == 'sale') return Tint.truck;
    if (line.isWork) return Tint.work;
    return line.entryKind == 'advance' ? Tint.money : Tint.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final state = account.lines;
    final colors = context.colors;
    if (state.isLoading && state.items.isEmpty) return const SizedBox(height: 200, child: LoadingIndicator());
    if (state.error != null && state.items.isEmpty) {
      return SizedBox(
        height: 260,
        child: AppErrorWidget(errorMessage: state.error!, onRetry: onRetry),
      );
    }
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.space2xl),
        child: Text('no_lines_yet'.tr(), textAlign: TextAlign.center, style: context.text.bodyMedium),
      );
    }

    // One card per day, newest first, with the day above it.
    final days = <DateTime, List<LedgerLine>>{};
    for (final line in lines) {
      days.putIfAbsent(DateTime(line.date.year, line.date.month, line.date.day), () => []).add(line);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: day, value: dayLines) in days.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceLg),
            child: GroupedSection(
              caption: Formatters.formatRelativeDate(day, today: 'today'.tr(), yesterday: 'yesterday'.tr()),
              children: [
                for (final line in dayLines)
                  GroupedRow(
                    onTap: () => onTap(line),
                    chevron: false,
                    leading: TintIcon(tint: _tint(line)),
                    title: line.title,
                    subtitle: _detail(line),
                    value: '${line.amount >= 0 ? '+' : '−'}${Formatters.formatCurrency(line.amount.abs())}',
                    valueColor: line.amount >= 0 ? colors.success : colors.danger,
                  ),
              ],
            ),
          ),
        if (state.data.hasMore)
          TextButton(
            onPressed: state.isLoadingMore ? null : onMore,
            child: Text(state.isLoadingMore ? 'loading'.tr() : 'load_more'.tr()),
          ),
      ],
    );
  }
}
