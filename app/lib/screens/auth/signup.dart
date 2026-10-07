import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/support.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/auth/authLayout.dart';
import 'package:khanak/screens/auth/sessionRouter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final phone = _phoneController.text.trim();
    final ok = await auth.signup(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text,
      phone: phone.isEmpty ? null : phone,
    );
    if (!mounted) return;

    if (ok) {
      await openAfterSignIn(context);
    } else {
      showErrorToast(auth.error ?? 'signup_failed'.tr());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'signup_title'.tr(),
      subtitle: 'signup_subtitle'.tr(),
      showLogo: false,
      footer: AuthFooterLink(
        question: 'already_have_account'.tr(),
        action: 'login'.tr(),
        onTap: () => Navigator.of(context).pop(),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameController,
              labelText: 'your_name'.tr(),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.person_outline_rounded,
              autofillHints: const [AutofillHints.name],
              validator: (v) => Validators.required(v, 'your_name'.tr()),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _emailController,
              labelText: 'email'.tr(),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.mail_outline_rounded,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _phoneController,
              labelText: 'mobile_optional'.tr(),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.phone_outlined,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: Validators.phone,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _passwordController,
              labelText: 'password'.tr(),
              helperText: 'password_rule'.tr(),
              isPassword: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              validator: Validators.password,
            ),
            const SizedBox(height: AppTheme.space2xl),
            AppButton(text: 'create_account'.tr(), isLoading: _busy, onPressed: _submit),
            const SizedBox(height: AppTheme.spaceMd),
            Text('signup_agree'.tr(), textAlign: TextAlign.center, style: context.text.bodySmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () => openLegalPage(LegalPage.terms), child: Text('terms'.tr())),
                TextButton(onPressed: () => openLegalPage(LegalPage.privacy), child: Text('privacy_policy'.tr())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
