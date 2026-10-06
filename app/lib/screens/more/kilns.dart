import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/textInputDialog.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/factory.dart';

/// The factory's kilns (bhatha). Every count into a kiln and every nikasi
/// names one, so each kiln's stock is known.
class KilnsScreen extends StatefulWidget {
  const KilnsScreen({super.key});

  @override
  State<KilnsScreen> createState() => _KilnsScreenState();
}

class _KilnsScreenState extends State<KilnsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final core = context.read<Core>();
      core.factory.fetchKilns();
      core.report.fetchSummary();
    });
  }

  Future<void> _edit([Kiln? kiln]) async {
    final name = await showTextInputDialog(
      context,
      title: kiln == null ? 'kiln_new'.tr() : 'kiln_rename'.tr(),
      label: 'kiln_name'.tr(),
      initialValue: kiln?.name,
      textCapitalization: TextCapitalization.words,
    );
    if (name == null || !mounted) return;
    final module = context.read<Core>().factory;
    if (!await module.saveKiln(kilnId: kiln?.id, name: name)) {
      showErrorToast(module.error ?? 'error_generic'.tr());
    }
  }

  Future<void> _toggle(Kiln kiln) async {
    final module = context.read<Core>().factory;
    if (!await module.saveKiln(kilnId: kiln.id, name: kiln.name, isActive: !kiln.isActive)) {
      showErrorToast(module.error ?? 'error_generic'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final module = core.factory;
    final stock = {for (final k in core.report.summary.value?.stock.kilns ?? const []) k.name: k.quantity};
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text('kilns'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_rounded),
        label: Text('kiln_new'.tr()),
      ),
      body: LoadStateBody<List<Kiln>>(
        state: module.kilns,
        onRetry: () => module.fetchKilns(refresh: true).then((_) {}),
        builder: (context, kilns) => kilns.isEmpty
            ? EmptyState(icon: Icons.local_fire_department_rounded, title: 'no_kilns_yet'.tr())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.fabClearance),
                children: [
                  for (final kiln in kilns) ...[
                    AppCard(
                      onTap: () => _edit(kiln),
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: kiln.isActive ? colors.primary : colors.muted),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kiln.name, style: context.text.titleMedium),
                                if (stock[kiln.name] != null)
                                  Text(
                                    'kiln_holds'.tr(namedArgs: {'bricks': Formatters.formatCount(stock[kiln.name]!)}),
                                    style: context.text.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Switch(value: kiln.isActive, onChanged: (_) => _toggle(kiln)),
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
