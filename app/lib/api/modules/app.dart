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
}
