import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

class AppApi {
  final Dio _dio;

  AppApi(this._dio);

  /// `{ platform, min_build, maintenance, store_url }`: builds below
  /// `min_build` must update before they can be used, and no build can be
  /// used while `maintenance` is true. Needs no sign-in, and still answers
  /// during maintenance.
  Future<Map<String, dynamic>> version(String platform) async {
    final response = await _dio.get(
      '/app/version',
      queryParameters: {'platform': platform},
    );
    return dataOf(response);
  }

  /// `{ whatsapp, terms_url, privacy_url, delete_account_url }`: where to get
  /// help. `whatsapp` is digits with the country code, or null. Needs no
  /// sign-in.
  Future<Map<String, dynamic>> support() async => dataOf(await _dio.get('/app/support'));
}
