import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/rateDialog.dart';
import 'package:khanak/components/saveBar.dart';
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
    _amountController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final core = context.read<Core>();
      await Future.wait([core.factory.fetchWorkTypes(), core.worker.fetchWorkers()]);
      if (!mounted) return;
      setState(() {
        final entry = widget.entry;
        if (entry != null) {
          _worker =
              core.worker.byId(entry.workerId) ?? Worker(id: entry.workerId, name: entry.workerName, isActive: true);
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

  /// The rate this worker gets for this kind of work, as on the server: their
  /// own day rate for day work, their own rate per 1000 for brick work paid
  /// at each worker's rate, otherwise the factory's.
  double? get _rate {
    final type = _type;
    if (type == null) return null;
    final worker = _worker;
    if (type.atOwnRate) return worker?.brickRate;
    if (type.payUnit == PayUnit.perDay && worker?.dayRate != null) return worker!.dayRate;
    return type.rate;
  }

  /// The rate the server will price this entry at: an edited entry keeps the
  /// rate it was made with while its worker and kind stay the same.
  double? get _pricingRate {
    final entry = widget.entry;
    final kept = entry?.rate ?? 0;
    if (entry != null && kept > 0 && entry.workTypeId == _type?.id && entry.workerId == _worker?.id) return kept;
    return _rate;
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
      .where((t) => t.code == 'daily' || t.code == 'lumpsum' || t.code == 'truck_loading' || t.code == null)
      .toList();

  /// Sets the rate of the kind of work picked, the first time it is used.
  Future<void> _setRate() async {
    final updated = await askRate(context, _type!);
    if (updated == null || !mounted) return;
    setState(() => _type = updated);
    _rateChanged();
  }

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
    // Priced by a rate: it must have one, unless the amount was typed in.
    if (_type!.payUnit.hasRate && !_amountByHand && (_pricingRate ?? 0) <= 0) {
      final updated = await ensureRate(context, _type!);
      if (updated == null || !mounted) return;
      setState(() => _type = updated);
      _rateChanged();
    }
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

    final amount = double.tryParse(_amountController.text) ?? 0;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(widget.entry == null ? 'action_other_work'.tr() : 'edit_work'.tr()),
        actions: [
          if (widget.entry != null && !widget.entry!.isCancelled)
            IconButton(
              tooltip: 'cancel_entry'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: _cancel,
            ),
          DatePill(value: _date, onChanged: (d) => setState(() => _date = d)),
        ],
      ),
      bottomNavigationBar: type == null
          ? null
          : SaveBar(
              label: 'save'.tr(),
              trailing: amount > 0 ? Formatters.formatCurrency(amount) : null,
              isLoading: _busy,
              onPressed: _submit,
            ),
      body: type == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                        onTap: _pickWorker,
                        leading: _worker != null
                            ? InitialBadge(letter: _worker!.initial, size: 36)
                            : Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
                                child: Icon(Icons.person_search_rounded, size: 19, color: colors.primary),
                              ),
                        label: 'worker'.tr(),
                        title: _worker?.displayName ?? 'pick_worker'.tr(),
                        titleColor: _worker == null ? colors.primary : null,
                      ),
                    ],
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
                    if ((_rate ?? 0) == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                canSetRates(context) ? 'rate_missing_line'.tr() : 'rate_ask_owner'.tr(),
                                style: context.text.bodySmall?.copyWith(color: colors.warning),
                              ),
                            ),
                            if (canSetRates(context)) TextButton(onPressed: _setRate, child: Text('set_rate'.tr())),
                          ],
                        ),
                      )
                    else
                      // The owner or munim taps the rate to change it.
                      InkWell(
                        onTap: canSetRates(context) ? _setRate : null,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs, bottom: 2),
                          child: Row(
                            children: [
                              Flexible(
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
                              if (canSetRates(context)) ...[
                                const SizedBox(width: AppTheme.spaceXs),
                                Icon(Icons.edit_rounded, size: 13, color: colors.muted),
                              ],
                            ],
                          ),
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
                  NoteCard(controller: _noteController, hint: 'work_note_hint'.tr()),
                ],
              ),
            ),
    );
  }
}
