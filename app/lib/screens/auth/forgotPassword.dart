import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/screens/auth/authLayout.dart';
import 'package:khanak/screens/auth/sessionRouter.dart';

/// Two steps: enter email to get a 6-digit code, then the code and a new
/// password. Success signs the user in.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendDelay = 60;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (!_codeSent && !_emailFormKey.currentState!.validate()) return;

    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final ok = await auth.requestPasswordReset(_email);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      showErrorToast(auth.error ?? 'error_generic'.tr());
      return;
    }
    showSuccessToast('reset_code_sent'.tr(namedArgs: {'email': _email}));
    setState(() => _codeSent = true);
    _startResendTimer();
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (!_resetFormKey.currentState!.validate()) return;

    final auth = context.read<Core>().auth;
    setState(() => _busy = true);
    final ok = await auth.resetPassword(
      email: _email,
      code: _codeController.text.trim(),
      newPassword: _passwordController.text,
    );
    if (!mounted) return;

    if (ok) {
      showSuccessToast('password_reset_done'.tr());
      await openAfterSignIn(context);
    } else {
      showErrorToast(auth.error ?? 'error_generic'.tr());
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_codeSent) {
      return AuthLayout(
        title: 'forgot_password_title'.tr(),
        subtitle: 'forgot_password_subtitle'.tr(),
        showLogo: false,
        child: Form(
          key: _emailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _emailController,
                labelText: 'email'.tr(),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.mail_outline_rounded,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _sendCode(),
                validator: Validators.email,
              ),
              const SizedBox(height: AppTheme.space2xl),
              AppButton(text: 'send_code'.tr(), isLoading: _busy, onPressed: _sendCode),
            ],
          ),
        ),
      );
    }

    return AuthLayout(
      title: 'reset_password_title'.tr(),
      subtitle: 'reset_password_subtitle'.tr(namedArgs: {'email': _email}),
      showLogo: false,
      footer: Column(
        children: [
          TextButton(
            onPressed: _busy || _resendIn > 0 ? null : _sendCode,
            child: Text(
              _resendIn > 0
                  ? 'resend_code_in'.tr(namedArgs: {'seconds': '$_resendIn'})
                  : 'resend_code'.tr(),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _codeSent = false),
            child: Text('change_email'.tr()),
          ),
        ],
      ),
      child: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _codeController,
              labelText: 'reset_code'.tr(),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.pin_outlined,
              maxLength: 6,
              autofocus: true,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.otp,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _passwordController,
              labelText: 'new_password'.tr(),
              helperText: 'password_rule'.tr(),
              isPassword: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _reset(),
              validator: Validators.password,
            ),
            const SizedBox(height: AppTheme.space2xl),
            AppButton(text: 'reset_password'.tr(), isLoading: _busy, onPressed: _reset),
          ],
        ),
      ),
    );
  }
}
