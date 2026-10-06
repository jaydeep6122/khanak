import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/factory.dart';

/// Cash left with a supervisor before the owner goes away. The supervisor's
/// advances are then paid from it.
class HandOverScreen extends StatefulWidget {
  const HandOverScreen({super.key});

  @override
  State<HandOverScreen> createState() => _HandOverScreenState();
}

class _HandOverScreenState extends State<HandOverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Member? _holder;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_holder == null) return showErrorToast('pick_supervisor_first'.tr());
    final report = context.read<Core>().report;
    setState(() => _busy = true);
    final ok = await report.handOver(
      holderId: _holder!.userId,
      kind: 'given',
      date: apiDate(_date),
      amount: apiAmount(_amountController.text)!,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return showErrorToast(report.error ?? 'error_generic'.tr());
    showSuccessToast('cash_given_done'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final members = (context.watch<Core>().factory.members.value ?? const <Member>[])
        .where((m) => m.role != MemberRole.owner)
        .toList();

    final amount = double.tryParse(_amountController.text) ?? 0;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text('give_cash'.tr()),
        actions: [DatePill(value: _date, onChanged: (d) => setState(() => _date = d))],
      ),
      bottomNavigationBar: SaveBar(
        label: 'give_cash'.tr(),
        trailing: amount > 0 ? Formatters.formatCurrency(amount) : null,
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
            FieldLabel('to_whom'.tr()),
            if (members.isEmpty)
              Text('no_supervisors_yet'.tr(), style: context.text.bodyMedium)
            else
              ChoiceRow<Member>(
                options: members,
                selected: _holder,
                label: (m) => m.name,
                icon: (_) => Icons.person_rounded,
                onSelected: (m) => setState(() => _holder = m),
              ),
            const SizedBox(height: AppTheme.space3xl),
            BigNumberField(
              controller: _amountController,
              label: 'amount'.tr(),
              prefix: '₹',
              decimal: true,
              quickAdds: const [5000, 10000, 20000],
              validator: (v) => Validators.amount(v, fieldLabel: 'amount'.tr(), allowZero: false),
            ),
            const SizedBox(height: AppTheme.space2xl),
            NoteCard(controller: _noteController, hint: 'note_optional'.tr()),
          ],
        ),
      ),
    );
  }
}
