import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:khanak/storage/secure_storage.dart';
import 'package:khanak/storage/hive.dart';
import 'package:khanak/helpers/logger.dart';
import 'package:khanak/helpers/toastNotifications.dart';

class DioInstance {
  static final DioInstance _singleton = DioInstance._internal();

  DioInstance._internal();

  factory DioInstance() {
    return _singleton;
  }

  late Dio dio;
  late String baseURL;

  // Callback when session has expired and user needs to be logged out
  static VoidCallback? onSessionExpired;

  /// Called when the server answers that it is under maintenance.
  static VoidCallback? onMaintenance;

  /// The server's answer to every request while MAINTENANCE_MODE is on.
  static bool _isMaintenance(Object error) {
    if (error is! DioException) return false;
    final data = error.response?.data;
    return error.response?.statusCode == 503 &&
        data is Map &&
        data['code'] == 'maintenance';
  }

  /// Guards token refresh so that N concurrent 401s trigger exactly one
  /// `/auth/refresh` call. The backend rotates refresh tokens, so parallel
  /// refreshes would invalidate each other and log the user out spuriously.
  static Completer<bool?>? _refreshCompleter;

  /// Marker placed on a request that has already been replayed once, so a
  /// second 401 on the replay cannot start another refresh cycle.
  static const String _retriedFlag = '__vs_retried';

  /// Single-flight token refresh. Returns true when a fresh access token is
  /// available; false when the session is genuinely no longer valid; null
  /// when the server is under maintenance, which says nothing about the
  /// session.
  static Future<bool?> _refreshTokens(String baseURL) {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool?>();
    _refreshCompleter = completer;

    () async {
      bool? success = false;
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken != null) {
          final refreshDio = Dio(BaseOptions(baseUrl: baseURL));
          final refreshResponse = await refreshDio.post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );

          if (refreshResponse.statusCode == 200 ||
              refreshResponse.statusCode == 201) {
            final data = refreshResponse.data['data'];
            final newAccessToken = data['access_token'];
            final newRefreshToken = data['refresh_token'];

            if (newAccessToken != null && newRefreshToken != null) {
              await SecureStorage.setAccessToken(newAccessToken);
              await SecureStorage.setRefreshToken(newRefreshToken);
              success = true;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          logger('Token refresh failed: $e');
        }
        if (_isMaintenance(e)) success = null;
      }

      _refreshCompleter = null;
      completer.complete(success);
    }();

    return completer.future;
  }

  /// Set once the session has been torn down. A burst of parallel requests
  /// all failing to refresh must sign out — and navigate — exactly once;
  /// otherwise the second navigation lands while the first is still running
  /// and Navigator asserts on `!_debugLocked`.
  static bool _sessionEnded = false;

  /// Call when a new session starts, so a later expiry is acted on again.
  static void markSessionStarted() => _sessionEnded = false;

  /// Tear down the session. Only called when the refresh itself fails, never
  /// on an arbitrary 401 — an authorization failure on one endpoint should not
  /// destroy a valid session.
  static Future<void> _endSession() async {
    if (_sessionEnded) return;
    _sessionEnded = true;
    await SecureStorage.deleteAll();
    await clearBoxes();
    onSessionExpired?.call();
  }

  static Future<DioInstance> init({required String baseURL}) async {
    _singleton.baseURL = baseURL;

    BaseOptions options = BaseOptions(
      baseUrl: baseURL,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      // Without this an upload (business logo, signature) can hang forever.
      sendTimeout: const Duration(seconds: 60),
    );
    final dio = Dio(options);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (
          RequestOptions options,
          RequestInterceptorHandler requestHandler,
        ) async {
          if (kDebugMode) {
            logger('DIO Request: ${options.method} ${options.path}');
          }

          options.baseUrl = baseURL;

          // Attach device metadata headers
          options.headers['meta-platform'] =
              Platform.isAndroid ? 'android' : 'ios';
          options.headers['meta-os'] = Platform.operatingSystem;

          if (_checkIfRequiresAccessToken(options.path)) {
            final accessToken = await SecureStorage.getAccessToken();
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }

          return requestHandler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler responseHandler,
        ) {
          if (kDebugMode) {
            logger(
              'DIO Response: ${response.statusCode} for ${response.requestOptions.path}',
            );
          }
          return responseHandler.next(response);
        },
        onError: (
          DioException error,
          ErrorInterceptorHandler errorHandler,
        ) async {
          if (kDebugMode) {
            logger(
              'DIO Error: ${error.requestOptions.path} - ${error.response?.statusCode} - ${error.response?.data}',
            );
          }

          // Show Toast notification on connection error
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            showErrorToast('error_network'.tr());
            return errorHandler.next(error);
          }

          if (_isMaintenance(error)) {
            onMaintenance?.call();
            return errorHandler.next(error);
          }

          // Handle 401 Unauthorized
          if (error.response?.statusCode == 401) {
            final options = error.requestOptions;
            final alreadyRetried = options.extra[_retriedFlag] == true;

            // Only attempt a refresh for authenticated endpoints, and never
            // for a request we have already replayed once.
            if (_checkIfRequiresAccessToken(options.path) && !alreadyRetried) {
              final refreshed = await _refreshTokens(baseURL);

              // Under maintenance: keep the session for when it is over.
              if (refreshed == null) {
                onMaintenance?.call();
                return errorHandler.next(error);
              }

              if (!refreshed) {
                // The refresh itself failed — the session really is over.
                await _endSession();
                return errorHandler.next(error);
              }

              final newAccessToken = await SecureStorage.getAccessToken();
              if (newAccessToken == null) {
                await _endSession();
                return errorHandler.next(error);
              }

              options.headers['Authorization'] = 'Bearer $newAccessToken';
              options.extra[_retriedFlag] = true;

              try {
                final retryDio = Dio(BaseOptions(baseUrl: baseURL));
                final retryResponse = await retryDio.request(
                  options.path,
                  data: options.data,
                  queryParameters: options.queryParameters,
                  cancelToken: options.cancelToken,
                  onSendProgress: options.onSendProgress,
                  onReceiveProgress: options.onReceiveProgress,
                  options: Options(
                    method: options.method,
                    headers: options.headers,
                    contentType: options.contentType,
                    responseType: options.responseType,
                    followRedirects: options.followRedirects,
                    receiveDataWhenStatusError:
                        options.receiveDataWhenStatusError,
                    extra: options.extra,
                  ),
                );
                return errorHandler.resolve(retryResponse);
              } on DioException catch (retryError) {
                // A 401 on the replay means the fresh token is not accepted.
                if (retryError.response?.statusCode == 401) {
                  await _endSession();
                }
                return errorHandler.next(retryError);
              }
            }
          }

          return errorHandler.next(error);
        },
      ),
    );

    _singleton.dio = dio;
    return _singleton;
  }
}

/// Routes that work without an access token. A 401 from one of these is a
/// real answer (e.g. wrong password), never a reason to refresh the session.
const _publicPaths = [
  '/app/version',
  '/auth/login',
  '/auth/signup',
  '/auth/refresh',
  '/auth/logout',
  '/auth/password/forgot',
  '/auth/password/reset',
];

bool _checkIfRequiresAccessToken(String path) =>
    !_publicPaths.any(path.contains);
