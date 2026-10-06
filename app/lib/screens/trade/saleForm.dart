import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/entries/groupDraft.dart';
import 'package:khanak/screens/entries/stockWarnings.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/trade.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// A load of fired bricks sold. The price changes from load to load, so it
/// starts at the last one. Paid in full, the customer can stay nameless;
/// anything left owing needs the customer on record, with a phone. With
/// [saleId] it edits that sale.
class SaleFormScreen extends StatefulWidget {
  final String? saleId;
  final Party? customer;

  const SaleFormScreen({super.key, this.saleId, this.customer});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _bhaduController = TextEditingController();
  final _paidController = TextEditingController();
  final _nameController = TextEditingController();
  final _tripsController = TextEditingController(text: '1');
  final _destinationController = TextEditingController();
  final _hireController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  Party? _customer;
  Delivery _delivery = Delivery.customer;
  Truck? _truck;
  Worker? _driver;
  Party? _truckOwner;
  GroupDraft? _loaders;
  final Map<String, double> _savedRates = {};
  Sale? _editing;

  /// The rate and the amount paid follow the bill until typed by hand.
  bool _rateByHand = false;
  bool _paidByHand = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    for (final controller in [_quantityController, _rateController, _bhaduController, _tripsController]) {
      controller.addListener(_billChanged);
    }
    _paidController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in [
      _quantityController,
      _rateController,
      _bhaduController,
      _paidController,
      _nameController,
      _tripsController,
      _destinationController,
      _hireController,
      _noteController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final core = context.read<Core>();
    await Future.wait([core.factory.fetchWorkTypes(), core.factory.fetchTrucks(), core.worker.fetchWorkers()]);
    final loading = core.factory.workType('truck_loading') ?? core.factory.workType('kiln_loading');
    if (loading != null) _loaders = GroupDraft(type: loading);
    final trucks = _activeTrucks(core);
    if (trucks.length == 1) _truck = trucks.first;
    final drivers = core.worker.activeWorkers.where((w) => w.mainWork == MainWork.driver).toList();
    if (drivers.length == 1) _driver = drivers.first;

    if (widget.saleId != null) {
      final sale = await core.trade.fetchSale(widget.saleId!);
      if (sale != null) _fill(sale, core);
    } else {
      await _suggestRate();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(Sale sale, Core core) {
    _editing = sale;
    _date = sale.soldOn;
    _customer = sale.partyId == null
        ? null
        : Party(
            id: sale.partyId!,
            kind: 'customer',
            name: sale.partyName ?? '',
            phone: sale.partyPhone,
            isActive: true,
          );
    _nameController.text = sale.customerName ?? '';
    _quantityController.text = '${sale.quantity}';
    _rateController.text = Formatters.formatDouble(sale.rate);
    _bhaduController.text = sale.bhadu == null ? '' : Formatters.formatDouble(sale.bhadu!);
    _paidController.text = Formatters.formatDouble(sale.paidAmount);
    _rateByHand = true;
    _paidByHand = true;
    _delivery = sale.delivery;
    _truck = core.factory.trucks.value?.where((t) => t.id == sale.truckId).firstOrNull;
    _driver = sale.driverId == null
        ? null
        : core.worker.byId(sale.driverId) ?? Worker(id: sale.driverId!, name: sale.driverName ?? '', isActive: true);
    _tripsController.text = '${sale.trips ?? 1}';
    _destinationController.text = sale.destination ?? '';
    _truckOwner = sale.hirePartyId == null
        ? null
        : Party(id: sale.hirePartyId!, kind: 'supplier', name: sale.hirePartyName ?? '', isActive: true);
    _hireController.text = sale.hireAmount == null ? '' : Formatters.formatDouble(sale.hireAmount!);
    _noteController.text = sale.note ?? '';

    final group = sale.groups.firstOrNull;
    if (group == null) return;
    if (group.rate != null) _savedRates[group.workTypeId] = group.rate!;
    final type = core.factory.workTypes.value!.firstWhere((t) => t.id == group.workTypeId);
    final workers = [
      for (final share in group.workers)
        core.worker.byId(share.workerId) ?? Worker(id: share.workerId, name: share.name, isActive: true),
    ];
    _loaders = GroupDraft(
      type: type,
      workers: workers,
      savedRates: {
        for (final share in group.workers)
          if (share.rate != null) share.workerId: share.rate!,
      },
    );
    markHandSetShares(_loaders!, group, bricks: sale.quantity, trips: _trips);
  }

  /// Starts the rate at this customer's last price, or the last sale's.
  Future<void> _suggestRate() async {
    if (_rateByHand) return;
    final rate = await context.read<Core>().trade.lastRate(partyId: _customer?.id);
    if (rate != null && mounted && !_rateByHand) {
      _rateController.text = Formatters.formatDouble(rate);
    }
  }

  List<Truck> _activeTrucks(Core core) =>
      (core.factory.trucks.value ?? const <Truck>[]).where((t) => t.isActive).toList();

  int get _bricks => int.tryParse(_quantityController.text) ?? 0;
  int get _trips => _delivery == Delivery.ownTruck ? (int.tryParse(_tripsController.text) ?? 1) : 1;
  double get _rate => double.tryParse(_rateController.text) ?? 0;
  double get _bhadu => double.tryParse(_bhaduController.text) ?? 0;
  double get _bricksAmount => ((_bricks * _rate / 1000) * 100).roundToDouble() / 100;
  double get _total => _bricksAmount + _bhadu;
  double get _paid => double.tryParse(_paidController.text) ?? 0;

  /// Paid in full until the amount paid is typed by hand.
  void _billChanged() {
    if (!_paidByHand) {
      final text = Formatters.formatDouble(_total);
      if (_paidController.text != text) _paidController.text = text;
    }
    setState(() {});
  }

  List<WorkType> _loadingChoices(Core core) => (core.factory.workTypes.value ?? const <WorkType>[])
      .where((t) => t.isActive && t.isGroup && !{'stacking', 'unloading'}.contains(t.code))
      .where((t) => t.payUnit.byBricks || t.payUnit == PayUnit.perTrip)
      .toList();

  Future<void> _pickCustomer() async {
    final party = await pickParty(context, kind: 'customer', title: 'pick_customer'.tr());
    if (party == null) return;
    setState(() => _customer = party);
    await _suggestRate();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    final due = _total - _paid;
    if (_delivery == Delivery.ownTruck && _truck == null) return showErrorToast('pick_truck_first'.tr());
    if (_delivery == Delivery.hired && _truckOwner == null) return showErrorToast('pick_truck_owner_first'.tr());
    // Anything left owing needs someone to collect it from.
    if (due > 0.004 && _customer == null) return showErrorToast('credit_needs_customer'.tr());
    if (due > 0.004 && (_customer!.phone ?? '').isEmpty) return showErrorToast('credit_needs_phone'.tr());
    if (!valid) return;

    final loaders = _loaders;
    final groups = <Map<String, dynamic>>[];
    if (loaders != null && loaders.workers.isNotEmpty) {
      final rate = keptOrCurrentRate(_savedRates[loaders.type.id], loaders.type);
      if (!await ensureGroupRate(context, loaders, rate) || !mounted) return;
      setState(() {});
      final total = loaders.total(
        bricks: _bricks,
        trips: _trips,
        rate: keptOrCurrentRate(_savedRates[loaders.type.id], loaders.type),
      );
      if (!loaders.fits(total)) return showErrorToast('shares_too_much'.tr());
      // Each loader's bricks must add up to the bricks sold.
      final bricksProblem = loaders.bricksProblem(_bricks);
      if (bricksProblem != null) return showErrorToast(bricksProblem);
      groups.add(
        loaders.toJson(
          bricks: _bricks,
          trips: _trips,
          rate: keptOrCurrentRate(_savedRates[loaders.type.id], loaders.type),
        ),
      );
    }

    final name = _nameController.text.trim();
    final data = {
      'sold_on': apiDate(_date),
      if (_customer != null) 'party_id': _customer!.id else if (name.isNotEmpty) 'customer_name': name,
      'quantity': _bricks,
      'rate': apiAmount(_rateController.text),
      'bhadu': apiAmount(_bhaduController.text),
      'paid_amount': apiAmount(_paidController.text) ?? '0',
      'delivery': _delivery.value,
      if (_delivery == Delivery.ownTruck) ...{'truck_id': _truck!.id, 'driver_id': _driver?.id, 'trips': _trips},
      'destination': _destinationController.text.trim(),
      if (_delivery == Delivery.hired) ...{
        'hire_party_id': _truckOwner!.id,
        'hire_amount': apiAmount(_hireController.text),
      },
      'groups': groups,
      'note': _noteController.text.trim(),
    };

    final trade = context.read<Core>().trade;
    setState(() => _busy = true);
    final saved = await trade.saveSale(data, saleId: widget.saleId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(trade.error ?? 'error_generic'.tr());
    showSuccessToast('sale_saved'.tr());
    showStockWarnings(saved.warnings);
    Navigator.of(context).pop(true);
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

  Future<void> _cancel() async {
    final reason = await showReasonDialog(
      context,
      title: 'cancel_sale_title'.tr(),
      message: 'cancel_sale_message'.tr(),
      confirmText: 'cancel_entry'.tr(),
    );
    if (reason == null || !mounted) return;
    final trade = context.read<Core>().trade;
    final done = await trade.cancelSale(widget.saleId!, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    if (done == null) return showErrorToast(trade.error ?? 'error_generic'.tr());
    showSuccessToast('entry_cancelled'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final colors = context.colors;
    final title = widget.saleId == null ? 'action_sale'.tr() : 'edit_sale'.tr();
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const LoadingIndicator(),
      );
    }

    final due = _total - _paid;
    final trucks = _activeTrucks(core);
    final loaders = _loaders;

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
          if (widget.saleId != null && _editing?.isCancelled == false)
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
        trailing: _total > 0 ? Formatters.formatCurrency(_total) : null,
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
            BigNumberField(
              controller: _quantityController,
              label: 'bricks_count'.tr(),
              quickAdds: const [1000, 2000, 5000],
              validator: Validators.bricks,
            ),
            const SizedBox(height: AppTheme.space2xl),
            GroupedSection(
              children: [
                GroupedRow(
                  onTap: _pickCustomer,
                  leading: _customer == null
                      ? pickIcon(Icons.person_search_rounded)
                      : InitialBadge(
                          letter: _customer!.name.isEmpty ? '?' : _customer!.name[0].toUpperCase(),
                          size: 36,
                        ),
                  label: 'customer'.tr(),
                  title: _customer?.name ?? 'pick_customer'.tr(),
                  titleColor: _customer == null ? colors.primary : null,
                  subtitle: _customer == null ? 'customer_optional_cash'.tr() : _customer!.phone,
                  chevron: _customer == null,
                  trailing: _customer == null
                      ? null
                      : IconButton(
                          tooltip: 'remove'.tr(),
                          icon: Icon(Icons.close_rounded, color: colors.muted, size: 20),
                          onPressed: () => setState(() => _customer = null),
                        ),
                ),
              ],
            ),
            if (_customer == null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppTextField(
                controller: _nameController,
                labelText: 'cash_buyer_name'.tr(),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _rateController,
                    labelText: 'rate_per_1000'.tr(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(decimals: 2)],
                    prefixText: '₹ ',
                    onChanged: (_) => _rateByHand = true,
                    validator: (v) => Validators.amount(v, fieldLabel: 'rate'.tr()),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: AppTextField(
                    controller: _bhaduController,
                    labelText: 'bhadu_optional'.tr(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter(decimals: 2)],
                    prefixText: '₹ ',
                    validator: (v) => Validators.amount(v, fieldLabel: 'bhadu'.tr(), isRequired: false),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
              child: Text('bhadu_help'.tr(), style: context.text.bodySmall),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            GroupedSection(
              caption: 'bill'.tr(),
              dividerIndent: AppTheme.spaceLg,
              children: [
                AmountLine(
                  label: 'bricks_amount'.tr(),
                  note: _bricks > 0
                      ? '${Formatters.formatCount(_bricks)} × ${Formatters.formatCurrency(_rate)} / 1000'
                      : null,
                  value: Formatters.formatCurrency(_bricksAmount),
                ),
                if (_bhadu > 0) AmountLine(label: 'bhadu'.tr(), value: Formatters.formatCurrency(_bhadu)),
                AmountLine(label: 'bill_total'.tr(), value: Formatters.formatCurrency(_total), strong: true),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _paidController,
              labelText: 'paid_now'.tr(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter(decimals: 2)],
              prefixText: '₹ ',
              onChanged: (_) => _paidByHand = true,
              validator: (v) => Validators.amount(v, fieldLabel: 'paid_now'.tr()),
            ),
            if (due.abs() > 0.004)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(
                    text: due > 0
                        ? 'credit_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(due)})
                        : 'advance_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(-due)}),
                    color: due > 0 ? colors.warning : colors.info,
                    background: due > 0 ? colors.warningSoft : colors.infoSoft,
                  ),
                ),
              ),
            const SizedBox(height: AppTheme.space2xl),
            GroupCaption('delivery'.tr()),
            SegmentedControl<Delivery>(
              options: Delivery.values,
              selected: _delivery,
              label: (d) => d.displayName,
              onChanged: (d) => setState(() {
                _delivery = d;
                _billChanged();
              }),
            ),
            if (_delivery == Delivery.ownTruck) ...[
              const SizedBox(height: AppTheme.spaceMd),
              GroupedSection(
                children: [
                  GroupedRow(
                    onTap: () => _pickTruck(trucks),
                    leading: _truck == null ? pickIcon(Icons.local_shipping_rounded) : const TintIcon(tint: Tint.truck),
                    label: 'truck'.tr(),
                    title: _truck?.label ?? 'pick_truck'.tr(),
                    titleColor: _truck == null ? colors.primary : null,
                  ),
                  GroupedRow(
                    onTap: () async {
                      final driver = await pickWorker(context, title: 'pick_driver'.tr(), role: MainWork.driver);
                      if (driver != null) setState(() => _driver = driver);
                    },
                    leading: _driver == null
                        ? pickIcon(Icons.badge_rounded)
                        : InitialBadge(letter: _driver!.initial, size: 36),
                    label: 'driver'.tr(),
                    title: _driver?.name ?? 'pick_driver'.tr(),
                    titleColor: _driver == null ? colors.primary : null,
                  ),
                  GroupedRow(
                    leading: const TintIcon(tint: Tint.neutral, icon: Icons.repeat_rounded),
                    title: 'trips'.tr(),
                    chevron: false,
                    trailing: CountStepper(
                      value: _trips,
                      onChanged: (v) => setState(() {
                        _tripsController.text = '$v';
                      }),
                    ),
                  ),
                ],
              ),
            ],
            if (_delivery == Delivery.hired) ...[
              const SizedBox(height: AppTheme.spaceMd),
              GroupedSection(
                children: [
                  GroupedRow(
                    onTap: () async {
                      final owner = await pickParty(context, kind: 'supplier', title: 'truck_owner'.tr());
                      if (owner != null) setState(() => _truckOwner = owner);
                    },
                    leading: _truckOwner == null
                        ? pickIcon(Icons.person_search_rounded)
                        : InitialBadge(
                            letter: _truckOwner!.name.isEmpty ? '?' : _truckOwner!.name[0].toUpperCase(),
                            size: 36,
                          ),
                    label: 'truck_owner'.tr(),
                    title: _truckOwner?.name ?? 'pick_truck_owner'.tr(),
                    titleColor: _truckOwner == null ? colors.primary : null,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppTextField(
                controller: _hireController,
                labelText: 'truck_rent'.tr(),
                helperText: 'truck_rent_help'.tr(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(decimals: 2)],
                prefixText: '₹ ',
                validator: (v) => Validators.amount(v, fieldLabel: 'truck_rent'.tr()),
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _destinationController,
              labelText: 'destination'.tr(),
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.place_outlined,
            ),
            if (loaders != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              GroupEditor(
                title: 'truck_loaders'.tr(),
                group: loaders,
                role: MainWork.loader,
                typeChoices: _loadingChoices(core),
                bricks: _bricks,
                trips: _trips,
                rate: keptOrCurrentRate(_savedRates[loaders.type.id], loaders.type),
                canChangeAmounts: true,
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
