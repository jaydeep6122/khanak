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

/// Kept for the next count in this session: the khadkaniya rarely change.
List<Worker> _lastStackers = [];

/// A brick count ("ginti"). Bricks are counted only at a few moments: the
/// drying ground is full, they go into the kiln (by workers or by truck), or
/// the last count when the workers leave. One count pays the molder, the
/// loaders and the khadkaniya together. With [countId] it edits that count.
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
  Truck? _truck;
  GroupDraft? _loaders;
  GroupDraft? _stackers;

  /// Rates an edited count was made with, by work type id. A new count uses
  /// today's rates.
  final Map<String, double> _savedRates = {};
  BrickCount? _editing;
  bool _loading = false;
  bool _busy = false;

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
    setState(() => _loading = true);
    await Future.wait([
      core.factory.fetchWorkTypes(),
      core.factory.fetchTrucks(),
      core.worker.fetchWorkers(),
    ]);
    if (widget.countId != null) {
      final count = await core.entry.fetchCount(widget.countId!);
      if (count != null) _fill(count, core);
    } else {
      _stackers = GroupDraft(
        type: core.factory.workType('stacking')!,
        workers: [..._lastStackers],
      );
      _loaders = GroupDraft(type: core.factory.workType('kiln_loading')!);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(BrickCount count, Core core) {
    _editing = count;
    _date = count.countedOn;
    _reason = count.reason;
    _alreadyCounted = count.alreadyCounted;
    _quantityController.text = '${count.quantity}';
    _tripsController.text = count.trips == null ? '' : '${count.trips}';
    _noteController.text = count.note ?? '';
    _molder =
        core.worker.byId(count.molderId) ??
        (count.molderId == null
            ? null
            : Worker(
                id: count.molderId!,
                name: count.molderName ?? '',
                isActive: true,
              ));
    _truck = core.factory.trucks.value
        ?.where((t) => t.id == count.truckId)
        .firstOrNull;
    final molding = core.factory.workType('molding');
    if (molding != null && count.molderRate != null) {
      _savedRates[molding.id] = count.molderRate!;
    }
    // A molder paid other than by the rate had the amount set by hand.
    final byRate = count.quantity * (count.molderRate ?? 0) / 1000;
    if (count.molderPay != null && (count.molderPay! - byRate).abs() > 0.005) {
      _molderAmount = count.molderPay;
    }

    GroupDraft draftOf(WorkGroup group) {
      if (group.rate != null) _savedRates[group.workTypeId] = group.rate!;
      final type = core.factory.workTypes.value!.firstWhere(
        (t) => t.id == group.workTypeId,
      );
      final workers = [
        for (final share in group.workers)
          core.worker.byId(share.workerId) ??
              Worker(id: share.workerId, name: share.name, isActive: true),
      ];
      final draft = GroupDraft(type: type, workers: workers);
      final equal = splitEqually(group.total, workers.length);
      for (var i = 0; i < group.workers.length; i++) {
        if ((group.workers[i].amount - equal[i]).abs() > 0.001) {
          draft.amounts[workers[i].id] = group.workers[i].amount;
        }
      }
      return draft;
    }

    final stacking = count.groups
        .where((g) => g.workTypeCode == 'stacking')
        .firstOrNull;
    final loading = count.groups
        .where((g) => g.workTypeCode != 'stacking')
        .firstOrNull;
    _stackers = stacking == null
        ? GroupDraft(type: core.factory.workType('stacking')!)
        : draftOf(stacking);
    _loaders = loading == null
        ? GroupDraft(type: core.factory.workType('kiln_loading')!)
        : draftOf(loading);
  }

  int get _bricks =>
      int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
  int? get _trips => int.tryParse(_tripsController.text);

  double? _rate(WorkType? type) =>
      type == null ? null : (_savedRates[type.id] ?? type.rate);

  /// Each molder has their own rate, as on the server: an edited count keeps
  /// the rate it was made with while the molder stays the same.
  double _molderRate(WorkType molding) {
    final saved = _savedRates[molding.id];
    if (saved != null && _molder?.id == _editing?.molderId) return saved;
    return _molder?.rate ?? molding.rate ?? 0;
  }

  /// Molding is paid per 1000 bricks.
  double _molderPay(WorkType molding) =>
      _molderAmount ?? _bricks * _molderRate(molding) / 1000;

  /// Kinds of work a loading group can be paid as: per 1000 bricks or per trip.
  List<WorkType> _loadingChoices(Core core) =>
      (core.factory.workTypes.value ?? const [])
          .where(
            (t) =>
                t.isActive &&
                t.isGroup &&
                t.code != 'stacking' &&
                t.code != 'unloading',
          )
          .where(
            (t) =>
                t.payUnit == PayUnit.per1000 ||
                (t.payUnit == PayUnit.perTrip &&
                    _reason == CountReason.kilnByTruck),
          )
          .toList();

  Future<void> _pickMolder() async {
    final worker = await pickWorker(context, title: 'pick_molder'.tr(), role: MainWork.molder);
    if (worker != null) setState(() => _molder = worker);
  }

  Future<void> _editMolderAmount(double current) async {
    final controller = TextEditingController(
      text: Formatters.formatDouble(current),
    );
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
          if (_molderAmount != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text('use_rate'.tr()),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    setState(
      () => _molderAmount = value.isEmpty ? null : double.tryParse(value),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final core = context.read<Core>();
    if (!_alreadyCounted && _molder == null) {
      return showErrorToast('pick_molder_first'.tr());
    }
    if (_reason == CountReason.kilnByTruck && _truck == null) {
      return showErrorToast('pick_truck_first'.tr());
    }

    final groups = <Map<String, dynamic>>[];
    if (_reason.intoKiln) {
      for (final group in [_loaders, _stackers]) {
        if (group == null || group.workers.isEmpty) continue;
        final total = group.total(
          bricks: _bricks,
          trips: _trips,
          rate: _rate(group.type),
        );
        if (!group.fits(total)) return showErrorToast('shares_too_much'.tr());
        groups.add(group.toJson(total));
      }
    }

    final data = {
      'counted_on': apiDate(_date),
      'reason': _reason.value,
      'quantity': _bricks,
      'already_counted': _alreadyCounted,
      if (!_alreadyCounted) 'molder_id': _molder!.id,
      if (!_alreadyCounted && _molderAmount != null)
        'molder_amount': _molderAmount!.toStringAsFixed(2),
      if (_reason == CountReason.kilnByTruck) ...{
        'truck_id': _truck!.id,
        'trips': _trips,
      },
      'groups': groups,
      'note': _noteController.text.trim(),
    };

    setState(() => _busy = true);
    final saved = await core.entry.saveCount(data, countId: widget.countId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) {
      return showErrorToast(core.entry.error ?? 'error_generic'.tr());
    }

    if (_reason == CountReason.kilnByTruck ||
        _reason == CountReason.kilnByWorkers) {
      _lastStackers = [...?_stackers?.workers];
    }
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
    final done = await module.cancelCount(
      widget.countId!,
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    if (done == null) {
      return showErrorToast(module.error ?? 'error_generic'.tr());
    }
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

    if (_loading ||
        molding == null ||
        (_reason.intoKiln && (_loaders == null || _stackers == null))) {
      return Scaffold(
        appBar: AppBar(title: Text('action_brick_count'.tr())),
        body: const LoadingIndicator(),
      );
    }

    final molderPay = _molderPay(molding);
    final loaderTotal = _loaders!.total(
      bricks: _bricks,
      trips: _trips,
      rate: _rate(_loaders!.type),
    );
    final stackerTotal = _stackers!.total(
      bricks: _bricks,
      trips: _trips,
      rate: _rate(_stackers!.type),
    );
    final total =
        (_alreadyCounted ? 0.0 : molderPay) +
        (_reason.intoKiln && _loaders!.workers.isNotEmpty ? loaderTotal : 0.0) +
        (_reason.intoKiln && _stackers!.workers.isNotEmpty ? stackerTotal : 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.countId == null
              ? 'action_brick_count'.tr()
              : 'edit_count'.tr(),
        ),
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
            DateField(
              label: 'date'.tr(),
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
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
                if (r != CountReason.kilnByTruck &&
                    _loaders!.type.payUnit == PayUnit.perTrip) {
                  _loaders!.type = core.factory.workType('kiln_loading')!;
                  _loaders!.amounts.clear();
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
            if (!_alreadyCounted) ...[
              const SizedBox(height: AppTheme.spaceLg),
              FieldLabel('molder'.tr()),
              AppCard(
                onTap: _pickMolder,
                child: Row(
                  children: [
                    if (_molder != null)
                      InitialBadge(letter: _molder!.initial)
                    else
                      Icon(
                        Icons.person_search_rounded,
                        color: colors.primary,
                        size: 32,
                      ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Text(
                        _molder?.displayName ?? 'pick_molder'.tr(),
                        style: context.text.titleMedium?.copyWith(
                          color: _molder == null ? colors.primary : null,
                        ),
                      ),
                    ),
                    if (_molder != null && _bricks > 0)
                      InkWell(
                        onTap: canChangeAmounts
                            ? () => _editMolderAmount(molderPay)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spaceXs),
                          child: Text(
                            Formatters.formatCurrency(molderPay),
                            style: context.text.titleMedium?.copyWith(
                              color: _molderAmount != null
                                  ? colors.warning
                                  : colors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_molder != null && _bricks > 0 && _molderAmount == null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spaceXs,
                    left: AppTheme.spaceXs,
                  ),
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
            if (_reason == CountReason.kilnByTruck) ...[
              const SizedBox(height: AppTheme.spaceLg),
              FieldLabel('truck'.tr()),
              _TruckChoice(
                trucks: (core.factory.trucks.value ?? const [])
                    .where((t) => t.isActive)
                    .toList(),
                selected: _truck,
                onSelected: (t) => setState(() => _truck = t),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              AppTextField(
                controller: _tripsController,
                labelText: 'trips'.tr(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefixIcon: Icons.repeat_rounded,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                    ? null
                    : 'validation_trips'.tr(),
              ),
            ],
            if (_reason.intoKiln) ...[
              const SizedBox(height: AppTheme.spaceLg),
              GroupEditor(
                title: 'loaders'.tr(),
                group: _loaders!,
                role: MainWork.loader,
                typeChoices: _loadingChoices(core),
                bricks: _bricks,
                trips: _trips,
                rate: _rate(_loaders!.type),
                canChangeAmounts: canChangeAmounts,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              GroupEditor(
                title: 'stackers'.tr(),
                group: _stackers!,
                role: MainWork.stacker,
                typeChoices: const [],
                bricks: _bricks,
                trips: _trips,
                rate: _rate(_stackers!.type),
                canChangeAmounts: canChangeAmounts,
                onChanged: () => setState(() {}),
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _noteController,
              labelText: 'note_optional'.tr(),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            if (_bricks > 0)
              PayLine(label: 'total_pay'.tr(), amount: total, strong: true),
            const SizedBox(height: AppTheme.spaceMd),
            AppButton(text: 'save'.tr(), isLoading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _TruckChoice extends StatelessWidget {
  final List<Truck> trucks;
  final Truck? selected;
  final ValueChanged<Truck> onSelected;

  const _TruckChoice({
    required this.trucks,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (trucks.isEmpty) {
      return Text(
        'no_trucks_yet'.tr(),
        style: context.text.bodyMedium?.copyWith(color: context.colors.danger),
      );
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
