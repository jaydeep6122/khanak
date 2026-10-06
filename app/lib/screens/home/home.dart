import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/floatingTabBar.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/screens/entries/list.dart';
import 'package:khanak/screens/home/dashboard.dart';
import 'package:khanak/screens/home/newEntrySheet.dart';
import 'package:khanak/screens/more/more.dart';
import 'package:khanak/screens/trade/parties.dart';
import 'package:khanak/screens/workers/list.dart';

/// The app after a factory is open: home, workers, credit (entries for a
/// supervisor) and more, with "+" in the middle for a new entry.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final core = context.read<Core>();
      core.factory.fetchWorkTypes();
      core.worker.fetchWorkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the language changes.
    context.locale;
    final supervisor = context.select<Core, bool>((core) => core.isSupervisor);

    return PopScope(
      // Back on another tab goes home first.
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: [
            DashboardTab(onOpenTab: (tab) => setState(() => _tab = tab)),
            const WorkersTab(),
            // A supervisor does not see credit; their own entries instead.
            if (supervisor) const EntriesTab(asTab: true) else const PartiesScreen(asTab: true),
            const MoreTab(),
          ],
        ),
        bottomNavigationBar: FloatingTabBar(
          selected: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
          centerLabel: 'new_entry'.tr(),
          onCenter: () => showNewEntrySheet(context),
          tabs: [
            FloatingTab(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'tab_home'.tr()),
            FloatingTab(
              icon: Icons.people_outline_rounded,
              selectedIcon: Icons.people_rounded,
              label: 'tab_workers'.tr(),
            ),
            if (supervisor)
              FloatingTab(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'tab_entries'.tr(),
              )
            else
              FloatingTab(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'credit'.tr(),
              ),
            FloatingTab(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'tab_more'.tr()),
          ],
        ),
      ),
    );
  }
}
