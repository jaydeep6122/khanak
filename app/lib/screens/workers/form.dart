import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/rateDialog.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/tint.dart';
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

/// A worker's details, kept short: the name, what they mainly do and what
/// they are paid are required (a paatla's own rate per 1000 bricks, a
/// driver's monthly salary, a group's rate the first time it is needed); a
/// phone number and a note are optional. No photo.
class WorkerFormScreen extends StatefulWidget {
  final Worker? worker;

  /// From a picker: the kind of worker being looked for, and the name typed.
  final MainWork? initialMainWork;
  final String? initialName;

  const WorkerFormScreen({super.key, this.worker, this.initialMainWork, this.initialName});

  @override
  State<WorkerFormScreen> createState() => _WorkerFormScreenState();
}

class _WorkerFormScreenState extends State<WorkerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.worker?.name ?? widget.initialName);
  late final _phoneController = TextEditingController(text: widget.worker?.phone);
  late final _noteController = TextEditingController(text: widget.worker?.note);
  late final _rateController = TextEditingController(
    text: widget.worker?.rate == null ? '' : Formatters.formatDouble(widget.worker!.rate!),
  );
  late final _salaryController = TextEditingController(
    text: widget.worker?.monthlySalary == null ? '' : Formatters.formatDouble(widget.worker!.monthlySalary!),
  );
  late MainWork? _mainWork = widget.worker?.mainWork ?? widget.initialMainWork;
  late DateTime _salaryFrom = widget.worker?.salaryFrom ?? DateTime.now();
  bool _busy = false;

  /// Rates typed here for group work not priced yet, by work type code.
  final Map<String, TextEditingController> _groupRates = {};

  TextEditingController _groupRate(String code) => _groupRates.putIfAbsent(code, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().factory.fetchWorkTypes());
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _phoneController,
      _noteController,
      _rateController,
      _salaryController,
      ..._groupRates.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    if (_mainWork == null) return showErrorToast('pick_main_work_first'.tr());
    if (!valid) return;

    final work = _mainWork!;
    final driver = work == MainWork.driver;
    final core = context.read<Core>();
    final module = core.worker;
    // Group work not priced yet is priced together with the worker.
    final unpriced = _unpriced(core, work);
    setState(() => _busy = true);
    final saved = await module.saveWorker({
      'name': _nameController.text.trim(),
      'main_work': work.value,
      'rate': work.hasOwnRate ? apiAmount(_rateController.text) : null,
      'phone': _text(_phoneController),
      'note': _text(_noteController),
      'monthly_salary': driver ? apiAmount(_salaryController.text) : null,
      'salary_from': driver ? apiDate(_salaryFrom) : null,
      if (unpriced.isNotEmpty)
        'group_rates': [
          for (final type in unpriced) {'work_type_id': type.id, 'rate': apiAmount(_groupRate(type.code!).text)},
        ],
    }, workerId: widget.worker?.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    if (unpriced.isNotEmpty) await core.factory.fetchWorkTypes(refresh: true);
    if (!mounted) return;
    showSuccessToast('saved'.tr());
    Navigator.of(context).pop(saved);
  }

  /// The group work [work] is paid for that has no rate yet.
  List<WorkType> _unpriced(Core core, MainWork work) => [
    for (final code in work.groupWork)
      if (core.factory.workType(code) case final type? when rateMissing(type)) type,
  ];

  @override
  Widget build(BuildContext context) {
    final work = _mainWork;
    final core = context.watch<Core>();

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(widget.worker == null ? 'worker_new'.tr() : 'worker_edit'.tr())),
      bottomNavigationBar: SaveBar(label: 'save'.tr(), isLoading: _busy, onPressed: _submit),
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
            AppTextField(
              controller: _nameController,
              labelText: 'worker_name'.tr(),
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.person_outline_rounded,
              autofocus: widget.worker == null && widget.initialName == null,
              validator: (v) => Validators.required(v, 'worker_name'.tr()),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            GroupCaption('main_work'.tr()),
            ChoiceGrid<MainWork>(
              // Roj is no longer a kind of worker; one saved as roj before
              // still shows it.
              options: [
                for (final w in MainWork.values)
                  if (w != MainWork.daily || widget.worker?.mainWork == MainWork.daily) w,
              ],
              selected: work,
              label: (w) => w.displayName,
              icon: (w) => switch (w) {
                MainWork.molder => Icons.grid_view_rounded,
                MainWork.loader => Icons.layers_rounded,
                MainWork.stacker => Icons.view_agenda_rounded,
                MainWork.unloader => Icons.local_fire_department_rounded,
                MainWork.driver => Icons.local_shipping_rounded,
                MainWork.daily => Icons.wb_sunny_rounded,
                MainWork.other => Icons.more_horiz_rounded,
              },
              iconColor: (context, w) => switch (w) {
                MainWork.molder || MainWork.loader || MainWork.stacker => Tint.bricks.color(context),
                MainWork.unloader => Tint.fire.color(context),
                MainWork.driver => Tint.truck.color(context),
                MainWork.daily => Tint.money.color(context),
                MainWork.other => Tint.work.color(context),
              },
              onSelected: (w) => setState(() => _mainWork = w),
            ),
            if (work == null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
                child: Text('main_work_help'.tr(), style: context.text.bodySmall),
              ),
            if (work != null && work.hasOwnRate) ...[
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _rateController,
                labelText: work == MainWork.molder ? 'own_rate_molder'.tr() : 'own_rate_daily'.tr(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(decimals: 2)],
                prefixText: '₹ ',
                validator: (v) => Validators.amount(v, fieldLabel: 'rate'.tr(), allowZero: false),
              ),
            ],
            if (work != null && work.groupWork.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space2xl),
              _GroupRates(
                types: [for (final code in work.groupWork) ?core.factory.workType(code)],
                controllerFor: _groupRate,
              ),
            ],
            if (work == MainWork.driver) ...[
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _salaryController,
                labelText: 'monthly_salary'.tr(),
                helperText: 'monthly_salary_help'.tr(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(decimals: 2)],
                prefixText: '₹ ',
                validator: (v) => Validators.amount(v, fieldLabel: 'monthly_salary'.tr(), allowZero: false),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              DateField(
                label: 'salary_from'.tr(),
                value: _salaryFrom,
                firstDate: DateTime.now().subtract(const Duration(days: 400)),
                onChanged: (d) => setState(() => _salaryFrom = d),
              ),
            ],
            const SizedBox(height: AppTheme.space2xl),
            AppTextField(
              controller: _phoneController,
              labelText: 'whatsapp_number'.tr(),
              helperText: 'whatsapp_number_help'.tr(),
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            NoteCard(controller: _noteController, hint: 'note_optional'.tr()),
          ],
        ),
      ),
    );
  }
}

