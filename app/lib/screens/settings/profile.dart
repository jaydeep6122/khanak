import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/support.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/auth/login.dart';
import 'package:khanak/screens/settings/changePassword.dart';

/// The signed-in person's own details: name and mobile, their password, and
/// deleting the account for good.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _user = context.read<Core>().auth.user!;
  late final _nameController = TextEditingController(text: _user.name);
  late final _phoneController = TextEditingController(text: _user.phone);
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final phone = _phoneController.text.trim();
    final ok = await auth.updateProfile(name: _nameController.text.trim(), phone: phone.isEmpty ? null : phone);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return showErrorToast(auth.error ?? 'error_generic'.tr());
    showSuccessToast('saved'.tr());
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount() async {
    final core = context.read<Core>();
    // An owner closes their factories for everyone they added, so say so.
    final ownsFactory = core.factory.factories.any((f) => f.role == MemberRole.owner);
    final sure = await showConfirmDialog(
      context,
      title: 'delete_account_title'.tr(),
      message: [
        'delete_account_message'.tr(),
        if (ownsFactory) 'delete_account_owner_message'.tr(),
      ].join('\n\n'),
      confirmText: 'delete_account'.tr(),
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!sure || !mounted) return;

    final deleted = await showDialog<bool>(context: context, builder: (_) => const _DeleteAccountDialog());
    if (deleted != true || !mounted) return;
    showSuccessToast('account_deleted'.tr());
    Navigator.of(context).pushAndRemoveUntil(getPageRoute(const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text('profile'.tr())),
      bottomNavigationBar: SaveBar(label: 'save'.tr(), isLoading: _busy, onPressed: _save),
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
                controller: _nameController,
                labelText: 'your_name'.tr(),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => Validators.required(v, 'your_name'.tr()),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                controller: _phoneController,
                labelText: 'mobile_optional'.tr(),
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: Validators.phone,
              ),
              const SizedBox(height: AppTheme.spaceLg),
              // The email is the sign-in name, so it is shown, not changed.
              AppTextField(
                initialValue: _user.email,
                labelText: 'email'.tr(),
                prefixIcon: Icons.mail_outline_rounded,
                enabled: false,
              ),
              const SizedBox(height: AppTheme.space2xl),
              GroupedSection(
                caption: 'account'.tr(),
                children: [
                  GroupedRow(
                    leading: const TintIcon(tint: Tint.neutral, icon: Icons.lock_outline_rounded),
                    title: 'change_password'.tr(),
                    onTap: () => Navigator.of(context).push(getPageRoute(const ChangePasswordScreen())),
                  ),
                  GroupedRow(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: colors.dangerSoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.delete_forever_rounded, size: 19, color: colors.danger),
                    ),
                    title: 'delete_account'.tr(),
                    titleColor: colors.danger,
                    subtitle: 'delete_account_desc'.tr(),
                    onTap: _deleteAccount,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextButton(
                onPressed: () => openLegalPage(LegalPage.deleteAccount),
                child: Text('delete_account_what_happens'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for the password, then deletes the account. Pops true once deleted.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final ok = await auth.deleteAccount(_passwordController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return showErrorToast(auth.error ?? 'error_generic'.tr());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('delete_account_confirm_title'.tr()),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _passwordController,
          labelText: 'password'.tr(),
          isPassword: true,
          autofocus: true,
          prefixIcon: Icons.lock_outline_rounded,
          validator: (v) => Validators.required(v, 'password'.tr()),
          onFieldSubmitted: (_) => _delete(),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceLg),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'cancel'.tr(),
                variant: AppButtonVariant.outline,
                compact: true,
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: AppButton(
                text: 'delete_account'.tr(),
                variant: AppButtonVariant.danger,
                compact: true,
                isLoading: _busy,
                onPressed: _delete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
