import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/screens/entries/list.dart';
import 'package:khanak/screens/home/dashboard.dart';
import 'package:khanak/screens/more/more.dart';
import 'package:khanak/screens/workers/list.dart';

/// The app after a factory is open: home, workers, entries and more.
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

    return PopScope(
      // Back on another tab goes home first.
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: const [DashboardTab(), WorkersTab(), EntriesTab(), MoreTab()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (tab) => setState(() => _tab = tab),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: 'tab_home'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups_rounded),
              label: 'tab_workers'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: 'tab_entries'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_rounded),
              selectedIcon: const Icon(Icons.menu_open_rounded),
              label: 'tab_more'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
