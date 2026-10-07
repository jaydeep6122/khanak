import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

const _deviceInfo = 'Khanak Android app';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  /// Returns `{ user, access_token, refresh_token, ... }`.
  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _dio.post(
      '/auth/signup',
      data: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
        'device_info': _deviceInfo,
      },
    );
    return dataOf(response);
  }

  /// Returns `{ user, access_token, refresh_token, ... }`.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password, 'device_info': _deviceInfo},
    );
    return dataOf(response);
  }

  Future<void> logout({
    required String refreshToken,
    bool allDevices = false,
  }) async {
    await _dio.post(
      '/auth/logout',
      data: {'refresh_token': refreshToken, 'all_devices': allDevices},
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    return dataOf(await _dio.get('/auth/me'));
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    return dataOf(await _dio.patch('/auth/me', data: data));
  }

  /// Returns a fresh session; every other session is signed out.
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post(
      '/auth/me/password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'device_info': _deviceInfo,
      },
    );
    return dataOf(response);
  }

  /// Wipes the account and signs it out on every device.
  Future<void> deleteAccount({required String password}) async {
    await _dio.post('/auth/me/delete', data: {'password': password});
  }

  /// Always succeeds, whether or not the email is registered.
  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/password/forgot', data: {'email': email});
  }

  /// Returns a fresh session.
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _dio.post(
      '/auth/password/reset',
      data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
        'device_info': _deviceInfo,
      },
    );
    return dataOf(response);
  }
}
