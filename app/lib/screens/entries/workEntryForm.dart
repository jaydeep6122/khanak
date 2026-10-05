import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// Work typed in by hand: day work ("6 days"), a lump sum ("₹150, he was
/// worn out") or any other kind of work outside a count. No attendance is
/// kept: days are entered whenever there is time. With [entry] it edits it.
class WorkEntryFormScreen extends StatefulWidget {
  final Worker? worker;
  final WorkEntry? entry;

  const WorkEntryFormScreen({super.key, this.worker, this.entry});

  @override
  State<WorkEntryFormScreen> createState() => _WorkEntryFormScreenState();
}

class _WorkEntryFormScreenState extends State<WorkEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _quantityController = TextEditingController(
    text: widget.entry?.quantity == null ? '' : Formatters.formatNumber(widget.entry!.quantity!),
  );
  late final _amountController = TextEditingController(
    text: widget.entry == null ? '' : Formatters.formatDouble(widget.entry!.amount),
  );
  late final _noteController = TextEditingController(text: widget.entry?.note);
  late DateTime _date = widget.entry?.entryDate ?? DateTime.now();
  Worker? _worker;
  WorkType? _type;

  /// The amount was typed rather than worked out from the rate.
  late bool _amountByHand = widget.entry != null;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _quantityController.addListener(_rateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final core = context.read<Core>();
      await Future.wait([core.factory.fetchWorkTypes(), core.worker.fetchWorkers()]);
      if (!mounted) return;
      setState(() {
        final entry = widget.entry;
        if (entry != null) {
          _worker = core.worker.byId(entry.workerId) ?? Worker(id: entry.workerId, name: entry.workerName, isActive: true);
          _type = core.factory.workTypes.value?.where((t) => t.id == entry.workTypeId).firstOrNull;
          // Typed by hand when it is not what its own rate gives.
          final type = _type;
          final byRate = type == null || entry.quantity == null || entry.rate == null
              ? null
              : WorkType(
                  id: type.id,
                  name: type.name,
                  payUnit: type.payUnit,
                  rate: entry.rate,
                  isGroup: type.isGroup,
                  isActive: true,
                ).payFor(entry.quantity!);
          _amountByHand = byRate == null || (byRate - entry.amount).abs() > 0.005;
        } else {
          _type = core.factory.workType('daily');
        }
      });
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The rate this worker gets for this kind of work: a day worker's own
  /// rate for day work, otherwise the factory's.
  double? get _rate {
    final type = _type;
    if (type == null) return null;
    final worker = _worker;
    if (type.code == 'daily' && worker?.mainWork == MainWork.daily && worker?.rate != null) return worker!.rate;
    return type.rate;
  }

  /// Keeps the amount in step with days × rate until it is typed by hand.
  void _rateChanged() {
    final type = _type;
    if (_amountByHand || type == null || !type.payUnit.hasRate) return;
    final quantity = double.tryParse(_quantityController.text);
    final pay = quantity == null
        ? null
        : WorkType(
            id: type.id,
            name: type.name,
            payUnit: type.payUnit,
            rate: _rate,
            isGroup: type.isGroup,
            isActive: true,
          ).payFor(quantity);
    _amountController.text = pay == null ? '' : Formatters.formatDouble(pay);
  }

  List<WorkType> _choices(Core core) => (core.factory.workTypes.value ?? const [])
      .where((t) => t.isActive && t.payUnit != PayUnit.perMonth)
      .where(
        (t) =>
            t.code == 'daily' ||
            t.code == 'lumpsum' ||
            t.code == 'stacking' ||
            t.code == 'truck_loading' ||
            t.code == null,
      )
      .toList();

  Future<void> _pickWorker() async {
    final worker = await pickWorker(context, title: 'pick_worker'.tr());
    if (worker == null) return;
    setState(() => _worker = worker);
    _rateChanged();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_worker == null) return showErrorToast('pick_worker_first'.tr());
    final type = _type!;
    final module = context.read<Core>().entry;

    setState(() => _busy = true);
    final saved = await module.saveWorkEntry({
      'worker_id': _worker!.id,
      'work_type_id': type.id,
      'entry_date': apiDate(_date),
      if (type.payUnit.hasRate) 'quantity': _quantityController.text.trim(),
      // A typed amount wins over the rate.
      if (!type.payUnit.hasRate || _amountByHand) 'amount': apiAmount(_amountController.text),
      'note': _noteController.text.trim(),
    }, entryId: widget.entry?.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('work_saved'.tr());
    Navigator.of(context).pop(true);
  }

  Future<void> _cancel() async {
    final reason = await showReasonDialog(
      context,
      title: 'cancel_work_title'.tr(),
      message: 'cancel_work_message'.tr(),
      confirmText: 'cancel_entry'.tr(),
    );
    if (reason == null || !mounted) return;
    final module = context.read<Core>().entry;
    final done = await module.cancelWorkEntry(widget.entry!.id, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    if (done == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('entry_cancelled'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final colors = context.colors;
    final type = _type;
    final choices = _choices(core);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'action_other_work'.tr() : 'edit_work'.tr()),
        actions: [
          if (widget.entry != null && !widget.entry!.isCancelled)
            IconButton(
              tooltip: 'cancel_entry'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: _cancel,
            ),
        ],
      ),
      body: type == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                children: [
                  FieldLabel('worker'.tr()),
                  AppCard(
                    onTap: _pickWorker,
                    child: Row(
                      children: [
                        if (_worker != null) InitialBadge(letter: _worker!.initial) else Icon(Icons.person_search_rounded, color: colors.primary, size: 32),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Text(
                            _worker?.displayName ?? 'pick_worker'.tr(),
                            style: context.text.titleMedium?.copyWith(color: _worker == null ? colors.primary : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  FieldLabel('work_kind'.tr()),
                  ChoiceRow<WorkType>(
                    options: choices,
                    selected: choices.where((t) => t.id == type.id).firstOrNull,
                    label: (t) => t.label,
                    onSelected: (t) => setState(() {
                      _type = t;
                      _amountByHand = !t.payUnit.hasRate;
                      _rateChanged();
                    }),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  if (type.payUnit.hasRate) ...[
                    AppTextField(
                      controller: _quantityController,
                      labelText: 'quantity_${type.payUnit.value}'.tr(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [DecimalInputFormatter(decimals: 1)],
                      validator: (v) => Validators.quantity(v),
                    ),
                    if (_rate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
                        child: Text(
                          'rate_line'.tr(
                            namedArgs: {
                              'rate': Formatters.formatCurrency(_rate!),
                              'unit': 'pay_unit_${type.payUnit.value}'.tr(),
                            },
                          ),
                          style: context.text.bodySmall,
                        ),
                      ),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],
                  AppTextField(
                    controller: _amountController,
                    labelText: 'amount'.tr(),
                    helperText: type.payUnit.hasRate ? 'amount_change_help'.tr() : null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(decimals: 2)],
                    prefixText: '₹ ',
                    onChanged: (_) => _amountByHand = true,
                    validator: (v) => Validators.amount(v, fieldLabel: 'amount'.tr()),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  DateField(label: 'date'.tr(), value: _date, onChanged: (d) => setState(() => _date = d)),
                  const SizedBox(height: AppTheme.spaceLg),
                  AppTextField(
                    controller: _noteController,
                    labelText: 'note_optional'.tr(),
                    hintText: 'work_note_hint'.tr(),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppTheme.space2xl),
                  AppButton(text: 'save'.tr(), isLoading: _busy, onPressed: _submit),
                ],
              ),
            ),
    );
  }
}
