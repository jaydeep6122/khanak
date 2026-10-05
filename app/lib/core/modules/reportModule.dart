import 'package:khanak/api/api.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/core/components/moduleBase.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/types/report.dart';

/// The home screen's totals, supervisor cash and who entered what.
class ReportModule extends CoreModule {
  ReportModule(super.core);

  final LoadState<HomeSummary> summary = LoadState();
  final LoadState<List<CashHolder>> cashHolders = LoadState();
  final Map<String, LoadState<CashHolder>> _cash = {};

  LoadState<CashHolder> cash(String holderId) => _cash.putIfAbsent(holderId, LoadState.new);

  Future<HomeSummary?> fetchSummary({bool refresh = false}) => loadValue(
    summary,
    () async => HomeSummary.fromJson(await Api.instance.report.summary(core.factoryId)),
    refresh: refresh,
  );

  Future<List<CashHolder>?> fetchCashHolders({bool refresh = false}) => loadValue(
    cashHolders,
    () async => (await Api.instance.report.cashHolders(core.factoryId)).map(CashHolder.fromJson).toList(),
    refresh: refresh,
  );

  Future<CashHolder?> fetchCash(String holderId, {bool refresh = false}) => loadValue(
    cash(holderId),
    () async => CashHolder.fromJson(await Api.instance.report.cashHolder(core.factoryId, holderId)),
    refresh: refresh,
  );

  Future<List<Activity>> fetchActivity({String? date, String? userId}) async {
    final rows = await Api.instance.report.activity(core.factoryId, date: date, userId: userId);
    return asMapList(rows).map(Activity.fromJson).toList();
  }

  Future<bool> handOver({
    required String holderId,
    required String kind,
    required String date,
    required String amount,
    String? note,
  }) async {
    final json = await runSave(
      () => Api.instance.report.handOver(core.factoryId, {
        'holder_id': holderId,
        'kind': kind,
        'handover_date': date,
        'amount': amount,
        'note': note,
      }),
    );
    if (json == null) return false;
    markStale();
    core.notify();
    return true;
  }

  Future<bool> settleCash(String holderId) async {
    final json = await runSave(() => Api.instance.report.settleCash(core.factoryId, holderId));
    if (json == null) return false;
    markStale();
    core.notify();
    return true;
  }

  void markStale() {
    summary.stale = true;
    cashHolders.stale = true;
    for (final state in _cash.values) {
      state.stale = true;
    }
  }

  void clear() {
    summary.reset();
    cashHolders.reset();
    _cash.clear();
  }
}
