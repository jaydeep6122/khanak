import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/trade/parties.dart';
import 'package:khanak/types/trade.dart';

/// Money with a customer or supplier after the sale or purchase: received
/// from a customer, paid to a supplier, or a customer's debt written off.
/// With [paymentId] it edits that payment.
class PaymentFormScreen extends StatefulWidget {
  final Party party;

  /// received, paid or writeoff.
  final String kind;
  final String? paymentId;

  const PaymentFormScreen({super.key, required this.party, required this.kind, this.paymentId});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    // What is outstanding is the likely amount.
    text: widget.party.balance.abs() >= 0.005 ? Formatters.formatDouble(widget.party.balance.abs()) : '',
  );
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String _mode = 'cash';
  bool _busy = false;
  late bool _loading = widget.paymentId != null;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    if (widget.paymentId != null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final trade = context.read<Core>().trade;
    final payment = await trade.fetchPayment(widget.paymentId!);
    if (!mounted) return;
    if (payment == null) {
      showErrorToast(trade.error ?? 'error_generic'.tr());
      return Navigator.of(context).pop();
    }
    setState(() {
      _amountController.text = Formatters.formatDouble(payment.amount);
      _noteController.text = payment.note ?? '';
      _date = payment.paidOn;
      _mode = payment.mode;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final trade = context.read<Core>().trade;
    setState(() => _busy = true);
    final balance = await trade.savePayment(widget.party.id, {
      // The kind of a payment is fixed once it is made.
      if (widget.paymentId == null) 'kind': widget.kind,
      'paid_on': apiDate(_date),
      'amount': apiAmount(_amountController.text),
      if (widget.kind != 'writeoff') 'mode': _mode,
      'note': _noteController.text.trim(),
    }, paymentId: widget.paymentId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (balance == null) return showErrorToast(trade.error ?? 'error_generic'.tr());
    showSuccessToast('payment_saved'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      'received' => 'payment_received'.tr(),
      'paid' => 'payment_paid'.tr(),
      _ => 'writeoff'.tr(),
    };

    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const LoadingIndicator());
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    final party = widget.party;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        actions: [DatePill(value: _date, onChanged: (d) => setState(() => _date = d))],
      ),
      bottomNavigationBar: SaveBar(
        label: 'save'.tr(),
        trailing: amount > 0 ? Formatters.formatCurrency(amount) : null,
        isLoading: _busy,
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceXl,
            AppTheme.spaceSm,
            AppTheme.spaceXl,
            AppTheme.fabClearance,
          ),
          children: [
            GroupedSection(
              children: [
                GroupedRow(
                  leading: InitialBadge(letter: party.name.isEmpty ? '?' : party.name[0].toUpperCase(), size: 40),
                  title: party.name,
                  subtitle: party.phone,
                  trailing: PartyBalance(balance: party.balance),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space3xl),
            BigNumberField(
              controller: _amountController,
              label: 'amount'.tr(),
              prefix: '₹',
              decimal: true,
              autofocus: widget.paymentId == null,
              validator: (v) => Validators.amount(v, fieldLabel: 'amount'.tr(), allowZero: false),
            ),
            if (widget.kind == 'writeoff') ...[
              const SizedBox(height: AppTheme.spaceLg),
              Text('writeoff_help'.tr(), textAlign: TextAlign.center, style: context.text.bodySmall),
            ],
            if (widget.kind != 'writeoff') ...[
              const SizedBox(height: AppTheme.space2xl),
              GroupCaption('payment_mode'.tr()),
              SegmentedControl<String>(
                options: const ['cash', 'bank', 'upi'],
                selected: _mode,
                label: (m) => 'mode_$m'.tr(),
                onChanged: (m) => setState(() => _mode = m),
              ),
            ],
            const SizedBox(height: AppTheme.space2xl),
            NoteCard(controller: _noteController, hint: 'note_optional'.tr()),
          ],
        ),
      ),
    );
  }
}
