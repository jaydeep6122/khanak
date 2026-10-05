import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/worker.dart';

/// A worker's details. What they mainly do comes first and is required, and
/// so is what they are paid: no two molders are paid alike, so a molder and
/// a day worker each have their own rate, and a driver a monthly salary.
/// No photo: a nickname or village tells two Rameshes apart.
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
  late final _nicknameController = TextEditingController(text: widget.worker?.nickname);
  late final _villageController = TextEditingController(text: widget.worker?.village);
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

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _nicknameController,
      _villageController,
      _phoneController,
      _noteController,
      _rateController,
      _salaryController,
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
    final module = context.read<Core>().worker;
    setState(() => _busy = true);
    final saved = await module.saveWorker({
      'name': _nameController.text.trim(),
      'main_work': work.value,
      'rate': work.hasOwnRate ? apiAmount(_rateController.text) : null,
      'nickname': _text(_nicknameController),
      'village': _text(_villageController),
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

  @override
  Widget build(BuildContext context) {
    final work = _mainWork;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(widget.worker == null ? 'worker_new'.tr() : 'worker_edit'.tr())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
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
            FieldLabel('main_work'.tr()),
            ChoiceRow<MainWork>(
              options: MainWork.values,
              selected: work,
              label: (w) => w.displayName,
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
            if (work != null && work != MainWork.driver && !work.hasOwnRate && work != MainWork.other)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm, left: AppTheme.spaceXs),
                child: Text('group_rate_help'.tr(), style: context.text.bodySmall?.copyWith(color: colors.inkSecondary)),
              ),
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
              controller: _nicknameController,
              labelText: 'nickname'.tr(),
              hintText: 'nickname_hint'.tr(),
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _villageController,
              labelText: 'village'.tr(),
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.place_outlined,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _phoneController,
              labelText: 'whatsapp_number'.tr(),
              helperText: 'whatsapp_number_help'.tr(),
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _noteController,
              labelText: 'note_optional'.tr(),
              maxLines: 2,
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
