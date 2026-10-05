import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/errorHandler.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/types/report.dart';

/// "What did the supervisor enter today?": everything anyone created,
/// changed or cancelled on a day, newest first.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  DateTime _date = DateTime.now();
  List<Activity>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await context.read<Core>().report.fetchActivity(date: apiDate(_date));
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    }
  }

  /// "created a brick count", "cancelled an advance".
  String _describe(Activity item) {
    final action = 'activity_action_${item.action}'.tr();
    final what = 'activity_entity_${item.entityType}'.tr();
    return '$action · $what';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final time = DateFormat('hh:mm a', 'en_US');

    return Scaffold(
      appBar: AppBar(title: Text('activity'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceSm),
            child: DateField(
              label: 'date'.tr(),
              value: _date,
              onChanged: (d) {
                _date = d;
                _load();
              },
            ),
          ),
          Expanded(
            child: _error != null
                ? AppErrorWidget(errorMessage: _error!, onRetry: _load)
                : items == null
                ? const LoadingIndicator()
                : items.isEmpty
                ? EmptyState(icon: Icons.history_rounded, title: 'no_activity'.tr())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceSm),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.userName ?? '', style: context.text.titleSmall),
                                    Text(_describe(item), style: context.text.bodyMedium),
                                  ],
                                ),
                              ),
                              Text(time.format(item.at.toLocal()), style: context.text.bodySmall),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
