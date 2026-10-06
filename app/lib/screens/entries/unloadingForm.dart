import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/optionSheet.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/tint.dart';
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

  /// Which kiln the fired bricks came out of; required.
  Kiln? _kiln;
  GroupDraft? _group;
  double? _savedRate;

  /// Set once save was tapped, so missing choices show in red.
  bool _tried = false;
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
    await Future.wait([core.factory.fetchWorkTypes(), core.factory.fetchKilns(), core.worker.fetchWorkers()]);
    final type = core.factory.workType('unloading');
    if (type != null) _group = GroupDraft(type: type);
    final kilns = _activeKilns(core);
    if (kilns.length == 1) _kiln = kilns.first;

    if (widget.unloadingId != null) {
      final unloading = await core.entry.fetchUnloading(widget.unloadingId!);
      if (unloading != null) {
        _date = unloading.unloadedOn;
        _cancelled = unloading.isCancelled;
        _kiln =
            core.factory.kilns.value?.where((k) => k.id == unloading.kilnId).firstOrNull ??
            (unloading.kilnId == null
                ? null
                : Kiln(id: unloading.kilnId!, name: unloading.kilnName ?? '', isActive: true));
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

  List<Kiln> _activeKilns(Core core) => (core.factory.kilns.value ?? const <Kiln>[]).where((k) => k.isActive).toList();

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    final valid = _formKey.currentState!.validate();
    if (_kiln == null) return showErrorToast('pick_kiln_first'.tr());
    if (!valid) return;
    final group = _group!;
    if (!await ensureGroupRate(context, group, keptOrCurrentRate(_savedRate, group.type)) || !mounted) return;
    setState(() {});
    final total = group.total(bricks: _bricks, rate: keptOrCurrentRate(_savedRate, group.type));
    if (!group.fits(total)) return showErrorToast('shares_too_much'.tr());

    final module = context.read<Core>().entry;
    setState(() => _busy = true);
    final saved = await module.saveUnloading({
      'unloaded_on': apiDate(_date),
      'kiln_id': _kiln!.id,
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

  Future<void> _pickKiln(List<Kiln> kilns) async {
    final kiln = await pickOption<Kiln>(
      context,
      title: 'from_which_kiln'.tr(),
      options: kilns,
      label: (k) => k.name,
      isSelected: (k) => k.id == _kiln?.id,
      tint: Tint.fire,
      empty: 'no_kilns_yet'.tr(),
    );
    if (kiln != null) setState(() => _kiln = kiln);
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
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const LoadingIndicator(),
      );
    }

    final colors = context.colors;
    final group = _group!;
    final rate = keptOrCurrentRate(_savedRate, group.type);
    final total = group.workers.isEmpty ? 0.0 : group.total(bricks: _bricks, rate: rate);
    final kilns = _activeKilns(core);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.unloadingId != null && !_cancelled)
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
        trailing: total > 0 ? Formatters.formatCurrency(total) : null,
        isLoading: _busy,
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceXl,
            AppTheme.spaceLg,
            AppTheme.spaceXl,
            AppTheme.fabClearance,
          ),
          children: [
            BigNumberField(
              controller: _quantityController,
              label: 'bricks_taken_out'.tr(),
              quickAdds: const [1000, 5000, 10000],
              validator: Validators.bricks,
            ),
            const SizedBox(height: AppTheme.space2xl),
            GroupedSection(
              children: [
                GroupedRow(
                  leading: TintIcon(tint: _kiln == null && _tried ? Tint.neutral : Tint.fire),
                  label: 'kiln_short'.tr(),
                  title: _kiln?.name ?? 'pick_kiln'.tr(),
                  titleColor: _kiln == null ? (_tried ? colors.danger : colors.primary) : null,
                  onTap: () => _pickKiln(kilns),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            GroupEditor(
              title: 'unloaders'.tr(),
              group: group,
              role: MainWork.unloader,
              typeChoices: const [],
              bricks: _bricks,
              trips: null,
              rate: rate,
              canChangeAmounts: !core.isSupervisor,
              missing: _tried && group.workers.isEmpty,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            NoteCard(controller: _noteController, hint: 'note_optional'.tr()),
          ],
        ),
      ),
    );
  }
}
