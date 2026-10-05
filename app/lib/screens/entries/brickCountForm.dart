import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/entries/groupDraft.dart';
import 'package:khanak/screens/entries/stockWarnings.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// A brick count ("ginti"). Bricks are counted only at a few moments: the
/// drying ground is full, they go into a kiln (by workers or by truck), or
/// the last count when the workers leave.
///
/// Bricks going into a kiln are always some molder's, put in by some
/// workers, into one kiln: the count cannot be saved without all three
/// (no molder when an earlier count already paid for them). Khadkaniya are
/// not paid here; their pay is typed in as other work. With [countId] it
/// edits that count.
class BrickCountFormScreen extends StatefulWidget {
  final String? countId;

  const BrickCountFormScreen({super.key, this.countId});

  @override
  State<BrickCountFormScreen> createState() => _BrickCountFormScreenState();
}

class _BrickCountFormScreenState extends State<BrickCountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _tripsController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  CountReason _reason = CountReason.drying;
  bool _alreadyCounted = false;
  Worker? _molder;
  double? _molderAmount;
  Kiln? _kiln;
  Truck? _truck;
  GroupDraft? _loaders;

  /// Rates an edited count was made with, by work type id. A new count uses
  /// today's rates.
  final Map<String, double> _savedRates = {};
  BrickCount? _editing;
  bool _loading = true;
  bool _busy = false;

  /// Set once save was tapped, so missing choices show in red.
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() => setState(() {}));
    _tripsController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _tripsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final core = context.read<Core>();
    await Future.wait([
      core.factory.fetchWorkTypes(),
      core.factory.fetchTrucks(),
      core.factory.fetchKilns(),
      core.worker.fetchWorkers(),
    ]);
    final loading = core.factory.workType('kiln_loading');
    if (loading != null) _loaders = GroupDraft(type: loading);

    final activeKilns = _activeKilns(core);
    if (activeKilns.length == 1) _kiln = activeKilns.first;

    if (widget.countId != null) {
      final count = await core.entry.fetchCount(widget.countId!);
      if (count != null) _fill(count, core);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Kiln> _activeKilns(Core core) => (core.factory.kilns.value ?? const <Kiln>[]).where((k) => k.isActive).toList();

  void _fill(BrickCount count, Core core) {
    _editing = count;
    _date = count.countedOn;
    _reason = count.reason;
    _alreadyCounted = count.alreadyCounted;
    _quantityController.text = '${count.quantity}';
    _tripsController.text = count.trips == null ? '' : '${count.trips}';
    _noteController.text = count.note ?? '';
    _molder = core.worker.byId(count.molderId) ??
        (count.molderId == null ? null : Worker(id: count.molderId!, name: count.molderName ?? '', isActive: true));
    _truck = core.factory.trucks.value?.where((t) => t.id == count.truckId).firstOrNull;
    _kiln = core.factory.kilns.value?.where((k) => k.id == count.kilnId).firstOrNull ??
        (count.kilnId == null ? null : Kiln(id: count.kilnId!, name: count.kilnName ?? '', isActive: true));

    final molding = core.factory.workType('molding');
    if (molding != null && count.molderRate != null) _savedRates[molding.id] = count.molderRate!;
    // A molder paid other than by the rate had the amount set by hand.
    final byRate = count.quantity * (count.molderRate ?? 0) / 1000;
    if (count.molderPay != null && (count.molderPay! - byRate).abs() > 0.005) {
      _molderAmount = count.molderPay;
    }

    final group = count.groups.firstOrNull;
    if (group == null) return;
    if (group.rate != null) _savedRates[group.workTypeId] = group.rate!;
    final type = core.factory.workTypes.value!.firstWhere((t) => t.id == group.workTypeId);
    final workers = [
      for (final share in group.workers)
        core.worker.byId(share.workerId) ?? Worker(id: share.workerId, name: share.name, isActive: true),
    ];
    _loaders = GroupDraft(type: type, workers: workers);
    final equal = splitEqually(group.total, workers.length);
    for (var i = 0; i < group.workers.length; i++) {
      if ((group.workers[i].amount - equal[i]).abs() > 0.001) _loaders!.amounts[workers[i].id] = group.workers[i].amount;
    }
  }

  int get _bricks => int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
  int? get _trips => int.tryParse(_tripsController.text);

  double? _rate(WorkType? type) => type == null ? null : (_savedRates[type.id] ?? type.rate);

  /// Each molder has their own rate, as on the server: an edited count keeps
  /// the rate it was made with while the molder stays the same.
  double _molderRate(WorkType molding) {
    final saved = _savedRates[molding.id];
    if (saved != null && _molder?.id == _editing?.molderId) return saved;
    return _molder?.rate ?? molding.rate ?? 0;
  }

  /// Molding is paid per 1000 bricks.
  double _molderPay(WorkType molding) => _molderAmount ?? _bricks * _molderRate(molding) / 1000;

  /// Kinds of work a loading group can be paid as: per 1000 bricks, or per
  /// trip when the truck carried them.
  List<WorkType> _loadingChoices(Core core) => (core.factory.workTypes.value ?? const <WorkType>[])
      .where((t) => t.isActive && t.isGroup && t.code != 'stacking' && t.code != 'unloading')
      .where((t) => t.payUnit == PayUnit.per1000 || (t.payUnit == PayUnit.perTrip && _reason == CountReason.kilnByTruck))
      .toList();

  bool get _needsMolder => !_alreadyCounted;
  bool get _needsKiln => _reason.intoKiln;

  Future<void> _pickMolder() async {
    final worker = await pickWorker(context, title: 'pick_molder'.tr(), role: MainWork.molder);
    if (worker != null) setState(() => _molder = worker);
  }

  Future<void> _editMolderAmount(double current) async {
    final controller = TextEditingController(text: Formatters.formatDouble(current));
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_molder?.name ?? ''),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: context.text.headlineSmall,
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          if (_molderAmount != null) TextButton(onPressed: () => Navigator.of(context).pop(''), child: Text('use_rate'.tr())),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: Text('save'.tr())),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    setState(() => _molderAmount = value.isEmpty ? null : double.tryParse(value));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    final valid = _formKey.currentState!.validate();
    final core = context.read<Core>();
    final loaders = _loaders!;

    // Every missing choice, in the order they appear on the screen.
    if (_needsMolder && _molder == null) return showErrorToast('pick_molder_first'.tr());
    if (_needsKiln && _kiln == null) return showErrorToast('pick_kiln_first'.tr());
    if (_reason == CountReason.kilnByTruck && _truck == null) return showErrorToast('pick_truck_first'.tr());
    if (_needsKiln && loaders.workers.isEmpty) return showErrorToast('pick_loaders_first'.tr());
    if (!valid) return;

    final groups = <Map<String, dynamic>>[];
    if (_needsKiln) {
      final total = loaders.total(bricks: _bricks, trips: _trips, rate: _rate(loaders.type));
      if (!loaders.fits(total)) return showErrorToast('shares_too_much'.tr());
      groups.add(loaders.toJson(total));
    }

    final data = {
      'counted_on': apiDate(_date),
      'reason': _reason.value,
      'quantity': _bricks,
      'already_counted': _alreadyCounted,
      if (_needsMolder) 'molder_id': _molder!.id,
      if (_needsMolder && _molderAmount != null) 'molder_amount': _molderAmount!.toStringAsFixed(2),
      if (_needsKiln) 'kiln_id': _kiln!.id,
      if (_reason == CountReason.kilnByTruck) ...{'truck_id': _truck!.id, 'trips': _trips},
      'groups': groups,
      'note': _noteController.text.trim(),
    };

    setState(() => _busy = true);
    final saved = await core.entry.saveCount(data, countId: widget.countId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(core.entry.error ?? 'error_generic'.tr());

    showSuccessToast('count_saved'.tr());
    showStockWarnings(saved.warnings);
    Navigator.of(context).pop(true);
  }

  Future<void> _cancelCount() async {
    final reason = await showReasonDialog(
      context,
      title: 'cancel_count_title'.tr(),
      message: 'cancel_count_message'.tr(),
      confirmText: 'cancel_entry'.tr(),
    );
    if (reason == null || !mounted) return;
    final module = context.read<Core>().entry;
    final done = await module.cancelCount(widget.countId!, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    if (done == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('entry_cancelled'.tr());
    showStockWarnings(done.warnings);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final colors = context.colors;
    final molding = core.factory.workType('molding');
    final canChangeAmounts = !core.isSupervisor;
    final title = widget.countId == null ? 'action_brick_count'.tr() : 'edit_count'.tr();

    if (_loading || molding == null || _loaders == null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const LoadingIndicator());
    }

    final loaders = _loaders!;
    final molderPay = _molderPay(molding);
    final loaderTotal = loaders.total(bricks: _bricks, trips: _trips, rate: _rate(loaders.type));
    final total = (_needsMolder ? molderPay : 0.0) + (_needsKiln && loaders.workers.isNotEmpty ? loaderTotal : 0.0);
    final kilns = _activeKilns(core);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.countId != null && _editing?.isCancelled == false)
            IconButton(
              tooltip: 'cancel_entry'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: _cancelCount,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          children: [
            DateField(label: 'date'.tr(), value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: AppTheme.spaceLg),
            FieldLabel('count_why'.tr()),
            ChoiceRow<CountReason>(
              options: CountReason.values,
              selected: _reason,
              label: (r) => r.displayName,
              icon: (r) => switch (r) {
                CountReason.drying => Icons.wb_sunny_rounded,
                CountReason.kilnByWorkers => Icons.groups_rounded,
                CountReason.kilnByTruck => Icons.local_shipping_rounded,
                CountReason.finalCount => Icons.flag_rounded,
              },
              onSelected: (r) => setState(() {
                _reason = r;
                if (!r.intoKiln) _alreadyCounted = false;
                if (r != CountReason.kilnByTruck && loaders.type.payUnit == PayUnit.perTrip) {
                  loaders.type = core.factory.workType('kiln_loading')!;
                  loaders.amounts.clear();
                }
              }),
            ),
            if (_reason.intoKiln) ...[
              const SizedBox(height: AppTheme.spaceMd),
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: _alreadyCounted,
                  title: Text('already_counted'.tr()),
                  subtitle: Text('already_counted_help'.tr()),
                  onChanged: (v) => setState(() => _alreadyCounted = v),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _quantityController,
              labelText: 'bricks_count'.tr(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: Icons.grid_view_rounded,
              validator: Validators.bricks,
            ),

            // 1. Whose bricks.
            if (_needsMolder) ...[
              const SizedBox(height: AppTheme.spaceLg),
              FieldLabel('molder'.tr()),
              _Choice(
                missing: _tried && _molder == null,
                onTap: _pickMolder,
                leading: _molder == null
                    ? Icon(Icons.person_search_rounded, color: colors.primary, size: 32)
                    : InitialBadge(letter: _molder!.initial),
                text: _molder?.displayName ?? 'pick_molder'.tr(),
                placeholder: _molder == null,
                trailing: _molder != null && _bricks > 0
                    ? InkWell(
                        onTap: canChangeAmounts ? () => _editMolderAmount(molderPay) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spaceXs),
                          child: Text(
                            Formatters.formatCurrency(molderPay),
                            style: context.text.titleMedium?.copyWith(
                              color: _molderAmount != null ? colors.warning : colors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              if (_molder != null && _bricks > 0 && _molderAmount == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
                  child: Text(
                    'molder_pay_line'.tr(
                      namedArgs: {
                        'bricks': Formatters.formatNumber(_bricks.toDouble()),
                        'rate': Formatters.formatCurrency(_molderRate(molding)),
                      },
                    ),
                    style: context.text.bodySmall,
                  ),
                ),
            ],

            if (_needsKiln) ...[
              // 2. Which kiln.
              const SizedBox(height: AppTheme.spaceLg),
              FieldLabel('which_kiln'.tr()),
              if (kilns.isEmpty)
                Text('no_kilns_yet'.tr(), style: context.text.bodyMedium?.copyWith(color: colors.danger))
              else
                ChoiceRow<Kiln>(
                  options: kilns,
                  selected: kilns.where((k) => k.id == _kiln?.id).firstOrNull,
                  label: (k) => k.name,
                  icon: (_) => Icons.local_fire_department_rounded,
                  onSelected: (k) => setState(() => _kiln = k),
                ),
              if (_tried && _kiln == null) _Missing('pick_kiln_first'.tr()),

              if (_reason == CountReason.kilnByTruck) ...[
                const SizedBox(height: AppTheme.spaceLg),
                FieldLabel('truck'.tr()),
                _TruckChoice(
                  trucks: (core.factory.trucks.value ?? const <Truck>[]).where((t) => t.isActive).toList(),
                  selected: _truck,
                  onSelected: (t) => setState(() => _truck = t),
                ),
                if (_tried && _truck == null) _Missing('pick_truck_first'.tr()),
                const SizedBox(height: AppTheme.spaceMd),
                AppTextField(
                  controller: _tripsController,
                  labelText: 'trips'.tr(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.repeat_rounded,
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'validation_trips'.tr(),
                ),
              ],

              // 3. Who put them in.
              const SizedBox(height: AppTheme.spaceLg),
              GroupEditor(
                title: 'loaders'.tr(),
                group: loaders,
                role: MainWork.loader,
                typeChoices: _loadingChoices(core),
                bricks: _bricks,
                trips: _trips,
                rate: _rate(loaders.type),
                canChangeAmounts: canChangeAmounts,
                onChanged: () => setState(() {}),
              ),
              if (_tried && loaders.workers.isEmpty) _Missing('pick_loaders_first'.tr()),
            ],

            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _noteController,
              labelText: 'note_optional'.tr(),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            if (_bricks > 0) PayLine(label: 'total_pay'.tr(), amount: total, strong: true),
            const SizedBox(height: AppTheme.spaceMd),
            AppButton(text: 'save'.tr(), isLoading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// A required choice shown as a card; outlined in red once save was tried
/// without it.
class _Choice extends StatelessWidget {
  final bool missing;
  final VoidCallback onTap;
  final Widget leading;
  final String text;
  final bool placeholder;
  final Widget? trailing;

  const _Choice({
    required this.missing,
    required this.onTap,
    required this.leading,
    required this.text,
    required this.placeholder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      borderColor: missing ? colors.danger : null,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              text,
              style: context.text.titleMedium?.copyWith(color: placeholder ? colors.primary : null),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  final String text;

  const _Missing(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
      child: Text(text, style: context.text.bodySmall?.copyWith(color: context.colors.danger)),
    );
  }
}

class _TruckChoice extends StatelessWidget {
  final List<Truck> trucks;
  final Truck? selected;
  final ValueChanged<Truck> onSelected;

  const _TruckChoice({required this.trucks, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (trucks.isEmpty) {
      return Text('no_trucks_yet'.tr(), style: context.text.bodyMedium?.copyWith(color: context.colors.danger));
    }
    return ChoiceRow<Truck>(
      options: trucks,
      selected: trucks.where((t) => t.id == selected?.id).firstOrNull,
      label: (t) => t.label,
      icon: (_) => Icons.local_shipping_rounded,
      onSelected: onSelected,
    );
  }
}
