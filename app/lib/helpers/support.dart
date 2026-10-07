import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khanak/api/api.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/helpers/toastNotifications.dart';

/// The web pages the server keeps: terms, privacy policy, and how to delete
/// an account. They are served next to the API, so no lookup is needed.
enum LegalPage {
  terms('terms'),
  privacy('privacy'),
  deleteAccount('delete-account');

  const LegalPage(this.path);
  final String path;

  Uri get url => Uri.parse(AppConstants.apiBaseUrl).resolve('/legal/$path');
}

/// Opens [page] in the browser.
Future<void> openLegalPage(LegalPage page) async {
  if (!await launchUrl(page.url, mode: LaunchMode.externalApplication)) {
    showErrorToast('link_open_failed'.tr());
  }
}

/// Opens a WhatsApp chat with Khanak's support number, which the server
/// supplies so it can change without an app update.
Future<void> openSupportChat() async {
  String? number;
  try {
    number = (await Api.instance.app.support())['whatsapp'] as String?;
  } catch (_) {
    showErrorToast('error_network'.tr());
    return;
  }
  if (number == null || number.isEmpty) {
    showErrorToast('support_unavailable'.tr());
    return;
  }
  final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent('support_greeting'.tr())}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    showErrorToast('whatsapp_open_failed'.tr());
  }
}
