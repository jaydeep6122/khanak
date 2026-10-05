import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/textInputDialog.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/factory.dart';

/// The factory's own trucks, picked when bricks go to the kiln by truck.
class TrucksScreen extends StatefulWidget {
  const TrucksScreen({super.key});

  @override
  State<TrucksScreen> createState() => _TrucksScreenState();
}

class _TrucksScreenState extends State<TrucksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().factory.fetchTrucks());
  }

  Future<void> _edit([Truck? truck]) async {
    final number = await showTextInputDialog(
      context,
      title: truck == null ? 'truck_new'.tr() : 'truck_edit'.tr(),
      label: 'truck_number'.tr(),
      initialValue: truck?.number,
      maxLength: 20,
      textCapitalization: TextCapitalization.characters,
    );
    if (number == null || !mounted) return;
    final module = context.read<Core>().factory;
    final ok = await module.saveTruck(truckId: truck?.id, number: number.toUpperCase(), name: truck?.name);
    if (!ok) showErrorToast(module.error ?? 'error_generic'.tr());
  }

  Future<void> _toggle(Truck truck) async {
    final module = context.read<Core>().factory;
    final ok = await module.saveTruck(truckId: truck.id, number: truck.number, name: truck.name, isActive: !truck.isActive);
    if (!ok) showErrorToast(module.error ?? 'error_generic'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final module = context.watch<Core>().factory;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text('trucks'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_rounded),
        label: Text('truck_new'.tr()),
      ),
      body: LoadStateBody<List<Truck>>(
        state: module.trucks,
        onRetry: () => module.fetchTrucks(refresh: true).then((_) {}),
        builder: (context, trucks) => trucks.isEmpty
            ? EmptyState(icon: Icons.local_shipping_rounded, title: 'no_trucks_yet'.tr())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.fabClearance),
                children: [
                  for (final truck in trucks) ...[
                    AppCard(
                      onTap: () => _edit(truck),
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping_rounded, color: truck.isActive ? colors.primary : colors.muted),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(child: Text(truck.label, style: context.text.titleMedium)),
                          Switch(value: truck.isActive, onChanged: (_) => _toggle(truck)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                  ],
                ],
              ),
      ),
    );
  }
}
