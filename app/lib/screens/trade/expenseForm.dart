import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/optionSheet.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/partyPicker.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/trade.dart';

/// Money spent: soil, coal, husk, diesel, truck upkeep or anything else.
/// Paid in full, no supplier is needed; anything left unpaid goes on the
/// supplier's account. Diesel can name the truck, the litres and the
/// odometer, which give the truck's average. With [expenseId] it edits it.
class ExpenseFormScreen extends StatefulWidget {
  final String? expenseId;
  final ExpenseCategory? category;
  final Truck? truck;

  const ExpenseFormScreen({super.key, this.expenseId, this.category, this.truck});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidController = TextEditingController();
  final _litresController = TextEditingController();
  final _odometerController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  late ExpenseCategory? _category = widget.category;
  late Truck? _truck = widget.truck;
  Party? _supplier;
  Expense? _editing;
  bool _paidByHand = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      if (!_paidByHand) _paidController.text = _amountController.text;
      setState(() {});
    });
    _paidController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in [
      _quantityController,
      _unitController,
      _amountController,
      _paidController,
      _litresController,
      _odometerController,
      _noteController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final core = context.read<Core>();
    await core.factory.fetchTrucks();
    if (widget.expenseId != null) {
      final expense = await core.trade.fetchExpense(widget.expenseId!);
      if (expense != null) {
        _editing = expense;
        _date = expense.spentOn;
        _category = expense.category;
        _quantityController.text = expense.quantity == null ? '' : Formatters.formatNumber(expense.quantity!);
        _unitController.text = expense.unit ?? '';
        _paidByHand = true;
        _amountController.text = Formatters.formatDouble(expense.amount);
        _paidController.text = Formatters.formatDouble(expense.paidAmount);
        _supplier = expense.partyId == null
            ? null
            : Party(id: expense.partyId!, kind: 'supplier', name: expense.partyName ?? '', isActive: true);
        _truck = core.factory.trucks.value?.where((t) => t.id == expense.truckId).firstOrNull;
        _litresController.text = expense.litres == null ? '' : Formatters.formatDouble(expense.litres!);
        _odometerController.text = expense.odometer == null ? '' : '${expense.odometer}';
        _noteController.text = expense.note ?? '';
      }
    } else {
      final trucks = (core.factory.trucks.value ?? const <Truck>[]).where((t) => t.isActive).toList();
      if (_truck == null && trucks.length == 1 && (_category?.forTruck ?? false)) _truck = trucks.first;
    }
    if (mounted) setState(() => _loading = false);
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  double get _paid => double.tryParse(_paidController.text) ?? 0;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    final category = _category;
    if (category == null) return showErrorToast('pick_expense_kind_first'.tr());
    if (_paid > _amount + 0.004) return showErrorToast('paid_more_than_amount'.tr());
    if (_amount - _paid > 0.004 && _supplier == null) return showErrorToast('credit_needs_supplier'.tr());
    if (!valid) return;

    final data = {
      'spent_on': apiDate(_date),
      'category': category.value,
      if (category.hasQuantity) ...{
        'quantity': _quantityController.text.trim().isEmpty ? null : _quantityController.text.trim(),
        'unit': _unitController.text.trim(),
      },
      'amount': apiAmount(_amountController.text),
      'paid_amount': apiAmount(_paidController.text) ?? '0',
      'party_id': _supplier?.id,
      'truck_id': category.forTruck ? _truck?.id : null,
      if (category == ExpenseCategory.diesel) ...{
        'litres': apiAmount(_litresController.text),
        'odometer': int.tryParse(_odometerController.text.trim()),
      },
      'note': _noteController.text.trim(),
    };

    final trade = context.read<Core>().trade;
    setState(() => _busy = true);
    final saved = await trade.saveExpense(data, expenseId: widget.expenseId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(trade.error ?? 'error_generic'.tr());
    showSuccessToast('expense_saved'.tr());
    Navigator.of(context).pop(true);
  }

  Future<void> _cancel() async {
    final reason = await showReasonDialog(
      context,
      title: 'cancel_expense_title'.tr(),
      message: 'cancel_expense_message'.tr(),
      confirmText: 'cancel_entry'.tr(),
    );
    if (reason == null || !mounted) return;
    final trade = context.read<Core>().trade;
    final done = await trade.cancelExpense(widget.expenseId!, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    if (done == null) return showErrorToast(trade.error ?? 'error_generic'.tr());
    showSuccessToast('entry_cancelled'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final colors = context.colors;
    final title = widget.expenseId == null ? 'action_expense'.tr() : 'edit_expense'.tr();
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const LoadingIndicator(),
      );
    }

    final category = _category;
    final trucks = (core.factory.trucks.value ?? const <Truck>[]).where((t) => t.isActive).toList();
    final due = _amount - _paid;

    Widget pickIcon(IconData icon) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: colors.primary),
    );

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.expenseId != null && _editing?.isCancelled == false)
            IconButton(
              tooltip: 'cancel_entry'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: _cancel,
            ),
          DatePill(value: _date, onChanged: (d) => setState(() => _date = d)),
        ],
      ),
      bottomNavigationBar: SaveBar(
        label: 'save'.tr(),
        trailing: _amount > 0 ? Formatters.formatCurrency(_amount) : null,
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
            GroupCaption('expense_kind'.tr()),
            ChoiceGrid<ExpenseCategory>(
              options: ExpenseCategory.values,
              selected: category,
              label: (c) => c.displayName,
              icon: (c) => switch (c) {
                ExpenseCategory.soil => Icons.landscape_rounded,
                ExpenseCategory.coal => Icons.whatshot_rounded,
                ExpenseCategory.husk => Icons.grass_rounded,
                ExpenseCategory.diesel => Icons.local_gas_station_rounded,
                ExpenseCategory.truckUpkeep => Icons.build_rounded,
                ExpenseCategory.other => Icons.more_horiz_rounded,
              },
              iconColor: (context, _) => Tint.expense.color(context),
              onSelected: (c) => setState(() {
                _category = c;
                if (c.forTruck && _truck == null && trucks.length == 1) _truck = trucks.first;
              }),
            ),
            const SizedBox(height: AppTheme.space2xl),
            BigNumberField(
              controller: _amountController,
              label: 'amount'.tr(),
              prefix: '₹',
              decimal: true,
              validator: (v) => Validators.amount(v, fieldLabel: 'amount'.tr(), allowZero: false),
            ),
            const SizedBox(height: AppTheme.space2xl),
            if (category != null && category.forTruck) ...[
              GroupedSection(
                children: [
                  GroupedRow(
                    onTap: () async {
                      // Wrapped so "no truck" differs from closing the sheet.
                      final picked = await pickOption<(Truck?,)>(
                        context,
                        title: category == ExpenseCategory.diesel ? 'diesel_for_truck'.tr() : 'truck'.tr(),
                        options: [for (final truck in trucks) (truck,), (null,)],
                        label: (t) => t.$1?.label ?? 'no_truck'.tr(),
                        isSelected: (t) => t.$1?.id == _truck?.id,
                        tint: Tint.truck,
                      );
                      if (picked == null || !mounted) return;
                      setState(() => _truck = picked.$1);
                    },
                    leading: const TintIcon(tint: Tint.truck),
                    label: category == ExpenseCategory.diesel ? 'diesel_for_truck'.tr() : 'truck'.tr(),
                    title: _truck?.label ?? 'no_truck'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),
            ],
            if (category != null && category.hasQuantity) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _quantityController,
                      labelText: 'expense_quantity'.tr(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [DecimalInputFormatter(decimals: 3)],
                      validator: (v) => Validators.quantity(v, isRequired: false),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppTextField(
                      controller: _unitController,
                      labelText: 'expense_unit'.tr(),
                      hintText: 'expense_unit_hint'.tr(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),
            ],
            if (category == ExpenseCategory.diesel) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _litresController,
                      labelText: 'litres'.tr(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [DecimalInputFormatter(decimals: 2)],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppTextField(
                      controller: _odometerController,
                      labelText: 'odometer'.tr(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
                child: Text('diesel_full_tank_help'.tr(), style: context.text.bodySmall),
              ),
              const SizedBox(height: AppTheme.spaceLg),
            ],
            AppTextField(
              controller: _paidController,
              labelText: 'paid_now'.tr(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter(decimals: 2)],
              prefixText: '₹ ',
              onChanged: (_) => _paidByHand = true,
              validator: (v) => Validators.amount(v, fieldLabel: 'paid_now'.tr()),
            ),
            if (due > 0.004)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(
                    text: 'expense_due_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(due)}),
                    color: colors.warning,
                    background: colors.warningSoft,
                  ),
                ),
              ),
            const SizedBox(height: AppTheme.spaceLg),
            GroupedSection(
              children: [
                GroupedRow(
                  onTap: () async {
                    final supplier = await pickParty(context, kind: 'supplier', title: 'pick_supplier'.tr());
                    if (supplier != null) setState(() => _supplier = supplier);
                  },
                  leading: _supplier == null
                      ? pickIcon(Icons.storefront_rounded)
                      : InitialBadge(
                          letter: _supplier!.name.isEmpty ? '?' : _supplier!.name[0].toUpperCase(),
                          size: 36,
                        ),
                  label: due > 0.004 ? 'supplier_required'.tr() : 'supplier_optional'.tr(),
                  title: _supplier?.name ?? 'pick_supplier'.tr(),
                  titleColor: _supplier == null ? (due > 0.004 ? colors.danger : colors.primary) : null,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            NoteCard(controller: _noteController, hint: 'note_optional'.tr()),
          ],
        ),
      ),
    );
  }
}
