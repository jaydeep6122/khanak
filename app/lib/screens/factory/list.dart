import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/factory/form.dart';
import 'package:khanak/screens/home/home.dart';
import 'package:khanak/types/factory.dart';

/// Every factory the member belongs to. Picking one opens it.
class FactoryListScreen extends StatelessWidget {
  final bool isRoot;

  const FactoryListScreen({super.key, this.isRoot = false});

  Future<void> _open(BuildContext context, Factory factory) async {
    final navigator = Navigator.of(context);
    await context.read<Core>().factory.select(factory);
    navigator.pushAndRemoveUntil(getPageRoute(const HomeScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final module = context.watch<Core>().factory;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: !isRoot, title: Text('factories'.tr())),
      body: RefreshIndicator(
        onRefresh: module.fetchFactories,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          children: [
            for (final factory in module.factories) ...[
              AppCard(
                onTap: () => _open(context, factory),
                borderColor: factory.id == module.selected?.id ? colors.primary : null,
                child: Row(
                  children: [
                    const BrickMark(size: 44),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(factory.name, style: context.text.titleMedium),
                          Text(
                            [factory.role.displayName, if (factory.city != null) factory.city!].join(' · '),
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.muted),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
            ],
            const SizedBox(height: AppTheme.spaceSm),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(getPageRoute(const FactoryFormScreen())),
              icon: const Icon(Icons.add_rounded),
              label: Text('factory_new'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
