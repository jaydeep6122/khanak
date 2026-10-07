import 'package:dio/dio.dart';
import 'package:khanak/api/response.dart';

/// A party's account, as a page of lines with the balance.
class PartyLedgerPage {
  final PageJson page;
  final String balance;

  const PartyLedgerPage({required this.page, required this.balance});
}

/// Sales, expenses, customers and suppliers, and the truck report. Owner and
/// munim only.
class TradeApi {
  final Dio _dio;

  TradeApi(this._dio);

  String _sales(String factoryId) => '${factoryPath(factoryId)}/sales';
  String _expenses(String factoryId) => '${factoryPath(factoryId)}/expenses';
  String _parties(String factoryId) => '${factoryPath(factoryId)}/parties';

  // ---- Sales ----

  Future<PageJson> sales(String factoryId, {int offset = 0, int limit = 30, String? partyId}) async => PageJson.of(
    await _dio.get(_sales(factoryId), queryParameters: queryOf({'offset': offset, 'limit': limit, 'party_id': partyId})),
  );

  Future<Map<String, dynamic>> sale(String factoryId, String saleId) async =>
      dataOf(await _dio.get('${_sales(factoryId)}/$saleId'));

  /// `{ rate, sold_on }` of the customer's last sale (or the factory's), or null.
  Future<Map<String, dynamic>?> lastRate(String factoryId, {String? partyId}) async {
    final response = await _dio.get(
      '${_sales(factoryId)}/last-rate',
      queryParameters: queryOf({'party_id': partyId}),
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<Map<String, dynamic>> createSale(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_sales(factoryId), data: data));

  Future<Map<String, dynamic>> updateSale(String factoryId, String saleId, Map<String, dynamic> data) async =>
      dataOf(await _dio.put('${_sales(factoryId)}/$saleId', data: data));

  Future<Map<String, dynamic>> cancelSale(String factoryId, String saleId, {String? reason}) async =>
      dataOf(await _dio.post('${_sales(factoryId)}/$saleId/cancel', data: {'reason': reason}));

  // ---- Expenses ----

  Future<PageJson> expenses(String factoryId, {int offset = 0, int limit = 30, String? truckId}) async => PageJson.of(
    await _dio.get(_expenses(factoryId), queryParameters: queryOf({'offset': offset, 'limit': limit, 'truck_id': truckId})),
  );

  Future<Map<String, dynamic>> expense(String factoryId, String expenseId) async =>
      dataOf(await _dio.get('${_expenses(factoryId)}/$expenseId'));

  Future<Map<String, dynamic>> createExpense(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_expenses(factoryId), data: data));

  Future<Map<String, dynamic>> updateExpense(String factoryId, String expenseId, Map<String, dynamic> data) async =>
      dataOf(await _dio.put('${_expenses(factoryId)}/$expenseId', data: data));

  Future<Map<String, dynamic>> cancelExpense(String factoryId, String expenseId, {String? reason}) async =>
      dataOf(await _dio.post('${_expenses(factoryId)}/$expenseId/cancel', data: {'reason': reason}));

  // ---- Customers and suppliers ----

  Future<List<Map<String, dynamic>>> parties(String factoryId, {String? kind, bool? withBalance}) async => listOf(
    await _dio.get(_parties(factoryId), queryParameters: queryOf({'kind': kind, 'with_balance': withBalance})),
  );

  Future<Map<String, dynamic>> party(String factoryId, String partyId) async =>
      dataOf(await _dio.get('${_parties(factoryId)}/$partyId'));

  Future<Map<String, dynamic>> createParty(String factoryId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post(_parties(factoryId), data: data));

  Future<Map<String, dynamic>> updateParty(String factoryId, String partyId, Map<String, dynamic> data) async =>
      dataOf(await _dio.patch('${_parties(factoryId)}/$partyId', data: data));

  Future<PartyLedgerPage> partyLedger(String factoryId, String partyId, {int offset = 0, int limit = 50}) async {
    final response = await _dio.get(
      '${_parties(factoryId)}/$partyId/ledger',
      queryParameters: queryOf({'offset': offset, 'limit': limit}),
    );
    return PartyLedgerPage(page: PageJson.of(response), balance: response.data['balance'].toString());
  }

  /// received, paid or writeoff. Returns it with the party's new `balance`.
  Future<Map<String, dynamic>> addPayment(String factoryId, String partyId, Map<String, dynamic> data) async =>
      dataOf(await _dio.post('${_parties(factoryId)}/$partyId/payments', data: data));

  Future<Map<String, dynamic>> payment(String factoryId, String paymentId) async =>
      dataOf(await _dio.get('${factoryPath(factoryId)}/party-payments/$paymentId'));

  /// Returns it with the party's new `balance`.
  Future<Map<String, dynamic>> updatePayment(String factoryId, String paymentId, Map<String, dynamic> data) async =>
      dataOf(await _dio.put('${factoryPath(factoryId)}/party-payments/$paymentId', data: data));

  Future<Map<String, dynamic>> cancelPayment(String factoryId, String paymentId, {String? reason}) async =>
      dataOf(await _dio.post('${factoryPath(factoryId)}/party-payments/$paymentId/cancel', data: {'reason': reason}));

  // ---- Truck report ----

  Future<Map<String, dynamic>> truckReport(String factoryId, String truckId, {String? from, String? to}) async =>
      dataOf(
        await _dio.get(
          '${factoryPath(factoryId)}/trucks/$truckId/report',
          queryParameters: queryOf({'from': from, 'to': to}),
        ),
      );
}
