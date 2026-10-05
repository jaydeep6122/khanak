import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

/// Totals for the owner and munim, and a supervisor's cash.
class ReportApi {
  final Dio _dio;

  ReportApi(this._dio);

  Future<Map<String, dynamic>> summary(String factoryId, {String? periodId}) async => dataOf(
    await _dio.get(
      '${factoryPath(factoryId)}/reports/summary',
      queryParameters: queryOf({'period_id': periodId}),
    ),
  );

  Future<Map<String, dynamic>> stock(String factoryId) async =>
      dataOf(await _dio.get('${factoryPath(factoryId)}/reports/stock'));

  /// Everything created, changed or cancelled on [date] ('YYYY-MM-DD').
  Future<List<Map<String, dynamic>>> activity(String factoryId, {String? date, String? userId}) async =>
      listOf(
        await _dio.get(
          '${factoryPath(factoryId)}/reports/activity',
          queryParameters: queryOf({'date': date, 'user_id': userId}),
        ),
      );

  // ---- Supervisor cash ----

  /// A supervisor gets only their own.
  Future<List<Map<String, dynamic>>> cashHolders(String factoryId) async =>
      listOf(await _dio.get('${factoryPath(factoryId)}/cash'));

  Future<Map<String, dynamic>> cashHolder(String factoryId, String holderId) async =>
      dataOf(await _dio.get('${factoryPath(factoryId)}/cash/$holderId'));

  Future<Map<String, dynamic>> handOver(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post('${factoryPath(factoryId)}/cash/handovers', data: data));

  /// Brings the holder's cash to zero: what is left comes back, or what they
  /// spent from their own pocket is paid back.
  Future<Map<String, dynamic>> settleCash(String factoryId, String holderId) async =>
      dataOf(await _dio.post('${factoryPath(factoryId)}/cash/$holderId/settle', data: {}));
}
