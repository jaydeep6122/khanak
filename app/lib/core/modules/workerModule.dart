import 'package:khanak/api/api.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/core/components/moduleBase.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// One worker's account as shown on their screen.
class WorkerAccount {
  final PagedState<LedgerLine> lines = PagedState();
  LedgerTotals totals = LedgerTotals.empty;
  double balance = 0;

  void reset() {
    lines.reset();
    totals = LedgerTotals.empty;
    balance = 0;
  }
}

/// Workers, their accounts, and money paid to or by them.
class WorkerModule extends CoreModule {
  WorkerModule(super.core);

  /// Every worker, active first. A supervisor's copy has names only.
  final LoadState<List<Worker>> workers = LoadState();

  final Map<String, LoadState<Worker>> _details = {};
  final Map<String, WorkerAccount> _accounts = {};

  LoadState<Worker> detail(String workerId) => _details.putIfAbsent(workerId, LoadState.new);
  WorkerAccount account(String workerId) => _accounts.putIfAbsent(workerId, WorkerAccount.new);

  List<Worker> get activeWorkers => (workers.value ?? const []).where((w) => w.isActive).toList();

  Worker? byId(String? workerId) => (workers.value ?? const []).where((w) => w.id == workerId).firstOrNull;

  Future<List<Worker>?> fetchWorkers({bool refresh = false}) => loadValue(
    workers,
    () async => (await Api.instance.worker.list(core.factoryId)).map(Worker.fromJson).toList(),
    refresh: refresh,
  );

  Future<Worker?> fetchWorker(String workerId, {bool refresh = false}) => loadValue(
    detail(workerId),
    () async => Worker.fromJson(await Api.instance.worker.get(core.factoryId, workerId)),
    refresh: refresh,
  );

  Future<void> fetchLedger(String workerId, {bool refresh = false, bool more = false}) {
    final account = this.account(workerId);
    return loadPage(
      account.lines,
      fetch: (offset) async {
        final page = await Api.instance.worker.ledger(core.factoryId, workerId, offset: offset);
        account.totals = LedgerTotals.fromJson(page.totals);
        account.balance = asDouble(page.balance);
        return page.page;
      },
      parse: LedgerLine.fromJson,
      refresh: refresh,
      more: more,
    );
  }

  /// Every line of the account, for a statement: [period] only, or the
  /// whole account when null.
  Future<WorkerStatement?> fetchStatement(String workerId, {Period? period}) => runSave(() async {
    const pageSize = 200;
    final lines = <LedgerLine>[];
    var totals = LedgerTotals.empty;
    var balance = 0.0;
    for (var offset = 0; ; offset += pageSize) {
      final page = await Api.instance.worker.ledger(
        core.factoryId,
        workerId,
        periodId: period?.id,
        offset: offset,
        limit: pageSize,
      );
      totals = LedgerTotals.fromJson(page.totals);
      balance = asDouble(page.balance);
      lines.addAll(page.page.items.map(LedgerLine.fromJson));
      if (page.page.items.length < pageSize) break;
    }
    return WorkerStatement(
      // The ledger comes newest first; a statement reads oldest first.
      lines: lines.reversed.toList(),
      totals: totals,
      balance: balance,
      from: period?.startedOn,
    );
  });

  /// The balance only: what a supervisor sees before giving an advance.
  Future<double?> fetchBalance(String workerId) async {
    try {
      return asDouble((await Api.instance.worker.balance(core.factoryId, workerId))['balance']);
    } catch (_) {
      return null;
    }
  }

  Future<Worker?> saveWorker(Map<String, dynamic> data, {String? workerId}) async {
    final json = await runSave(
      () => workerId == null
          ? Api.instance.worker.create(core.factoryId, data)
          : Api.instance.worker.update(core.factoryId, workerId, data),
    );
    if (json == null) return null;
    final worker = Worker.fromJson(json);
    detail(worker.id).value = worker;
    workers.stale = true;
    if (workerId != null) core.markBooksChanged();
    core.notify();
    return worker;
  }

  Future<bool> markLeft(String workerId, String leftOn) =>
      _changeStatus(workerId, () => Api.instance.worker.markLeft(core.factoryId, workerId, leftOn));

  Future<bool> markReturned(String workerId) =>
      _changeStatus(workerId, () => Api.instance.worker.markReturned(core.factoryId, workerId));

  Future<bool> _changeStatus(String workerId, Future<Map<String, dynamic>> Function() action) async {
    final json = await runSave(action);
    if (json == null) return false;
    detail(workerId).stale = true;
    workers.stale = true;
    core.markBooksChanged();
    core.notify();
    return true;
  }

  // ---- The worker's own link ----

  Future<WorkerShare?> share(String workerId) async {
    final json = await runSave(() => Api.instance.worker.share(core.factoryId, workerId));
    return json == null ? null : WorkerShare.fromJson(json);
  }

  Future<WorkerShare?> regenerateShare(String workerId) async {
    final json = await runSave(() => Api.instance.worker.regenerateShare(core.factoryId, workerId));
    return json == null ? null : WorkerShare.fromJson(json);
  }

  Future<WorkerShare?> setShareEnabled(String workerId, bool enabled) async {
    final json = await runSave(
      () => Api.instance.worker.setShareEnabled(core.factoryId, workerId, enabled),
    );
    if (json == null) return null;
    detail(workerId).stale = true;
    return WorkerShare.fromJson(json);
  }

  // ---- Advances, settlements, recoveries and write-offs ----

  /// Returns the worker's balance after it, or null when it failed.
  Future<double?> addTransaction(String workerId, Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.worker.addTransaction(core.factoryId, workerId, data));
    if (json == null) return null;
    core.markBooksChanged();
    core.notify();
    return asDouble(json['balance']);
  }

  Future<bool> updateTransaction(String txnId, Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.worker.updateTransaction(core.factoryId, txnId, data));
    if (json == null) return false;
    core.markBooksChanged();
    core.notify();
    return true;
  }

  Future<bool> cancelTransaction(String txnId, {String? reason}) async {
    final json = await runSave(
      () => Api.instance.worker.cancelTransaction(core.factoryId, txnId, reason: reason),
    );
    if (json == null) return false;
    core.markBooksChanged();
    core.notify();
    return true;
  }

  void markStale() {
    workers.stale = true;
    for (final state in _details.values) {
      state.stale = true;
    }
    for (final account in _accounts.values) {
      account.lines.stale = true;
    }
  }

  void clear() {
    workers.reset();
    _details.clear();
    _accounts.clear();
  }
}
