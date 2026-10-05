import 'package:khanak/api/api.dart';
import 'package:khanak/core/components/moduleBase.dart';
import 'package:khanak/helpers/errorHandler.dart';
import 'package:khanak/storage/hive/cache.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/work.dart';

/// The member's factories, the open one, and what is set up for it: kinds of
/// work and rates, trucks, members and seasons.
class FactoryModule extends CoreModule {
  FactoryModule(super.core);

  List<Factory> _factories = [];
  Factory? _selected;
  bool _isLoading = false;
  String? _loadError;

  List<Factory> get factories => _factories;

  /// The open factory, with the member's role, the open period and the
  /// subscription.
  Factory? get selected => _selected;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  final LoadState<List<WorkType>> workTypes = LoadState();
  final LoadState<List<Truck>> trucks = LoadState();
  final LoadState<List<Kiln>> kilns = LoadState();
  final LoadState<List<Member>> members = LoadState();
  final LoadState<List<Period>> periods = LoadState();

  Future<void> _cache() async {
    await CacheBox.setFactories(_factories.map((f) => f.toJson()).toList());
  }

  /// Loads the member's factories and reopens the last one (or the only one).
  Future<void> fetchFactories() async {
    _isLoading = true;
    _loadError = null;
    core.notify();

    try {
      _factories = (await Api.instance.factory.list()).map(Factory.fromJson).toList();
      await _cache();
    } catch (e) {
      _loadError = extractErrorMessage(e);
      if (_factories.isEmpty) {
        _factories = CacheBox.getFactories().map(Factory.fromJson).toList();
      }
    }

    final selectedId = _selected?.id ?? CacheBox.getSelectedFactoryId();
    final match = _factories.where((f) => f.id == selectedId).firstOrNull ??
        (_factories.length == 1 ? _factories.first : null);
    if (match != null) {
      await select(match);
    } else {
      _selected = null;
    }

    _isLoading = false;
    core.notify();
  }

  /// Opens [factory] and loads its full view (period, subscription). The
  /// list's copy is shown until that arrives, or kept when offline.
  Future<void> select(Factory factory) async {
    final changed = _selected?.id != factory.id;
    _selected = changed ? factory : _selected;
    await CacheBox.setSelectedFactoryId(factory.id);
    if (changed) {
      workTypes.reset();
      trucks.reset();
      kilns.reset();
      members.reset();
      periods.reset();
      core.resetFactoryData();
    }
    await refreshSelected();
  }

  /// Reloads the open factory: its period changes with each season and its
  /// subscription with each renewal.
  Future<void> refreshSelected() async {
    final current = _selected;
    if (current == null) return;
    try {
      final fresh = Factory.fromJson(await Api.instance.factory.get(current.id));
      _selected = fresh;
      _factories = [for (final f in _factories) f.id == fresh.id ? fresh : f];
      await _cache();
    } catch (_) {
      // Keep what is shown; the next screen that loads data will say why.
    }
    core.notify();
  }

