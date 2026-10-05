import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/sectionHeader.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/report.dart';

/// One supervisor's cash: given, handed back, the advances paid from it, and
/// what is in hand. The owner settles it when back at the kiln.
class CashDetailScreen extends StatefulWidget {
  final String holderId;
  final String? holderName;

  const CashDetailScreen({super.key, required this.holderId, this.holderName});

  @override
  State<CashDetailScreen> createState() => _CashDetailScreenState();
}

class _CashDetailScreenState extends State<CashDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().report.fetchCash(widget.holderId));
  }

  Future<void> _settle(CashHolder cash) async {
    final returning = cash.inHand > 0;
    final ok = await showConfirmDialog(
      context,
      title: 'settle_cash'.tr(),
      message: returning
          ? 'settle_cash_return'.tr(namedArgs: {'amount': Formatters.formatCurrency(cash.inHand)})
          : 'settle_cash_repay'.tr(namedArgs: {'amount': Formatters.formatCurrency(-cash.inHand)}),
      confirmText: 'settle_cash'.tr(),
    );
    if (!ok || !mounted) return;
    final report = context.read<Core>().report;
    setState(() => _busy = true);
    final done = await report.settleCash(widget.holderId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) return showErrorToast(report.error ?? 'error_generic'.tr());
    showSuccessToast('cash_settled'.tr());
    report.fetchCash(widget.holderId, refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final state = core.report.cash(widget.holderId);
    scheduleReload(state.needsReload, () => core.report.fetchCash(widget.holderId));
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(widget.holderName ?? 'my_cash'.tr())),
      body: LoadStateBody<CashHolder>(
        state: state,
        onRetry: () => core.report.fetchCash(widget.holderId, refresh: true).then((_) {}),
        builder: (context, cash) => RefreshIndicator(
          onRefresh: () => core.report.fetchCash(widget.holderId, refresh: true).then((_) {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.space2xl),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(cash.inHand < 0 ? 'cash_spent_own'.tr() : 'cash_in_hand'.tr(), style: context.text.bodyLarge),
                    Text(
                      Formatters.formatCurrency(cash.inHand.abs()),
                      style: context.text.headlineMedium?.copyWith(color: cash.inHand < 0 ? colors.danger : colors.ink),
                    ),
                    const Divider(height: AppTheme.space2xl),
                    _Row(label: 'cash_given'.tr(), amount: cash.given),
                    _Row(label: 'advances_paid'.tr(), amount: cash.advancesPaid),
                    _Row(label: 'cash_returned'.tr(), amount: cash.returned),
                  ],
                ),
              ),
              if (core.can(MemberRole.munim) && cash.inHand.abs() >= 0.01) ...[
                const SizedBox(height: AppTheme.spaceMd),
                AppButton(text: 'settle_cash'.tr(), icon: Icons.handshake_rounded, isLoading: _busy, onPressed: () => _settle(cash)),
              ],
              SectionHeader(title: 'cash_lines'.tr(), padding: const EdgeInsets.only(top: AppTheme.spaceLg)),
              if (cash.lines.isEmpty) Text('no_lines_yet'.tr(), style: context.text.bodyMedium),
              if (cash.lines.isNotEmpty)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final line in cash.lines)
                        ListTile(
                          title: Text(
                            line.lineKind == 'advance'
                                ? 'advance_to'.tr(namedArgs: {'name': line.workerName ?? ''})
                                : line.kind == 'given'
                                ? 'cash_given'.tr()
                                : 'cash_returned'.tr(),
                          ),
                          subtitle: Text([Formatters.formatDate(line.date), if (line.note != null) line.note!].join(' · ')),
                          trailing: Text(
                            '${line.isIn ? '+' : '−'}${Formatters.formatCurrency(line.amount)}',
                            style: context.text.titleSmall?.copyWith(color: line.isIn ? colors.success : colors.danger),
                          ),
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

class _Row extends StatelessWidget {
  final String label;
  final double amount;

  const _Row({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyLarge)),
          Text(Formatters.formatCurrency(amount), style: context.text.titleSmall),
        ],
      ),
    );
  }
}
