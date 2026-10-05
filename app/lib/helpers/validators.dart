import 'package:easy_localization/easy_localization.dart';

/// Form validators. Each returns an error message, or null when valid.
/// Optional fields pass when empty.
class Validators {
  Validators._();

  static bool _isEmpty(String? value) => value == null || value.trim().isEmpty;

  static String? required(String? value, String fieldLabel) => _isEmpty(value)
      ? 'validation_required'.tr(namedArgs: {'field': fieldLabel})
      : null;

  static String? email(String? value, {bool isRequired = true}) {
    if (_isEmpty(value)) return isRequired ? 'validation_email_required'.tr() : null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$').hasMatch(value!.trim());
    return valid ? null : 'validation_email_invalid'.tr();
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'validation_password_required'.tr();
    if (value.length < 8) return 'validation_password_short'.tr();
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'validation_confirm_password_required'.tr();
    return value == password ? null : 'validation_passwords_mismatch'.tr();
  }

  /// 10-digit Indian mobile number, optionally with +91 or a leading 0.
  static String? phone(String? value, {bool isRequired = false}) {
    if (_isEmpty(value)) return isRequired ? 'validation_phone_required'.tr() : null;
    final digits = value!.replaceAll(RegExp(r'[\s-]'), '');
    final valid = RegExp(r'^(\+91|0)?[6-9]\d{9}$').hasMatch(digits);
    return valid ? null : 'validation_phone_invalid'.tr();
  }

  static String? otp(String? value) {
    if (_isEmpty(value)) return 'validation_otp_required'.tr();
    return RegExp(r'^\d{6}$').hasMatch(value!.trim()) ? null : 'validation_otp_invalid'.tr();
  }

  /// A rupee amount with at most 2 decimals.
  static String? amount(
    String? value, {
    required String fieldLabel,
    bool isRequired = true,
    bool allowZero = true,
    bool allowNegative = false,
    double? max,
  }) {
    if (_isEmpty(value)) {
      return isRequired ? 'validation_required'.tr(namedArgs: {'field': fieldLabel}) : null;
    }
    final text = value!.trim().replaceAll(',', '');
    final number = double.tryParse(text);
    if (number == null || !RegExp(r'^-?\d*\.?\d{0,2}$').hasMatch(text)) {
      return 'validation_amount_invalid'.tr();
    }
    if (!allowNegative && number < 0) return 'validation_amount_negative'.tr();
    if (!allowZero && number == 0) return 'validation_amount_zero'.tr();
    if (max != null && number > max + 0.0001) {
      return 'validation_amount_max'.tr(namedArgs: {'max': max.toStringAsFixed(2)});
    }
    return null;
  }

  /// A whole number of bricks, more than zero.
  static String? bricks(String? value) {
    if (_isEmpty(value)) return 'validation_bricks_required'.tr();
    final number = int.tryParse(value!.trim().replaceAll(',', ''));
    if (number == null) return 'validation_bricks_invalid'.tr();
    return number > 0 ? null : 'validation_bricks_zero'.tr();
  }

  /// A quantity greater than zero with at most 3 decimals.
  static String? quantity(String? value, {bool isRequired = true}) {
    if (_isEmpty(value)) return isRequired ? 'validation_quantity_required'.tr() : null;
    final text = value!.trim();
    final number = double.tryParse(text);
    if (number == null || !RegExp(r'^\d*\.?\d{0,3}$').hasMatch(text)) {
      return 'validation_quantity_invalid'.tr();
    }
    return number > 0 ? null : 'validation_quantity_zero'.tr();
  }

}
