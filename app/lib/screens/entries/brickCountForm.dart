import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/components/amountDialog.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/rateDialog.dart';
import 'package:khanak/components/optionSheet.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/components/tint.dart';
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

/// A brick count ("ginti"). Bricks are counted only at a few moments: they
/// are carried to the drying ground or into a kiln (by workers or by truck),
/// or the last count when the workers leave.
///
/// Carried bricks are always some molder's and carried by someone who is
/// paid for it: the count cannot be saved without both (no molder when an
/// earlier count already paid for them), nor without the kiln they went
/// into, or the truck that carried them. Bricks going into a kiln also pay
/// the khadkaniya who stacked them there, per lakh: this is the only place
/// they are paid. With [countId] it edits that count.
class BrickCountFormScreen extends StatefulWidget {
  final String? countId;

  const BrickCountFormScreen({super.key, this.countId});

  @override
  State<BrickCountFormScreen> createState() => _BrickCountFormScreenState();
}

class _BrickCountFormScreenState extends State<BrickCountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  CountReason _reason = CountReason.dryingByWorkers;
  bool _alreadyCounted = false;
  int _tripCount = 1;
  Worker? _molder;
  double? _molderAmount;
  Kiln? _kiln;
  Truck? _truck;
  GroupDraft? _loaders;

  /// The khadkaniya who stacked the bricks in the kiln, paid per lakh.
  GroupDraft? _stackers;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _quantityController.dispose();
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
    final carry = _defaultCarry(core, _reason.place);
    if (carry != null) _loaders = GroupDraft(type: carry);
    final stacking = core.factory.workType('stacking');
    if (stacking != null) {
      // With only one khadkaniyo there is nobody else to pick: he is in from
      // the start. With more, the owner picks who stacked this time.
      final khadkaniya = core.worker.activeWorkers.where((w) => w.mainWork == MainWork.stacker).toList();
      _stackers = GroupDraft(type: stacking, workers: khadkaniya.length == 1 ? khadkaniya : []);
    }

    final activeKilns = _activeKilns(core);
    if (activeKilns.length == 1) _kiln = activeKilns.first;
    final trucks = (core.factory.trucks.value ?? const <Truck>[]).where((t) => t.isActive).toList();
    if (trucks.length == 1) _truck = trucks.first;

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
    _tripCount = count.trips ?? 1;
    _noteController.text = count.note ?? '';
    _molder =
        core.worker.byId(count.molderId) ??
        (count.molderId == null ? null : Worker(id: count.molderId!, name: count.molderName ?? '', isActive: true));
    _truck = core.factory.trucks.value?.where((t) => t.id == count.truckId).firstOrNull;
    _kiln =
        core.factory.kilns.value?.where((k) => k.id == count.kilnId).firstOrNull ??
        (count.kilnId == null ? null : Kiln(id: count.kilnId!, name: count.kilnName ?? '', isActive: true));

    final molding = core.factory.workType('molding');
    if (molding != null && count.molderRate != null) _savedRates[molding.id] = count.molderRate!;
    // A molder paid other than by the rate had the amount set by hand.
    final byRate = count.quantity * (count.molderRate ?? 0) / 1000;
    if (count.molderPay != null && (count.molderPay! - byRate).abs() > 0.005) {
      _molderAmount = count.molderPay;
    }

    // The khadkaniya's group and the carriers' group, as they were saved.
    _stackers = _stackers == null ? null : GroupDraft(type: _stackers!.type);
    for (final group in count.groups) {
      if (group.rate != null) _savedRates[group.workTypeId] = group.rate!;
      final type = core.factory.workTypes.value!.firstWhere((t) => t.id == group.workTypeId);
      final workers = [
        for (final share in group.workers)
          core.worker.byId(share.workerId) ?? Worker(id: share.workerId, name: share.name, isActive: true),
      ];
      final draft = GroupDraft(type: type, workers: workers);
      final equal = splitEqually(group.total, workers.length);
      for (var i = 0; i < group.workers.length; i++) {
        if ((group.workers[i].amount - equal[i]).abs() > 0.001) draft.amounts[workers[i].id] = group.workers[i].amount;
      }
      if (type.code == 'stacking') {
        _stackers = draft;
      } else {
        _loaders = draft;
      }
    }
  }

  int get _bricks => int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
  int? get _trips => _reason.byTruck ? _tripCount : null;

  double? _rate(WorkType? type) => type == null ? null : keptOrCurrentRate(_savedRates[type.id], type);

  /// Each molder has their own rate, as on the server: an edited count keeps
  /// the rate it was made with while the molder stays the same.
  double _molderRate(WorkType molding) {
    final saved = _savedRates[molding.id];
    if (saved != null && saved > 0 && _molder?.id == _editing?.molderId) return saved;
    final own = _molder?.rate ?? 0;
    return own > 0 ? own : molding.rate ?? 0;
  }

  /// Molding is paid per 1000 bricks.
  double _molderPay(WorkType molding) => _molderAmount ?? _bricks * _molderRate(molding) / 1000;

  /// What carrying is paid as unless the owner picks otherwise: carrying to
  /// drying, or loading the kiln.
  WorkType? _defaultCarry(Core core, CountPlace place) =>
      core.factory.workType(place == CountPlace.kiln ? 'kiln_loading' : 'drying_carry') ??
      core.factory.workType('kiln_loading');

  /// Kinds of work the carrying group can be paid as: per 1000 bricks, or per
  /// trip when the truck carried them. Loading the kiln is not offered for
  /// carrying to dry, nor the other way round.
  List<WorkType> _loadingChoices(Core core) {
    final other = _reason.intoKiln ? 'drying_carry' : 'kiln_loading';
    return (core.factory.workTypes.value ?? const <WorkType>[])
        .where((t) => t.isActive && t.isGroup && !{'stacking', 'unloading', other}.contains(t.code))
        .where((t) => t.payUnit == PayUnit.per1000 || (t.payUnit == PayUnit.perTrip && _reason.byTruck))
        .toList();
  }

  bool get _needsMolder => !_alreadyCounted;
  bool get _needsKiln => _reason.intoKiln;
  bool get _needsCarriers => _reason.carried;

  /// Changes where or how the bricks went, keeping the carriers but paying
  /// them as fits the new reason.
  void _setReason(Core core, CountReason next) {
    final loaders = _loaders!;
    final placeChanged = next.place != _reason.place;
    _reason = next;
    if (!next.intoKiln) _alreadyCounted = false;
    final allowed = _loadingChoices(core).any((t) => t.id == loaders.type.id);
    if (placeChanged || !allowed) {
      final carry = _defaultCarry(core, next.place);
      if (carry != null && carry.id != loaders.type.id) {
        loaders.type = carry;
        loaders.amounts.clear();
      }
    }
  }

  Future<void> _pickMolder() async {
    final worker = await pickWorker(context, title: 'pick_molder'.tr(), role: MainWork.molder);
    if (worker != null) setState(() => _molder = worker);
  }

  Future<void> _pickKiln(List<Kiln> kilns) async {
    final kiln = await pickOption<Kiln>(
      context,
      title: 'which_kiln'.tr(),
      options: kilns,
      label: (k) => k.name,
      isSelected: (k) => k.id == _kiln?.id,
      tint: Tint.fire,
      empty: 'no_kilns_yet'.tr(),
    );
    if (kiln != null) setState(() => _kiln = kiln);
  }

  Future<void> _pickTruck(List<Truck> trucks) async {
    final truck = await pickOption<Truck>(
      context,
      title: 'truck'.tr(),
      options: trucks,
      label: (t) => t.label,
      isSelected: (t) => t.id == _truck?.id,
      tint: Tint.truck,
      empty: 'no_trucks_yet'.tr(),
    );
    if (truck != null) setState(() => _truck = truck);
  }

  Future<void> _editMolderAmount(double current) async {
    final value = await showAmountDialog(
      context,
      title: _molder?.name ?? '',
      initialValue: Formatters.formatDouble(current),
      resetText: _molderAmount != null ? 'use_rate'.tr() : null,
    );
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
    if (_reason.byTruck && _truck == null) return showErrorToast('pick_truck_first'.tr());
    if (_needsCarriers && loaders.workers.isEmpty) {
      return showErrorToast(_needsKiln ? 'pick_loaders_first'.tr() : 'pick_drying_carriers_first'.tr());
    }
    final stackers = _stackers;
    if (_needsKiln && (stackers == null || stackers.workers.isEmpty)) return showErrorToast('pick_stackers_first'.tr());
    if (!valid) return;

    // Nothing is priced from a missing rate: it is asked for here, the
    // first time a kind of work is used.
    final molding = core.factory.workType('molding')!;
    if (_needsMolder && _molderAmount == null && _molderRate(molding) <= 0) {
      if (await ensureRate(context, molding) == null || !mounted) return;
    }
    if (_needsCarriers && !await ensureGroupRate(context, loaders, _rate(loaders.type))) return;
    if (!mounted) return;
    if (_needsKiln && !await ensureGroupRate(context, stackers!, _rate(stackers.type))) return;
    if (!mounted) return;
    setState(() {});

    final groups = <Map<String, dynamic>>[];
    if (_needsCarriers) {
      final total = loaders.total(bricks: _bricks, trips: _trips, rate: _rate(loaders.type));
      if (!loaders.fits(total)) return showErrorToast('shares_too_much'.tr());
      groups.add(loaders.toJson(total));
    }
    if (_needsKiln) {
      final total = stackers!.total(bricks: _bricks, rate: _rate(stackers.type));
      if (!stackers.fits(total)) return showErrorToast('shares_too_much'.tr());
      groups.add(stackers.toJson(total));
    }

    final data = {
      'counted_on': apiDate(_date),
      'reason': _reason.value,
      'quantity': _bricks,
      'already_counted': _alreadyCounted,
      if (_needsMolder) 'molder_id': _molder!.id,
      if (_needsMolder && _molderAmount != null) 'molder_amount': _molderAmount!.toStringAsFixed(2),
      if (_needsKiln) 'kiln_id': _kiln!.id,
      if (_reason.byTruck) ...{'truck_id': _truck!.id, 'trips': _trips},
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
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const LoadingIndicator(),
      );
    }

    final loaders = _loaders!;
    final molderPay = _molderPay(molding);
    final loaderTotal = loaders.total(bricks: _bricks, trips: _trips, rate: _rate(loaders.type));
    final stackers = _stackers;
    final stackerTotal = stackers == null || stackers.workers.isEmpty
        ? 0.0
        : stackers.total(bricks: _bricks, rate: _rate(stackers.type));
    final total =
        (_needsMolder ? molderPay : 0.0) +
        (_needsCarriers && loaders.workers.isNotEmpty ? loaderTotal : 0.0) +
        (_needsKiln ? stackerTotal : 0.0);
    final kilns = _activeKilns(core);
    final trucks = (core.factory.trucks.value ?? const <Truck>[]).where((t) => t.isActive).toList();

    // What is asked depends on why the bricks are counted: whose they are
    // (unless counted before), and for a kiln which one, by which truck and
    // who put them in.
    final choices = <Widget>[
      if (_reason.intoKiln)
        GroupedRow(
          leading: const TintIcon(tint: Tint.neutral, icon: Icons.fact_check_rounded),
          title: 'already_counted'.tr(),
          subtitle: 'already_counted_help'.tr(),
          chevron: false,
          trailing: Switch(value: _alreadyCounted, onChanged: (v) => setState(() => _alreadyCounted = v)),
          onTap: () => setState(() => _alreadyCounted = !_alreadyCounted),
        ),
      if (_needsMolder)
        GroupedRow(
          leading: _molder == null
              ? _MissingIcon(icon: Icons.person_search_rounded, missing: _tried)
              : InitialBadge(letter: _molder!.initial, size: 36),
          label: 'molder_short'.tr(),
          title: _molder == null
              ? 'pick_molder'.tr()
              : '${_molder!.displayName} · ${Formatters.formatCurrency(_molderRate(molding))} / 1000',
          titleColor: _molder == null ? (_tried ? colors.danger : colors.primary) : null,
          onTap: _pickMolder,
        ),
      if (_needsKiln)
        GroupedRow(
          leading: _kiln == null
              ? _MissingIcon(icon: Icons.local_fire_department_rounded, missing: _tried)
              : const TintIcon(tint: Tint.fire),
          label: 'kiln_short'.tr(),
          title: _kiln?.name ?? 'pick_kiln'.tr(),
          titleColor: _kiln == null ? (_tried ? colors.danger : colors.primary) : null,
          onTap: () => _pickKiln(kilns),
        ),
      if (_reason.byTruck) ...[
        GroupedRow(
          leading: _truck == null
              ? _MissingIcon(icon: Icons.local_shipping_rounded, missing: _tried)
              : const TintIcon(tint: Tint.truck),
          label: 'truck'.tr(),
          title: _truck?.label ?? 'pick_truck'.tr(),
          titleColor: _truck == null ? (_tried ? colors.danger : colors.primary) : null,
          onTap: () => _pickTruck(trucks),
        ),
        GroupedRow(
          leading: const TintIcon(tint: Tint.neutral, icon: Icons.repeat_rounded),
          title: 'trips'.tr(),
          chevron: false,
          trailing: CountStepper(value: _tripCount, onChanged: (v) => setState(() => _tripCount = v)),
        ),
      ],
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.countId != null && _editing?.isCancelled == false)
            IconButton(
              tooltip: 'cancel_entry'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              onPressed: _cancelCount,
            ),
          DatePill(value: _date, onChanged: (d) => setState(() => _date = d)),
        ],
      ),
      bottomNavigationBar: SaveBar(
        label: 'save'.tr(),
        trailing: _bricks > 0 && total > 0 ? Formatters.formatCurrency(total) : null,
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
            // Where the bricks went, then how they were carried there.
            SegmentedControl<CountPlace>(
              options: CountPlace.values,
              selected: _reason.place,
              label: (place) => place.displayName,
              onChanged: (place) => setState(() => _setReason(core, CountReason.of(place, byTruck: _reason.byTruck))),
            ),
            if (_reason.carried) ...[
              const SizedBox(height: AppTheme.spaceSm),
              SegmentedControl<bool>(
                options: const [false, true],
                selected: _reason.byTruck,
                label: (byTruck) => byTruck ? 'carried_by_truck'.tr() : 'carried_by_workers'.tr(),
                onChanged: (byTruck) =>
                    setState(() => _setReason(core, CountReason.of(_reason.place, byTruck: byTruck))),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceSm),
              child: Text(_reason.displayName, textAlign: TextAlign.center, style: context.text.bodySmall),
            ),
            const SizedBox(height: AppTheme.space2xl),
            BigNumberField(
              controller: _quantityController,
              label: 'how_many_bricks'.tr(),
              quickAdds: const [1000, 5000, 10000],
              validator: Validators.bricks,
            ),
            const SizedBox(height: AppTheme.space2xl),
            if (choices.isNotEmpty) GroupedSection(children: choices),
            if (_needsMolder && _molder != null && _bricks > 0) ...[
              const SizedBox(height: AppTheme.spaceLg),
              GroupedSection(
                caption: 'pay'.tr(),
                dividerIndent: AppTheme.spaceLg,
                children: [
                  GroupedRow(
                    title: _molder!.name,
                    subtitle: _molderAmount != null
                        ? 'share_set_by_hand'.tr()
                        : 'molder_pay_line'.tr(
                            namedArgs: {
                              'bricks': Formatters.formatCount(_bricks),
                              'rate': Formatters.formatCurrency(_molderRate(molding)),
                            },
                          ),
                    value: Formatters.formatCurrency(molderPay),
                    valueColor: _molderAmount != null ? colors.warning : null,
                    chevron: false,
                    onTap: canChangeAmounts ? () => _editMolderAmount(molderPay) : null,
                  ),
                ],
              ),
            ],
            if (_needsCarriers) ...[
              const SizedBox(height: AppTheme.spaceLg),
              GroupEditor(
                title: _needsKiln ? 'loaders'.tr() : 'drying_carriers'.tr(),
                group: loaders,
                role: MainWork.loader,
                typeChoices: _loadingChoices(core),
                bricks: _bricks,
                trips: _trips,
                rate: _rate(loaders.type),
                canChangeAmounts: canChangeAmounts,
                missing: _tried && loaders.workers.isEmpty,
                onChanged: () => setState(() {}),
              ),
            ],
            if (_needsKiln && stackers != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              GroupEditor(
                title: 'stackers'.tr(),
                group: stackers,
                role: MainWork.stacker,
                typeChoices: const [],
                bricks: _bricks,
                trips: null,
                rate: _rate(stackers.type),
                canChangeAmounts: canChangeAmounts,
                missing: _tried && stackers.workers.isEmpty,
                onChanged: () => setState(() {}),
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            NoteCard(controller: _noteController, hint: 'note_optional'.tr()),
          ],
        ),
      ),
    );
  }
}

/// The icon of a choice not made yet; red once save was tried without it.
class _MissingIcon extends StatelessWidget {
  final IconData icon;
  final bool missing;

  const _MissingIcon({required this.icon, required this.missing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: missing ? colors.dangerSoft : colors.primarySoft, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: missing ? colors.danger : colors.primary),
    );
  }
}
