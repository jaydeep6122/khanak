import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/trade.dart';

/// Picks a customer or supplier ([kind]), or adds a new one on the spot:
/// most are one-off, so there is no setting them up first. Null when dismissed.
Future<Party?> pickParty(BuildContext context, {required String kind, required String title}) {
  context.read<Core>().trade.fetchParties();
  return showModalBottomSheet<Party>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _PartyPicker(kind: kind, title: title)),
  );
}

class _PartyPicker extends StatefulWidget {
  final String kind;
  final String title;

  const _PartyPicker({required this.kind, required this.title});

  @override
  State<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends State<_PartyPicker> {
  String _search = '';

  Future<void> _addNew() async {
    final party = await showDialog<Party>(
      context: context,
      builder: (_) => _NewPartyDialog(kind: widget.kind, initialName: _search),
    );
    if (party != null && mounted) Navigator.of(context).pop(party);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final query = _search.toLowerCase();
    final parties = (core.trade.parties.value ?? const <Party>[])
        .where((p) => p.kind == widget.kind && p.isActive)
        .where(
          (p) =>
              query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              (p.phone ?? '').contains(query) ||
              (p.village ?? '').toLowerCase().contains(query),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceSm),
          child: Row(
            children: [
              Expanded(child: Text(widget.title, style: context.text.titleLarge)),
              TextButton.icon(
                onPressed: _addNew,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: Text(widget.kind == 'customer' ? 'customer_new'.tr() : 'supplier_new'.tr()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
          child: TextField(
            onChanged: (value) => setState(() => _search = value.trim()),
            decoration: InputDecoration(
              hintText: 'search_party'.tr(),
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Expanded(
          child: core.trade.parties.value == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: parties.length + 1,
                  itemBuilder: (context, index) {
                    if (index == parties.length) {
                      return Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        child: AppButton(
                          text: widget.kind == 'customer' ? 'customer_new'.tr() : 'supplier_new'.tr(),
                          icon: Icons.person_add_alt_1_rounded,
                          variant: AppButtonVariant.outline,
                          onPressed: _addNew,
                        ),
                      );
                    }
                    final party = parties[index];
                    return ListTile(
                      minVerticalPadding: 12,
                      leading: InitialBadge(letter: party.name.isEmpty ? '?' : party.name[0].toUpperCase()),
                      title: Text(party.name, style: context.text.titleMedium),
                      subtitle: Text([party.phone, party.village].whereType<String>().join(' · ')),
                      trailing: party.balance.abs() < 0.005
                          ? null
                          : Text(
                              Formatters.formatCurrency(party.balance.abs()),
                              style: context.text.titleSmall?.copyWith(
                                color: party.balance > 0 ? context.colors.success : context.colors.danger,
                              ),
                            ),
                      onTap: () => Navigator.of(context).pop(party),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NewPartyDialog extends StatefulWidget {
  final String kind;
  final String initialName;

  const _NewPartyDialog({required this.kind, required this.initialName});

  @override
  State<_NewPartyDialog> createState() => _NewPartyDialogState();
}

class _NewPartyDialogState extends State<_NewPartyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName);
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final trade = context.read<Core>().trade;
    setState(() => _busy = true);
    final phone = _phoneController.text.trim();
    final village = _villageController.text.trim();
    final party = await trade.createParty(
      kind: widget.kind,
      name: _nameController.text.trim(),
      phone: phone.isEmpty ? null : phone,
      village: village.isEmpty ? null : village,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (party == null) return showErrorToast(trade.error ?? 'error_generic'.tr());
    Navigator.of(context).pop(party);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.kind == 'customer' ? 'customer_new'.tr() : 'supplier_new'.tr()),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _nameController,
              labelText: 'party_name'.tr(),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'party_name'.tr()),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              controller: _phoneController,
              labelText: 'mobile_optional'.tr(),
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              controller: _villageController,
              labelText: 'village'.tr(),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
        FilledButton(onPressed: _busy ? null : _submit, child: Text('save'.tr())),
      ],
    );
  }
}
