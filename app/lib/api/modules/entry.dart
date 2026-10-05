import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

/// Brick counts, kiln unloadings and work typed in by hand.
class EntryApi {
  final Dio _dio;

  EntryApi(this._dio);

  String _counts(String factoryId) => '${factoryPath(factoryId)}/brick-counts';
  String _unloadings(String factoryId) => '${factoryPath(factoryId)}/kiln-unloadings';
  String _work(String factoryId) => '${factoryPath(factoryId)}/work-entries';

  // ---- Brick counts ----

  Future<PageJson> brickCounts(String factoryId, {int offset = 0, int limit = 30, String? periodId}) async =>
      PageJson.of(
        await _dio.get(
          _counts(factoryId),
          queryParameters: queryOf({'offset': offset, 'limit': limit, 'period_id': periodId}),
        ),
      );

  Future<Map<String, dynamic>> brickCount(String factoryId, String countId) async =>
      dataOf(await _dio.get('${_counts(factoryId)}/$countId'));

  Future<Map<String, dynamic>> createBrickCount(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_counts(factoryId), data: data));

  /// Replaces the whole count.
  Future<Map<String, dynamic>> updateBrickCount(
    String factoryId,
    String countId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.put('${_counts(factoryId)}/$countId', data: data));

  Future<Map<String, dynamic>> cancelBrickCount(String factoryId, String countId, {String? reason}) async =>
      dataOf(await _dio.post('${_counts(factoryId)}/$countId/cancel', data: {'reason': reason}));

  // ---- Kiln unloadings ----

  Future<PageJson> unloadings(String factoryId, {int offset = 0, int limit = 30}) async => PageJson.of(
    await _dio.get(_unloadings(factoryId), queryParameters: queryOf({'offset': offset, 'limit': limit})),
  );

  Future<Map<String, dynamic>> unloading(String factoryId, String unloadingId) async =>
      dataOf(await _dio.get('${_unloadings(factoryId)}/$unloadingId'));

  Future<Map<String, dynamic>> createUnloading(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_unloadings(factoryId), data: data));

  Future<Map<String, dynamic>> updateUnloading(
    String factoryId,
    String unloadingId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.put('${_unloadings(factoryId)}/$unloadingId', data: data));

  Future<Map<String, dynamic>> cancelUnloading(String factoryId, String unloadingId, {String? reason}) async =>
      dataOf(await _dio.post('${_unloadings(factoryId)}/$unloadingId/cancel', data: {'reason': reason}));

  // ---- Work typed in by hand ----

  Future<PageJson> workEntries(String factoryId, {int offset = 0, int limit = 30, String? source}) async =>
      PageJson.of(
        await _dio.get(
          _work(factoryId),
          queryParameters: queryOf({'offset': offset, 'limit': limit, 'source': source}),
        ),
      );

  Future<Map<String, dynamic>> createWorkEntry(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_work(factoryId), data: data));

  Future<Map<String, dynamic>> updateWorkEntry(
    String factoryId,
    String entryId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.put('${_work(factoryId)}/$entryId', data: data));

  Future<Map<String, dynamic>> cancelWorkEntry(String factoryId, String entryId, {String? reason}) async =>
      dataOf(await _dio.post('${_work(factoryId)}/$entryId/cancel', data: {'reason': reason}));
}
