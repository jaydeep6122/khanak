import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/entries/groupDraft.dart';
import 'package:khanak/screens/entries/stockWarnings.dart';
import 'package:khanak/types/worker.dart';

/// Fired bricks taken out of the kiln ("nikasi"): kiln stock down, fired
/// stock up, and the workers who took them out paid together. With
/// [unloadingId] it edits that unloading.
class UnloadingFormScreen extends StatefulWidget {
  final String? unloadingId;

  const UnloadingFormScreen({super.key, this.unloadingId});

  @override
  State<UnloadingFormScreen> createState() => _UnloadingFormScreenState();
}

class _UnloadingFormScreenState extends State<UnloadingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  GroupDraft? _group;
  double? _savedRate;
  bool _cancelled = false;
  bool _loading = true;
  bool _busy = false;

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
    await Future.wait([core.factory.fetchWorkTypes(), core.worker.fetchWorkers()]);
    final type = core.factory.workType('unloading');
    if (type != null) _group = GroupDraft(type: type);

    if (widget.unloadingId != null) {
      final unloading = await core.entry.fetchUnloading(widget.unloadingId!);
      if (unloading != null) {
        _date = unloading.unloadedOn;
        _cancelled = unloading.isCancelled;
        _quantityController.text = '${unloading.quantity}';
        _noteController.text = unloading.note ?? '';
        final group = unloading.groups.firstOrNull;
        if (group != null && type != null) {
          _savedRate = group.rate;
          final workers = [
            for (final share in group.workers)
              core.worker.byId(share.workerId) ?? Worker(id: share.workerId, name: share.name, isActive: true),
          ];
          _group = GroupDraft(type: type, workers: workers);
          final equal = splitEqually(group.total, workers.length);
          for (var i = 0; i < workers.length; i++) {
            if ((group.workers[i].amount - equal[i]).abs() > 0.001) {
              _group!.amounts[workers[i].id] = group.workers[i].amount;
            }
          }
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  int get _bricks => int.tryParse(_quantityController.text) ?? 0;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final group = _group!;
    final total = group.total(bricks: _bricks, rate: _savedRate ?? group.type.rate);
    if (!group.fits(total)) return showErrorToast('shares_too_much'.tr());

    final module = context.read<Core>().entry;
    setState(() => _busy = true);
    final saved = await module.saveUnloading({
      'unloaded_on': apiDate(_date),
      'quantity': _bricks,
      'groups': [if (group.workers.isNotEmpty) group.toJson(total)],
      'note': _noteController.text.trim(),
    }, unloadingId: widget.unloadingId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('unloading_saved'.tr());
    showStockWarnings(saved.warnings);
    Navigator.of(context).pop(true);
  }

  Future<void> _cancel() async {
    final reason = await showReasonDialog(
      context,
      title: 'cancel_unloading_title'.tr(),
      message: 'cancel_count_message'.tr(),
      confirmText: 'cancel_entry'.tr(),
    );
    if (reason == null || !mounted) return;
    final module = context.read<Core>().entry;
    final done = await module.cancelUnloading(widget.unloadingId!, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    if (done == null) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('entry_cancelled'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final title = widget.unloadingId == null ? 'action_unloading'.tr() : 'edit_unloading'.tr();
    if (_loading || _group == null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const LoadingIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.unloadingId != null && !_cancelled)
            IconButton(
              tooltip: 'cancel_entry'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: context.colors.danger),
              onPressed: _cancel,
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
            AppTextField(
              controller: _quantityController,
              labelText: 'bricks_taken_out'.tr(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: Icons.local_fire_department_rounded,
              validator: Validators.bricks,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            GroupEditor(
              title: 'unloaders'.tr(),
              group: _group!,
              role: MainWork.unloader,
              typeChoices: const [],
              bricks: _bricks,
              trips: null,
              rate: _savedRate ?? _group!.type.rate,
              canChangeAmounts: !core.isSupervisor,
              onChanged: () => setState(() {}),
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
