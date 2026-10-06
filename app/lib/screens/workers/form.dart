import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/optionSheet.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/worker.dart';

/// A worker's details, kept short: the name, what they mainly do and their
/// own rate (per 1000 bricks or per day; a driver's monthly salary instead)
/// are required; a phone number and a note are optional. No photo. All of
/// the worker's pay is worked out from their own rate: in group work they
/// get their share of the bricks at it.
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

  /// Per 1000 bricks or per day. Follows the main work (per day for roj)
  /// until picked by hand.
  late PayUnit _rateUnit = widget.worker?.rateUnit ?? _defaultUnit(_mainWork);
  late bool _rateUnitPicked = widget.worker?.rateUnit != null;
  late DateTime _salaryFrom = widget.worker?.salaryFrom ?? DateTime.now();
  bool _busy = false;

  /// Set once save was tapped, so a missing main work shows in red.
  bool _tried = false;

  static PayUnit _defaultUnit(MainWork? work) => work == MainWork.daily ? PayUnit.perDay : PayUnit.per1000;

  @override
  void dispose() {
    for (final controller in [_nameController, _phoneController, _noteController, _rateController, _salaryController]) {
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
    setState(() => _tried = true);
    final valid = _formKey.currentState!.validate();
    if (_mainWork == null) return showErrorToast('pick_main_work_first'.tr());
    if (!valid) return;

    final work = _mainWork!;
    final driver = work.hasSalary;
    final module = context.read<Core>().worker;
    setState(() => _busy = true);
    final saved = await module.saveWorker({
      'name': _nameController.text.trim(),
      'main_work': work.value,
      'rate': driver ? null : apiAmount(_rateController.text),
      'rate_unit': driver ? null : _rateUnit.value,
      'phone': _text(_phoneController),
      'note': _text(_noteController),
      'monthly_salary': driver ? apiAmount(_salaryController.text) : null,
      'salary_from': driver ? apiDate(_salaryFrom) : null,
    }, workerId: widget.worker?.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('saved'.tr());
    Navigator.of(context).pop(saved);
  }

  static IconData _icon(MainWork work) => switch (work) {
    MainWork.molder => Icons.grid_view_rounded,
    MainWork.loader => Icons.layers_rounded,
    MainWork.stacker => Icons.view_agenda_rounded,
    MainWork.unloader => Icons.local_fire_department_rounded,
    MainWork.driver => Icons.local_shipping_rounded,
    MainWork.daily => Icons.wb_sunny_rounded,
    MainWork.other => Icons.more_horiz_rounded,
  };

  static Tint _tint(MainWork work) => switch (work) {
    MainWork.molder || MainWork.loader || MainWork.stacker => Tint.bricks,
    MainWork.unloader => Tint.fire,
    MainWork.driver => Tint.truck,
    MainWork.daily => Tint.money,
    MainWork.other => Tint.work,
  };

  Future<void> _pickMainWork() async {
    FocusScope.of(context).unfocus();
    final work = await pickOption<MainWork>(
      context,
      title: 'main_work'.tr(),
      // Roj is no longer a kind of worker; one saved as roj before still
      // shows it.
      options: [
        for (final w in MainWork.values)
          if (w != MainWork.daily || widget.worker?.mainWork == MainWork.daily) w,
      ],
      label: (w) => w.displayName,
      isSelected: (w) => w == _mainWork,
      leading: (w) => TintIcon(tint: _tint(w), icon: _icon(w)),
    );
    if (work == null || !mounted) return;
    setState(() {
      _mainWork = work;
      if (!_rateUnitPicked) _rateUnit = _defaultUnit(work);
    });
  }

  @override
  Widget build(BuildContext context) {
    final work = _mainWork;

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
            GroupedSection(
              caption: 'main_work'.tr(),
              children: [
                GroupedRow(
                  leading: work == null
                      ? const TintIcon(tint: Tint.neutral, icon: Icons.work_outline_rounded)
                      : TintIcon(tint: _tint(work), icon: _icon(work)),
                  title: work?.displayName ?? 'main_work_help'.tr(),
                  placeholder: work == null && !_tried,
                  titleColor: work == null && _tried ? context.colors.danger : null,
                  onTap: _pickMainWork,
                ),
              ],
            ),
            if (work != null && !work.hasSalary) ...[
              const SizedBox(height: AppTheme.spaceLg),
              GroupCaption('own_rate'.tr()),
              SegmentedControl<PayUnit>(
                options: const [PayUnit.per1000, PayUnit.perDay],
                selected: _rateUnit,
                label: (unit) => 'own_rate_${unit.value}'.tr(),
                onChanged: (unit) => setState(() {
                  _rateUnit = unit;
                  _rateUnitPicked = true;
                }),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppTextField(
                controller: _rateController,
                labelText: 'rate'.tr(),
                helperText: _rateUnit == PayUnit.per1000 ? 'own_rate_per_1000_help'.tr() : 'own_rate_per_day_help'.tr(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter(decimals: 2)],
                prefixText: '₹ ',
                suffixText: 'rate_unit_${_rateUnit.value}'.tr(),
                validator: (v) => Validators.amount(v, fieldLabel: 'rate'.tr(), allowZero: false),
              ),
            ],
            if (work != null && work.hasSalary) ...[
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
