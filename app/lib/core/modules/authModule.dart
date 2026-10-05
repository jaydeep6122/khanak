import 'package:dio/dio.dart';
import 'package:khanak/api/api.dart';
import 'package:khanak/api/dio.dart';
import 'package:khanak/core/components/moduleBase.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/storage/hive.dart';
import 'package:khanak/storage/hive/cache.dart';
import 'package:khanak/storage/hive/user.dart';
import 'package:khanak/storage/secure_storage.dart';
import 'package:khanak/types/user.dart';

class AuthModule extends CoreModule {
  AuthModule(super.core);

  User? _user;
  User? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Stores the tokens (and the user, when included) from a session response.
  Future<void> _startSession(Map<String, dynamic> session) async {
    await SecureStorage.setAccessToken(session['access_token'] as String);
    await SecureStorage.setRefreshToken(session['refresh_token'] as String);
    // A fresh session: a later expiry should sign out again.
    DioInstance.markSessionStarted();
    final userJson = asMapOrNull(session['user']);
    if (userJson != null) {
      _user = User.fromJson(userJson);
      await CacheBox.setUser(_user!.toJson());
    }
    core.notify();
  }

  Future<bool> login(String email, String password) async {
    final session = await runSave(
      () => Api.instance.auth.login(email: email, password: password),
    );
    if (session == null) return false;
    await _startSession(session);
    await UserBox.setLastLoginEmail(email);
    return true;
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final session = await runSave(
      () => Api.instance.auth.signup(
        name: name,
        email: email,
        password: password,
        phone: phone,
      ),
    );
    if (session == null) return false;
    await _startSession(session);
    await UserBox.setLastLoginEmail(email);
    return true;
  }

  /// Restores a saved session. Uses the cached user offline, and refreshes it
  /// from the server when reachable.
  Future<bool> tryAutoLogin() async {
    final cachedUser = CacheBox.getUser();
    final token = await SecureStorage.getAccessToken();
    if (cachedUser == null || token == null) return false;

    _user = User.fromJson(cachedUser);
    core.notify();

    try {
      _user = User.fromJson(await Api.instance.auth.getMe());
      await CacheBox.setUser(_user!.toJson());
      core.notify();
    } on DioException {
      // Offline or server asleep: keep the cached user. A rejected session is
      // ended by the Dio interceptor, which clears the token.
      if (await SecureStorage.getAccessToken() == null) {
        _user = null;
        core.notify();
      }
    }
    return _user != null;
  }

  /// Emails a 6-digit code. Succeeds whether or not the email is registered.
  Future<bool> requestPasswordReset(String email) async {
    final done = await runSave(
      () => Api.instance.auth.forgotPassword(email).then((_) => true),
    );
    return done ?? false;
  }

  /// Sets a new password with the emailed code and signs in.
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final session = await runSave(
      () => Api.instance.auth.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
    if (session == null) return false;
    await _startSession(session);
    await UserBox.setLastLoginEmail(email);
    try {
      _user = User.fromJson(await Api.instance.auth.getMe());
      await CacheBox.setUser(_user!.toJson());
      core.notify();
    } catch (_) {}
    return true;
  }

  Future<bool> updateProfile({required String name, String? phone}) async {
    final json = await runSave(
      () => Api.instance.auth.updateMe({'name': name, 'phone': phone}),
    );
    if (json == null) return false;
    _user = User.fromJson(json);
    await CacheBox.setUser(_user!.toJson());
    core.notify();
    return true;
  }

  /// Every other device is signed out; this one gets a fresh session.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await runSave(
      () => Api.instance.auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
    if (session == null) return false;
    await _startSession(session);
    return true;
  }

  Future<void> logout({bool allDevices = false}) async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken != null) {
        await Api.instance.auth.logout(
          refreshToken: refreshToken,
          allDevices: allDevices,
        );
      }
    } catch (_) {
      // Signing out locally must work even when the server is unreachable.
    }
    await SecureStorage.deleteAll();
    await clearBoxes();
    handleSessionExpired();
  }

  void handleSessionExpired() {
    _user = null;
    core.factory.clearAll();
    core.resetFactoryData();
  }
}
