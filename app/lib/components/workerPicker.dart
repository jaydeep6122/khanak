import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/workers/form.dart';
import 'package:khanak/types/worker.dart';

/// Picks one worker. Null when dismissed. With [role], only workers whose
/// main work it is are listed, until "show all workers" is tapped.
Future<Worker?> pickWorker(
  BuildContext context, {
  required String title,
  MainWork? role,
  Set<String> exclude = const {},
}) async {
  final picked = await _showPicker(context, title: title, multi: false, role: role, exclude: exclude);
  return picked?.firstOrNull;
}

/// Picks any number of workers (a loading group, a nikasi group). Null when
/// dismissed; [initial] starts ticked.
Future<List<Worker>?> pickWorkers(
  BuildContext context, {
  required String title,
  MainWork? role,
  List<Worker> initial = const [],
}) => _showPicker(context, title: title, multi: true, role: role, initial: initial);

Future<List<Worker>?> _showPicker(
  BuildContext context, {
  required String title,
  required bool multi,
  MainWork? role,
  List<Worker> initial = const [],
  Set<String> exclude = const {},
}) {
  context.read<Core>().worker.fetchWorkers();
  return showModalBottomSheet<List<Worker>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _WorkerPicker(title: title, multi: multi, role: role, initial: initial, exclude: exclude),
    ),
  );
}

class _WorkerPicker extends StatefulWidget {
  final String title;
  final bool multi;
  final MainWork? role;
  final List<Worker> initial;
  final Set<String> exclude;

  const _WorkerPicker({
    required this.title,
    required this.multi,
    required this.role,
    required this.initial,
    required this.exclude,
  });

  @override
  State<_WorkerPicker> createState() => _WorkerPickerState();
}

class _WorkerPickerState extends State<_WorkerPicker> {
  String _search = '';
  late final List<Worker> _picked = [...widget.initial];

  /// Someone outside their main work did it this time (a loader stacking).
  bool _showAll = false;

  bool _isPicked(Worker worker) => _picked.any((w) => w.id == worker.id);

  void _tap(Worker worker) {
    if (!widget.multi) return Navigator.of(context).pop([worker]);
    setState(() {
      _isPicked(worker) ? _picked.removeWhere((w) => w.id == worker.id) : _picked.add(worker);
    });
  }

  /// A new worker without leaving the form: their main work is the one being
  /// picked for, and their rate is asked like anywhere else.
  Future<void> _quickAdd() async {
    final worker = await Navigator.of(context).push<Worker>(
      getPageRoute(
        WorkerFormScreen(initialMainWork: widget.role, initialName: _search.isEmpty ? null : _search),
      ),
    );
    if (worker == null || !mounted) return;
    await context.read<Core>().worker.fetchWorkers(refresh: true);
    _tap(worker);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final colors = context.colors;
    final query = _search.toLowerCase();
    final role = widget.role;
    final ofRole = role == null || _showAll;
    final workers = core.worker.activeWorkers
        .where((w) => !widget.exclude.contains(w.id))
        .where((w) => ofRole || w.mainWork == role || _isPicked(w))
        .where((w) => query.isEmpty || w.displayName.toLowerCase().contains(query))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceSm),
          child: Row(
            children: [
              Expanded(child: Text(widget.title, style: context.text.headlineSmall)),
              if (core.can(MemberRole.munim))
                TextButton.icon(
                  onPressed: _quickAdd,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: Text('worker_new'.tr()),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
          child: TextField(
            onChanged: (value) => setState(() => _search = value.trim()),
            decoration: InputDecoration(
              hintText: 'search_worker'.tr(),
              prefixIcon: Icon(Icons.search_rounded, size: 21, color: colors.muted),
              isDense: true,
              fillColor: colors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Expanded(
          child: core.worker.workers.value == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: workers.length + 1,
                  itemBuilder: (context, index) {
                    if (index == workers.length) {
                      return Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        child: Column(
                          children: [
                            if (workers.isEmpty)
                              Text(
                                role != null && !_showAll
                                    ? 'no_workers_of_role'.tr(namedArgs: {'role': role.displayName})
                                    : 'no_workers_found'.tr(),
                                style: context.text.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            if (role != null && !_showAll)
                              TextButton(
                                onPressed: () => setState(() => _showAll = true),
                                child: Text('show_all_workers'.tr()),
                              ),
                          ],
                        ),
                      );
                    }
                    final worker = workers[index];
                    final picked = _isPicked(worker);
                    return ListTile(
                      minVerticalPadding: 10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
                      leading: InitialBadge(letter: worker.initial, size: 40),
                      title: Text(worker.name),
                      subtitle: Text(
                        [
                          worker.mainWork.displayName,
                          if (worker.displayName != worker.name) worker.displayName.substring(worker.name.length + 3),
                        ].join(' · '),
                      ),
                      trailing: widget.multi
                          ? Icon(
                              picked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: picked ? colors.primary : colors.muted.withValues(alpha: 0.5),
                              size: 26,
                            )
                          : null,
                      onTap: () => _tap(worker),
                    );
                  },
                ),
        ),
        if (widget.multi)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: AppButton(
                text: 'workers_done'.tr(namedArgs: {'count': '${_picked.length}'}),
                onPressed: () => Navigator.of(context).pop(_picked),
              ),
            ),
          ),
      ],
    );
  }
}
