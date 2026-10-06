import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/auth/sessionRouter.dart';
import 'package:khanak/screens/home/home.dart';
import 'package:khanak/types/factory.dart';

/// Sets up a kiln: its name and place, and whether a season is running.
/// With [isOnboarding] it is the first screen after signing up. With
/// [factory] it edits that factory's details.
class FactoryFormScreen extends StatefulWidget {
  final bool isOnboarding;
  final Factory? factory;

  const FactoryFormScreen({super.key, this.isOnboarding = false, this.factory});

  @override
  State<FactoryFormScreen> createState() => _FactoryFormScreenState();
}

class _FactoryFormScreenState extends State<FactoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.factory?.name);
  late final _ownerController = TextEditingController(
    text: widget.factory?.ownerName ?? context.read<Core>().auth.user?.name,
  );
  late final _cityController = TextEditingController(text: widget.factory?.city);
  bool _seasonRunning = true;
  DateTime _seasonStartedOn = DateTime.now();
  bool _busy = false;

  bool get _editing => widget.factory != null;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String? _orNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final factory = context.read<Core>().factory;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);

    final data = {
      'name': _nameController.text.trim(),
      'owner_name': _orNull(_ownerController),
      'city': _orNull(_cityController),
    };

    if (_editing) {
      final ok = await factory.updateFactory(data);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return showErrorToast(factory.error ?? 'error_generic'.tr());
      showSuccessToast('saved'.tr());
      navigator.pop();
      return;
    }

    final created = await factory.createFactory({
      ...data,
      if (_seasonRunning) 'season_started_on': apiDate(_seasonStartedOn),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (created == null) return showErrorToast(factory.error ?? 'error_generic'.tr());

    // Straight in: each worker's rate is set with the worker, and a group's
    // rate the first time that group is paid.
    navigator.pushAndRemoveUntil(getPageRoute(const HomeScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(_editing ? 'factory_edit'.tr() : 'factory_new'.tr()),
      ),
      bottomNavigationBar: SaveBar(
        label: _editing ? 'save'.tr() : 'factory_create'.tr(),
        isLoading: _busy,
        onPressed: _submit,
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceXl,
              AppTheme.spaceSm,
              AppTheme.spaceXl,
              AppTheme.fabClearance,
            ),
            children: [
              if (widget.isOnboarding) ...[
                Text('factory_onboarding_title'.tr(), style: context.text.headlineSmall),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'factory_onboarding_subtitle'.tr(),
                  style: context.text.bodyLarge?.copyWith(color: colors.inkSecondary),
                ),
                const SizedBox(height: AppTheme.space2xl),
              ],
              AppTextField(
                controller: _nameController,
                labelText: 'factory_name'.tr(),
                hintText: 'factory_name_hint'.tr(),
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.factory_outlined,
                validator: (v) => Validators.required(v, 'factory_name'.tr()),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _ownerController,
                labelText: 'owner_name'.tr(),
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _cityController,
                labelText: 'city_village'.tr(),
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.place_outlined,
              ),
              if (!_editing) ...[
                const SizedBox(height: AppTheme.space2xl),
                FieldLabel('season_running_question'.tr()),
                ChoiceRow<bool>(
                  options: const [true, false],
                  selected: _seasonRunning,
                  label: (running) => running ? 'season_running_yes'.tr() : 'season_running_no'.tr(),
                  onSelected: (running) => setState(() => _seasonRunning = running),
                ),
                if (_seasonRunning) ...[
                  const SizedBox(height: AppTheme.spaceLg),
                  DateField(
                    label: 'season_started_on'.tr(),
                    value: _seasonStartedOn,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    onChanged: (date) => setState(() => _seasonStartedOn = date),
                  ),
                ],
              ],
              if (widget.isOnboarding) ...[
                const SizedBox(height: AppTheme.space2xl),
                Text('factory_added_by_owner'.tr(), style: context.text.bodyMedium, textAlign: TextAlign.center),
                TextButton(onPressed: _busy ? null : () => openAfterSignIn(context), child: Text('check_again'.tr())),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
