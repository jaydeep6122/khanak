import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

/// The factory itself and what is set up for it: members, seasons, kinds of
/// work and trucks.
class FactoryApi {
  final Dio _dio;

  FactoryApi(this._dio);

  Future<List<Map<String, dynamic>>> list() async => listOf(await _dio.get('/factories'));

  /// `season_started_on` starts a season from that date; without it the
  /// factory starts in the off-season.
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async =>
      dataOf(await _dio.post('/factories', data: data));

  /// The factory with the caller's role, the open period and the subscription.
  Future<Map<String, dynamic>> get(String factoryId) async =>
      dataOf(await _dio.get(factoryPath(factoryId)));

  Future<Map<String, dynamic>> update(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.patch(factoryPath(factoryId), data: data));

  // ---- Members ----

  Future<List<Map<String, dynamic>>> members(String factoryId) async =>
      listOf(await _dio.get('${factoryPath(factoryId)}/members'));

  /// The person signs up first; they are added by the email they used.
  Future<Map<String, dynamic>> addMember(
    String factoryId, {
    required String email,
    required String role,
    String? workerId,
  }) async => dataOf(
    await _dio.post(
      '${factoryPath(factoryId)}/members',
      data: {'email': email, 'role': role, 'worker_id': workerId},
    ),
  );

  Future<Map<String, dynamic>> updateMember(
    String factoryId,
    String userId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.patch('${factoryPath(factoryId)}/members/$userId', data: data));

  Future<void> removeMember(String factoryId, String userId) async {
    await _dio.delete('${factoryPath(factoryId)}/members/$userId');
  }

  // ---- Seasons ----

  Future<List<Map<String, dynamic>>> periods(String factoryId) async =>
      listOf(await _dio.get('${factoryPath(factoryId)}/periods'));

  /// Returns `{ closed, opened }`.
  Future<Map<String, dynamic>> startSeason(String factoryId, {String? startedOn, String? name}) async =>
      dataOf(
        await _dio.post(
          '${factoryPath(factoryId)}/periods/start-season',
          data: {'started_on': ?startedOn, 'name': ?name},
        ),
      );

  /// Returns `{ closed, opened }`; the off-season opens the same day.
  Future<Map<String, dynamic>> endSeason(String factoryId, {String? endedOn}) async => dataOf(
    await _dio.post('${factoryPath(factoryId)}/periods/end-season', data: {'ended_on': ?endedOn}),
  );

  // ---- Kinds of work ----

  Future<List<Map<String, dynamic>>> workTypes(String factoryId) async =>
      listOf(await _dio.get('${factoryPath(factoryId)}/work-types'));

  Future<Map<String, dynamic>> createWorkType(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post('${factoryPath(factoryId)}/work-types', data: data));

  Future<Map<String, dynamic>> updateWorkType(
    String factoryId,
    String typeId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.patch('${factoryPath(factoryId)}/work-types/$typeId', data: data));

  // ---- Trucks ----

  Future<List<Map<String, dynamic>>> trucks(String factoryId) async =>
      listOf(await _dio.get('${factoryPath(factoryId)}/trucks'));

  Future<Map<String, dynamic>> createTruck(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post('${factoryPath(factoryId)}/trucks', data: data));

  Future<Map<String, dynamic>> updateTruck(
    String factoryId,
    String truckId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.patch('${factoryPath(factoryId)}/trucks/$truckId', data: data));
}
