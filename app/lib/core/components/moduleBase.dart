import 'package:khanak/api/response.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/helpers/errorHandler.dart';
import 'package:khanak/types/paged.dart';

/// A list that loads page by page (invoices, parties, ...).
class PagedState<T> {
  Paged<T> data = Paged<T>.empty();

  /// True only while there is nothing to show yet.
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  bool loaded = false;

  /// Something changed on the server; reload on the next visit.
  bool stale = false;

  /// A request is on its way (including a refresh of data already shown).
  bool isFetching = false;
  int _generation = 0;

  List<T> get items => data.items;

  /// Loaded data went stale and nothing is reloading it yet.
  bool get needsReload => loaded && stale && !isFetching && error == null;

  void reset() {
    data = Paged<T>.empty();
    isLoading = false;
    isLoadingMore = false;
    error = null;
    loaded = false;
    stale = false;
    isFetching = false;
    _generation++;
  }
}

/// One value loaded from the server (a record, a report, a small list).
class LoadState<T> {
  T? value;

  /// True only while there is nothing to show yet.
  bool isLoading = false;
  String? error;

  /// Something changed on the server; reload on the next visit.
  bool stale = false;

  /// A request is on its way (including a refresh of a value already shown).
  bool isFetching = false;
  int _generation = 0;

  /// The value went stale and nothing is reloading it yet.
  bool get needsReload => value != null && stale && !isFetching && error == null;

  void reset() {
    value = null;
    isLoading = false;
    error = null;
    stale = false;
    isFetching = false;
    _generation++;
  }
}

/// Shared plumbing for Core modules.
///
/// The server is the source of truth: modules never recalculate balances or
/// stock locally. After a change they mark affected data stale so it reloads.
abstract class CoreModule {
  CoreModule(this.core);

  final Core core;

  String? _error;

  /// Friendly message from the last failed save, ready to show the user.
  String? get error => _error;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// Runs a create/update/cancel call. Returns null and sets [error] when it
  /// fails.
  Future<R?> runSave<R>(Future<R> Function() action) async {
    _isSaving = true;
    _error = null;
    core.notify();
    try {
      return await action();
    } catch (e) {
      _error = extractErrorMessage(e);
      return null;
    } finally {
      _isSaving = false;
      core.notify();
    }
  }

  /// Loads the first page (or, with [more], the next one) into [state].
  ///
  /// Skips the call when data is already loaded and not stale, unless
  /// [refresh]. Responses that arrive after a newer request started are
  /// dropped, so fast typing in search never shows old results.
  Future<void> loadPage<T>(
    PagedState<T> state, {
    required Future<PageJson> Function(int offset) fetch,
    required T Function(Map<String, dynamic>) parse,
    bool refresh = false,
    bool more = false,
  }) async {
    if (more) {
      if (state.isLoading || state.isLoadingMore || !state.data.hasMore) return;
      state.isLoadingMore = true;
    } else {
      if (!refresh && state.loaded && !state.stale) return;
      state.isLoading = !state.loaded;
      state.error = null;
    }
    final generation = ++state._generation;
    state.isFetching = true;
    core.notify();

    try {
      final page = await fetch(more ? state.data.nextOffset : 0);
      if (generation != state._generation) return;
      state.data = Paged.fromPage(page, parse, previous: more ? state.data : null);
      state.loaded = true;
      state.stale = false;
    } catch (e) {
      if (generation != state._generation) return;
      state.error = extractErrorMessage(e);
    } finally {
      if (generation == state._generation) {
        state.isLoading = false;
        state.isLoadingMore = false;
        state.isFetching = false;
        core.notify();
      }
    }
  }

  /// Loads a value into [state], reusing it unless it is missing, stale or
  /// [refresh] is set. Returns the value available afterwards.
  Future<T?> loadValue<T>(
    LoadState<T> state,
    Future<T> Function() fetch, {
    bool refresh = false,
  }) async {
    if (!refresh && state.value != null && !state.stale) return state.value;

    final generation = ++state._generation;
    state.isLoading = state.value == null;
    state.isFetching = true;
    state.error = null;
    core.notify();

    try {
      final value = await fetch();
      if (generation == state._generation) {
        state.value = value;
        state.stale = false;
      }
    } catch (e) {
      if (generation == state._generation) state.error = extractErrorMessage(e);
    } finally {
      if (generation == state._generation) {
        state.isLoading = false;
        state.isFetching = false;
        core.notify();
      }
    }
    return state.value;
  }
}