  Future<Factory?> createFactory(Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.factory.create(data));
    if (json == null) return null;
    final factory = Factory.fromJson(json);
    _factories = [..._factories, factory];
    await _cache();
    await select(factory);
    return factory;
  }

  Future<bool> updateFactory(Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.factory.update(_selected!.id, data));
    if (json == null) return false;
    _selected = Factory.fromJson(json);
    _factories = [for (final f in _factories) f.id == _selected!.id ? _selected! : f];
    await _cache();
    core.notify();
    return true;
  }

  // ---- Kinds of work and rates ----

  Future<List<WorkType>?> fetchWorkTypes({bool refresh = false}) => loadValue(
    workTypes,
    () async => (await Api.instance.factory.workTypes(_selected!.id)).map(WorkType.fromJson).toList(),
    refresh: refresh,
  );

  /// The built-in kind with [code] (molding, kiln_loading, ...), once loaded.
  WorkType? workType(String code) => workTypes.value?.where((t) => t.code == code).firstOrNull;

  /// True when no rate for brick work has been set yet: the owner is asked
  /// to set them before the first count.
  bool get ratesMissing {
    final types = workTypes.value;
    if (types == null) return false;
    return ['molding', 'kiln_loading', 'stacking', 'unloading']
        .map(workType)
        .any((type) => type != null && (type.rate ?? 0) == 0);
  }

  Future<bool> updateWorkType(String typeId, Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.factory.updateWorkType(_selected!.id, typeId, data));
    if (json == null) return false;
    await fetchWorkTypes(refresh: true);
    return true;
  }

  Future<bool> createWorkType(Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.factory.createWorkType(_selected!.id, data));
    if (json == null) return false;
    await fetchWorkTypes(refresh: true);
    return true;
  }

  // ---- Trucks ----

  Future<List<Truck>?> fetchTrucks({bool refresh = false}) => loadValue(
    trucks,
    () async => (await Api.instance.factory.trucks(_selected!.id)).map(Truck.fromJson).toList(),
    refresh: refresh,
  );

  Future<bool> saveTruck({String? truckId, required String number, String? name, bool? isActive}) async {
    final data = {'number': number, 'name': name, 'is_active': ?isActive};
    final json = await runSave(
      () => truckId == null
          ? Api.instance.factory.createTruck(_selected!.id, data)
          : Api.instance.factory.updateTruck(_selected!.id, truckId, data),
    );
    if (json == null) return false;
    await fetchTrucks(refresh: true);
    return true;
  }

  // ---- Kilns ----

  Future<List<Kiln>?> fetchKilns({bool refresh = false}) => loadValue(
    kilns,
    () async => (await Api.instance.factory.kilns(_selected!.id)).map(Kiln.fromJson).toList(),
    refresh: refresh,
  );

  Future<bool> saveKiln({String? kilnId, required String name, bool? isActive}) async {
    final data = {'name': name, 'is_active': ?isActive};
    final json = await runSave(
      () => kilnId == null
          ? Api.instance.factory.createKiln(_selected!.id, data)
          : Api.instance.factory.updateKiln(_selected!.id, kilnId, data),
    );
    if (json == null) return false;
    await fetchKilns(refresh: true);
    return true;
  }

  // ---- Members ----

  Future<List<Member>?> fetchMembers({bool refresh = false}) => loadValue(
    members,
    () async => (await Api.instance.factory.members(_selected!.id)).map(Member.fromJson).toList(),
    refresh: refresh,
  );

  Future<bool> addMember({required String email, required String role, String? workerId}) async {
    final json = await runSave(
      () => Api.instance.factory.addMember(_selected!.id, email: email, role: role, workerId: workerId),
    );
    if (json == null) return false;
    await fetchMembers(refresh: true);
    return true;
  }

  Future<bool> updateMember(String userId, Map<String, dynamic> data) async {
    final json = await runSave(() => Api.instance.factory.updateMember(_selected!.id, userId, data));
    if (json == null) return false;
    await fetchMembers(refresh: true);
    return true;
  }

  Future<bool> removeMember(String userId) async {
    final done = await runSave(
      () => Api.instance.factory.removeMember(_selected!.id, userId).then((_) => true),
    );
    if (done != true) return false;
    await fetchMembers(refresh: true);
    return true;
  }

  // ---- Seasons ----

  Future<List<Period>?> fetchPeriods({bool refresh = false}) => loadValue(
    periods,
    () async => (await Api.instance.factory.periods(_selected!.id)).map(Period.fromJson).toList(),
    refresh: refresh,
  );

  Future<bool> startSeason({String? startedOn, String? name}) => _switchPeriod(
    () => Api.instance.factory.startSeason(_selected!.id, startedOn: startedOn, name: name),
  );

  Future<bool> endSeason({String? endedOn}) =>
      _switchPeriod(() => Api.instance.factory.endSeason(_selected!.id, endedOn: endedOn));

  Future<bool> _switchPeriod(Future<Map<String, dynamic>> Function() action) async {
    final json = await runSave(action);
    if (json == null) return false;
    await refreshSelected();
    await fetchPeriods(refresh: true);
    core.report.markStale();
    return true;
  }

  void clearAll() {
    _factories = [];
    _selected = null;
    _isLoading = false;
    _loadError = null;
    workTypes.reset();
    trucks.reset();
    kilns.reset();
    members.reset();
    periods.reset();
  }
}
