import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/worker.dart';

/// Money between the factory and one worker: an advance (upad), a
/// settlement (chukti), money the worker paid back, or a write-off. The
/// worker's balance is shown first, so it is clear how much to give.
class TransactionFormScreen extends StatefulWidget {
  final Worker worker;
  final TxnKind kind;

  const TransactionFormScreen({super.key, required this.worker, required this.kind});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  double? _balance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBalance());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final balance = await context.read<Core>().worker.fetchBalance(widget.worker.id);
    if (!mounted) return;
    setState(() => _balance = balance);
    // Paying off or forgiving: the whole balance is the likely amount.
    if (balance != null && _amountController.text.isEmpty) {
      final suggested = switch (widget.kind) {
        TxnKind.settlement when balance > 0 => balance,
        TxnKind.writeoff || TxnKind.recovery when balance < 0 => -balance,
        _ => null,
      };
      if (suggested != null) _amountController.text = Formatters.formatDouble(suggested);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final module = context.read<Core>().worker;
    setState(() => _busy = true);
    final balance = await module.addTransaction(widget.worker.id, {
      'kind': widget.kind.value,
      'txn_date': apiDate(_date),
      'amount': apiAmount(_amountController.text),
      'note': _noteController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (balance == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast(
      'txn_saved'.tr(namedArgs: {'kind': widget.kind.displayName, 'balance': _balanceText(balance)}),
    );
    Navigator.of(context).pop(true);
  }

  String _balanceText(double balance) => balance >= 0
      ? 'balance_to_pay'.tr(namedArgs: {'amount': Formatters.formatCurrency(balance)})
      : 'balance_to_get'.tr(namedArgs: {'amount': Formatters.formatCurrency(-balance)});

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final colors = context.colors;
    final balance = _balance;

    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.displayName)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          children: [
            AppCard(
              child: Row(
                children: [
                  InitialBadge(letter: widget.worker.initial, size: 48),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.worker.displayName, style: context.text.titleMedium),
                        const SizedBox(height: AppTheme.spaceXs),
                        if (balance == null)
                          Text('loading'.tr(), style: context.text.bodySmall)
                        else
                          Text(
                            _balanceText(balance),
                            style: context.text.titleSmall?.copyWith(color: balance >= 0 ? colors.danger : colors.success),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text('txn_help_${widget.kind.value}'.tr(), style: context.text.bodyMedium),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _amountController,
              labelText: 'amount'.tr(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter(decimals: 2)],
              prefixText: '₹ ',
              autofocus: widget.kind == TxnKind.advance,
              validator: (v) => Validators.amount(v, fieldLabel: 'amount'.tr(), allowZero: false),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            DateField(label: 'date'.tr(), value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _noteController,
              labelText: 'note_optional'.tr(),
              textCapitalization: TextCapitalization.sentences,
            ),
            if (core.isSupervisor && widget.kind == TxnKind.advance) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Text('advance_from_your_cash'.tr(), style: context.text.bodySmall),
            ],
            const SizedBox(height: AppTheme.space2xl),
            AppButton(text: 'save'.tr(), isLoading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
