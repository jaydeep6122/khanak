import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khanak/helpers/toastNotifications.dart';

/// The number in the international form WhatsApp links need (91XXXXXXXXXX),
/// or null when [phone] is not an Indian mobile number.
String? whatsAppNumber(String? phone) {
  final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length == 10) return '91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return digits;
  if (digits.length == 11 && digits.startsWith('0')) return '91${digits.substring(1)}';
  return null;
}

/// Opens a WhatsApp chat with [phone] and [message] typed in, ready to send.
/// Shows a toast when the number is unusable or WhatsApp cannot open.
Future<void> openWhatsApp(String? phone, String message) async {
  final number = whatsAppNumber(phone);
  if (number == null) {
    showErrorToast('whatsapp_no_number'.tr());
    return;
  }
  final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    showErrorToast('whatsapp_open_failed'.tr());
  }
}
