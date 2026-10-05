import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/auth/authLayout.dart';
import 'package:khanak/screens/auth/forgotPassword.dart';
import 'package:khanak/screens/auth/sessionRouter.dart';
import 'package:khanak/screens/auth/signup.dart';
import 'package:khanak/storage/hive/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: UserBox.getLastLoginEmail());
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final ok = await auth.login(
      _emailController.text.trim().toLowerCase(),
      _passwordController.text,
    );
    if (!mounted) return;

    if (ok) {
      await openAfterSignIn(context);
    } else {
      showErrorToast(auth.error ?? 'login_failed'.tr());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'login_title'.tr(),
      subtitle: 'login_subtitle'.tr(),
      footer: AuthFooterLink(
        question: 'dont_have_account'.tr(),
        action: 'signup'.tr(),
        onTap: () => Navigator.of(context).push(getPageRoute(const SignupScreen())),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              controller: _passwordController,
              labelText: 'password'.tr(),
              isPassword: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'validation_password_required'.tr()
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  getPageRoute(
                    ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
                  ),
                ),
                child: Text('forgot_password'.tr()),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(text: 'login'.tr(), isLoading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