/// What the worker's group work pays. A rate set before shows as it is (the
/// owner or munim taps it to change it); a missing one must be typed here,
/// and is then used for every worker in that group.
class _GroupRates extends StatelessWidget {
  final List<WorkType> types;
  final TextEditingController Function(String code) controllerFor;

  const _GroupRates({required this.types, required this.controllerFor});

  @override
  Widget build(BuildContext context) {
    final set = types.where((t) => !rateMissing(t)).toList();
    final missing = types.where(rateMissing).toList();
    final canSet = canSetRates(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupCaption('group_rate_title'.tr()),
        if (set.isNotEmpty)
          GroupedSection(
            dividerIndent: AppTheme.spaceLg,
            children: [
              for (final type in set)
                GroupedRow(
                  title: type.label,
                  value: '${Formatters.formatCurrency(type.rate!)} / ${'rate_unit_${type.payUnit.value}'.tr()}',
                  onTap: canSet ? () => askRate(context, type) : null,
                ),
            ],
          ),
        for (final type in missing) ...[
          const SizedBox(height: AppTheme.spaceSm),
          AppTextField(
            controller: controllerFor(type.code!),
            labelText: type.label,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter(decimals: 2)],
            prefixText: '₹ ',
            suffixText: 'rate_unit_${type.payUnit.value}'.tr(),
            validator: (v) => Validators.amount(v, fieldLabel: type.label, allowZero: false),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.spaceSm, left: AppTheme.spaceXs),
          child: Text(
            missing.isEmpty ? 'group_rate_help'.tr() : 'group_rate_first_help'.tr(),
            style: context.text.bodySmall,
          ),
        ),
      ],
    );
  }
}
