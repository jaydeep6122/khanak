import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';

/// A new password, after the current one. Every other phone signed in with
/// this account is signed out; this one stays signed in.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final ok = await auth.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return showErrorToast(auth.error ?? 'error_generic'.tr());
    showSuccessToast('password_changed'.tr());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text('change_password'.tr())),
      bottomNavigationBar: SaveBar(label: 'change_password'.tr(), isLoading: _busy, onPressed: _submit),
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
              AppTextField(
                controller: _currentController,
                labelText: 'current_password'.tr(),
                isPassword: true,
                autofocus: true,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.lock_outline_rounded,
                autofillHints: const [AutofillHints.password],
                validator: (v) => Validators.required(v, 'current_password'.tr()),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _newController,
                labelText: 'new_password'.tr(),
                helperText: 'password_rule'.tr(),
                isPassword: true,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.lock_reset_rounded,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
              ),
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _confirmController,
                labelText: 'confirm_password'.tr(),
                isPassword: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_reset_rounded,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => Validators.confirmPassword(v, _newController.text),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Text('change_password_note'.tr(), style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
