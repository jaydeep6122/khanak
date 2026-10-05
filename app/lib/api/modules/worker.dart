import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

/// One worker's account, as a page of lines with what they add up to.
class LedgerPage {
  final PageJson page;
  final Map<String, dynamic> totals;
  final String balance;

  const LedgerPage({required this.page, required this.totals, required this.balance});
}

class WorkerApi {
  final Dio _dio;

  WorkerApi(this._dio);

  String _path(String factoryId) => '${factoryPath(factoryId)}/workers';

  /// A supervisor gets names only, no balances.
  Future<List<Map<String, dynamic>>> list(String factoryId, {bool? active, String? search}) async =>
      listOf(
        await _dio.get(
          _path(factoryId),
          queryParameters: queryOf({'active': active, 'search': search}),
        ),
      );

  Future<Map<String, dynamic>> create(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_path(factoryId), data: data));

  Future<Map<String, dynamic>> get(String factoryId, String workerId) async =>
      dataOf(await _dio.get('${_path(factoryId)}/$workerId'));

  Future<Map<String, dynamic>> update(String factoryId, String workerId, Map<String, dynamic> data) async =>
      dataOf(await _dio.patch('${_path(factoryId)}/$workerId', data: data));

  Future<Map<String, dynamic>> markLeft(String factoryId, String workerId, String leftOn) async =>
      dataOf(await _dio.post('${_path(factoryId)}/$workerId/leave', data: {'left_on': leftOn}));

  Future<Map<String, dynamic>> markReturned(String factoryId, String workerId) async =>
      dataOf(await _dio.post('${_path(factoryId)}/$workerId/return'));

  /// `{ worker_id, name, nickname, balance }`: all a supervisor may see.
  Future<Map<String, dynamic>> balance(String factoryId, String workerId) async =>
      dataOf(await _dio.get('${_path(factoryId)}/$workerId/balance'));

  Future<LedgerPage> ledger(
    String factoryId,
    String workerId, {
    String? periodId,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '${_path(factoryId)}/$workerId/ledger',
      queryParameters: queryOf({'period_id': periodId, 'offset': offset, 'limit': limit}),
    );
    return LedgerPage(
      page: PageJson.of(response),
      totals: Map<String, dynamic>.from(response.data['totals'] as Map),
      balance: response.data['balance'].toString(),
    );
  }

  Future<Map<String, dynamic>> share(String factoryId, String workerId) async =>
      dataOf(await _dio.get('${_path(factoryId)}/$workerId/share'));

  /// A new link; the old one stops working at once.
  Future<Map<String, dynamic>> regenerateShare(String factoryId, String workerId) async =>
      dataOf(await _dio.post('${_path(factoryId)}/$workerId/share/regenerate'));

  Future<Map<String, dynamic>> setShareEnabled(String factoryId, String workerId, bool enabled) async =>
      dataOf(await _dio.patch('${_path(factoryId)}/$workerId/share', data: {'enabled': enabled}));

  /// An advance, settlement, recovery or write-off. Returns it with the
  /// worker's new `balance`.
  Future<Map<String, dynamic>> addTransaction(
    String factoryId,
    String workerId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.post('${_path(factoryId)}/$workerId/transactions', data: data));

  Future<Map<String, dynamic>> updateTransaction(
    String factoryId,
    String txnId,
    Map<String, dynamic> data,
  ) async => dataOf(await _dio.put('${factoryPath(factoryId)}/worker-transactions/$txnId', data: data));

  Future<Map<String, dynamic>> cancelTransaction(String factoryId, String txnId, {String? reason}) async =>
      dataOf(
        await _dio.post(
          '${factoryPath(factoryId)}/worker-transactions/$txnId/cancel',
          data: {'reason': reason},
        ),
      );
}
