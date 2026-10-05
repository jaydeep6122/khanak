import 'package:khanak/api/api.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/core/components/moduleBase.dart';
import 'package:khanak/types/work.dart';

/// Brick counts, kiln unloadings and work typed in by hand.
class EntryModule extends CoreModule {
  EntryModule(super.core);

  final PagedState<BrickCount> counts = PagedState();
  final PagedState<KilnUnloading> unloadings = PagedState();
  final PagedState<WorkEntry> workEntries = PagedState();

  Future<void> fetchCounts({bool refresh = false, bool more = false}) => loadPage(
    counts,
    fetch: (offset) => Api.instance.entry.brickCounts(core.factoryId, offset: offset),
    parse: BrickCount.fromJson,
    refresh: refresh,
    more: more,
  );

  Future<void> fetchUnloadings({bool refresh = false, bool more = false}) => loadPage(
    unloadings,
    fetch: (offset) => Api.instance.entry.unloadings(core.factoryId, offset: offset),
    parse: KilnUnloading.fromJson,
    refresh: refresh,
    more: more,
  );

  /// Only what was typed in by hand; counts and unloadings have their own lists.
  Future<void> fetchWorkEntries({bool refresh = false, bool more = false}) => loadPage(
    workEntries,
    fetch: (offset) => Api.instance.entry.workEntries(core.factoryId, offset: offset, source: 'manual'),
    parse: WorkEntry.fromJson,
    refresh: refresh,
    more: more,
  );

  Future<BrickCount?> fetchCount(String countId) async {
    final json = await runSave(() => Api.instance.entry.brickCount(core.factoryId, countId));
    return json == null ? null : BrickCount.fromJson(json);
  }

  Future<KilnUnloading?> fetchUnloading(String unloadingId) async {
    final json = await runSave(() => Api.instance.entry.unloading(core.factoryId, unloadingId));
    return json == null ? null : KilnUnloading.fromJson(json);
  }

  /// Creates the count, or replaces [countId]. The saved count comes back
  /// with any stock warnings.
  Future<BrickCount?> saveCount(Map<String, dynamic> data, {String? countId}) => _save(
    () => countId == null
        ? Api.instance.entry.createBrickCount(core.factoryId, data)
        : Api.instance.entry.updateBrickCount(core.factoryId, countId, data),
    BrickCount.fromJson,
  );

  Future<BrickCount?> cancelCount(String countId, {String? reason}) => _save(
    () => Api.instance.entry.cancelBrickCount(core.factoryId, countId, reason: reason),
    BrickCount.fromJson,
  );

  Future<KilnUnloading?> saveUnloading(Map<String, dynamic> data, {String? unloadingId}) => _save(
    () => unloadingId == null
        ? Api.instance.entry.createUnloading(core.factoryId, data)
        : Api.instance.entry.updateUnloading(core.factoryId, unloadingId, data),
    KilnUnloading.fromJson,
  );

  Future<KilnUnloading?> cancelUnloading(String unloadingId, {String? reason}) => _save(
    () => Api.instance.entry.cancelUnloading(core.factoryId, unloadingId, reason: reason),
    KilnUnloading.fromJson,
  );

  Future<WorkEntry?> saveWorkEntry(Map<String, dynamic> data, {String? entryId}) => _save(
    () => entryId == null
        ? Api.instance.entry.createWorkEntry(core.factoryId, data)
        : Api.instance.entry.updateWorkEntry(core.factoryId, entryId, data),
    WorkEntry.fromJson,
  );

  Future<WorkEntry?> cancelWorkEntry(String entryId, {String? reason}) => _save(
    () => Api.instance.entry.cancelWorkEntry(core.factoryId, entryId, reason: reason),
    WorkEntry.fromJson,
  );

  Future<T?> _save<T>(Future<Map<String, dynamic>> Function() action, T Function(Map<String, dynamic>) parse) async {
    final json = await runSave(action);
    if (json == null) return null;
    core.markBooksChanged();
    core.notify();
    return parse(json);
  }

  void markStale() {
    counts.stale = true;
    unloadings.stale = true;
    workEntries.stale = true;
  }

  void clear() {
    counts.reset();
    unloadings.reset();
    workEntries.reset();
  }
}
