import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

class SecureStorage {
  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';

  static Future<String?> _read(String key) async {
    return await _storage.read(
      key: key,
      aOptions: const AndroidOptions(resetOnError: true),
    );
  }

  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _read(_accessTokenKey);
  }

  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }

  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
