import 'package:khanak/api/api.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/core/components/moduleBase.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/types/trade.dart';

/// One party's account as shown on their screen.
class PartyAccount {
  final PagedState<PartyLine> lines = PagedState();
  double balance = 0;

  void reset() {
    lines.reset();
    balance = 0;
  }
}

/// Sales, expenses, customers and suppliers, and money with them.
class TradeModule extends CoreModule {
  TradeModule(super.core);

  final PagedState<Sale> sales = PagedState();
  final PagedState<Expense> expenses = PagedState();

  /// Every customer and supplier with their balance.
  final LoadState<List<Party>> parties = LoadState();
  final Map<String, LoadState<Party>> _details = {};
  final Map<String, PartyAccount> _accounts = {};

  LoadState<Party> party(String partyId) => _details.putIfAbsent(partyId, LoadState.new);
  PartyAccount account(String partyId) => _accounts.putIfAbsent(partyId, PartyAccount.new);

  Future<void> fetchSales({bool refresh = false, bool more = false}) => loadPage(
    sales,
    fetch: (offset) => Api.instance.trade.sales(core.factoryId, offset: offset),
    parse: Sale.fromJson,
    refresh: refresh,
    more: more,
  );

  Future<void> fetchExpenses({bool refresh = false, bool more = false}) => loadPage(
    expenses,
    fetch: (offset) => Api.instance.trade.expenses(core.factoryId, offset: offset),
    parse: Expense.fromJson,
    refresh: refresh,
    more: more,
  );

  Future<List<Party>?> fetchParties({bool refresh = false}) => loadValue(
    parties,
    () async => (await Api.instance.trade.parties(core.factoryId)).map(Party.fromJson).toList(),
    refresh: refresh,
  );

  Future<Party?> fetchParty(String partyId, {bool refresh = false}) => loadValue(
    party(partyId),
    () async => Party.fromJson(await Api.instance.trade.party(core.factoryId, partyId)),
    refresh: refresh,
  );

  Future<void> fetchPartyLedger(String partyId, {bool refresh = false, bool more = false}) {
    final account = this.account(partyId);
    return loadPage(
      account.lines,
      fetch: (offset) async {
        final page = await Api.instance.trade.partyLedger(core.factoryId, partyId, offset: offset);
        account.balance = asDouble(page.balance);
        return page.page;
      },
      parse: PartyLine.fromJson,
      refresh: refresh,
      more: more,
    );
  }

  Future<Sale?> fetchSale(String saleId) async {
    final json = await runSave(() => Api.instance.trade.sale(core.factoryId, saleId));
    return json == null ? null : Sale.fromJson(json);
  }

  Future<Expense?> fetchExpense(String expenseId) async {
    final json = await runSave(() => Api.instance.trade.expense(core.factoryId, expenseId));
    return json == null ? null : Expense.fromJson(json);
  }

  /// The rate to start a new sale with, or null when there was no sale yet.
  Future<double?> lastRate({String? partyId}) async {
    try {
      final json = await Api.instance.trade.lastRate(core.factoryId, partyId: partyId);
      return json == null ? null : asDoubleOrNull(json['rate']);
    } catch (_) {
      return null;
    }
  }

  Future<Sale?> saveSale(Map<String, dynamic> data, {String? saleId}) => _save(
    () => saleId == null
        ? Api.instance.trade.createSale(core.factoryId, data)
        : Api.instance.trade.updateSale(core.factoryId, saleId, data),
    Sale.fromJson,
  );

  Future<Sale?> cancelSale(String saleId, {String? reason}) =>
      _save(() => Api.instance.trade.cancelSale(core.factoryId, saleId, reason: reason), Sale.fromJson);

  Future<Expense?> saveExpense(Map<String, dynamic> data, {String? expenseId}) => _save(
    () => expenseId == null
        ? Api.instance.trade.createExpense(core.factoryId, data)
        : Api.instance.trade.updateExpense(core.factoryId, expenseId, data),
    Expense.fromJson,
  );

  Future<Expense?> cancelExpense(String expenseId, {String? reason}) =>
      _save(() => Api.instance.trade.cancelExpense(core.factoryId, expenseId, reason: reason), Expense.fromJson);

  /// A new customer or supplier, added on the spot.
  Future<Party?> createParty({required String kind, required String name, String? phone, String? village}) =>
      _save(
        () => Api.instance.trade.createParty(core.factoryId, {
          'kind': kind,
          'name': name,
          'phone': phone,
          'village': village,
        }),
        Party.fromJson,
      );

  Future<PartyPayment?> fetchPayment(String paymentId) async {
    final json = await runSave(() => Api.instance.trade.payment(core.factoryId, paymentId));
    return json == null ? null : PartyPayment.fromJson(json);
  }

  /// A new payment, or a change to [paymentId]. Returns the party's balance
  /// after it, or null when it failed.
  Future<double?> savePayment(String partyId, Map<String, dynamic> data, {String? paymentId}) async {
    final json = await runSave(
      () => paymentId == null
          ? Api.instance.trade.addPayment(core.factoryId, partyId, data)
          : Api.instance.trade.updatePayment(core.factoryId, paymentId, data),
    );
    if (json == null) return null;
    _changed();
    return asDouble(json['balance']);
  }

  Future<bool> cancelPayment(String paymentId, {String? reason}) async {
    final json = await runSave(() => Api.instance.trade.cancelPayment(core.factoryId, paymentId, reason: reason));
    if (json == null) return false;
    _changed();
    return true;
  }

  Future<TruckReport?> truckReport(String truckId, {String? from, String? to}) async {
    final json = await runSave(() => Api.instance.trade.truckReport(core.factoryId, truckId, from: from, to: to));
    return json == null ? null : TruckReport.fromJson(json);
  }

  Future<T?> _save<T>(Future<Map<String, dynamic>> Function() action, T Function(Map<String, dynamic>) parse) async {
    final json = await runSave(action);
    if (json == null) return null;
    _changed();
    return parse(json);
  }

  void _changed() {
    core.markBooksChanged();
    core.notify();
  }

  void markStale() {
    sales.stale = true;
    expenses.stale = true;
    parties.stale = true;
    for (final state in _details.values) {
      state.stale = true;
    }
    for (final account in _accounts.values) {
      account.lines.stale = true;
    }
  }

  void clear() {
    sales.reset();
    expenses.reset();
    parties.reset();
    _details.clear();
    _accounts.clear();
  }
}
