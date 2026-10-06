import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/entries/brickCountForm.dart';
import 'package:khanak/screens/entries/unloadingForm.dart';
import 'package:khanak/screens/entries/workEntryForm.dart';
import 'package:khanak/screens/trade/expenseForm.dart';
import 'package:khanak/screens/trade/saleForm.dart';
import 'package:khanak/screens/workers/transactionForm.dart';

/// Opens [screen] and, when it saved something, marks the books as changed
/// so totals and lists reload.
Future<void> openEntry(BuildContext context, Widget screen) async {
  final core = context.read<Core>();
  final saved = await Navigator.of(context).push(getPageRoute(screen));
  if (saved != null) core.markBooksChanged();
}

/// Picks a worker, then opens the advance form for them. A supervisor never
/// gives an advance to themselves.
Future<void> giveAdvance(BuildContext context) async {
  final core = context.read<Core>();
  final self = core.isSupervisor ? core.openFactory?.workerId : null;
  final worker = await pickWorker(context, title: 'advance_pick_worker'.tr(), exclude: {if (self != null) self});
  if (worker == null || !context.mounted) return;
  await openEntry(context, TransactionFormScreen(worker: worker, kind: TxnKind.advance));
}

class EntryAction {
  final Tint tint;
  final String label;
  final String description;
  final Future<void> Function(BuildContext context) open;

  const EntryAction({required this.tint, required this.label, required this.description, required this.open});
}

/// Every kind of everyday entry. A supervisor makes only counts, nikasi and
/// advances.
List<EntryAction> entryActions(Core core) => [
  EntryAction(
    tint: Tint.bricks,
    label: 'action_brick_count'.tr(),
    description: 'new_count_desc'.tr(),
    open: (context) => openEntry(context, const BrickCountFormScreen()),
  ),
  EntryAction(
    tint: Tint.fire,
    label: 'action_unloading'.tr(),
    description: 'new_unloading_desc'.tr(),
    open: (context) => openEntry(context, const UnloadingFormScreen()),
  ),
  EntryAction(tint: Tint.money, label: 'action_advance'.tr(), description: 'new_advance_desc'.tr(), open: giveAdvance),
  if (!core.isSupervisor) ...[
    EntryAction(
      tint: Tint.truck,
      label: 'action_sale'.tr(),
      description: 'new_sale_desc'.tr(),
      open: (context) => openEntry(context, const SaleFormScreen()),
    ),
    EntryAction(
      tint: Tint.expense,
      label: 'action_expense'.tr(),
      description: 'new_expense_desc'.tr(),
      open: (context) => openEntry(context, const ExpenseFormScreen()),
    ),
    EntryAction(
      tint: Tint.work,
      label: 'action_other_work'.tr(),
      description: 'new_other_work_desc'.tr(),
      open: (context) => openEntry(context, const WorkEntryFormScreen()),
    ),
  ],
];

/// The sheet behind the "+" in the tab bar: a tile for each kind of entry.
Future<void> showNewEntrySheet(BuildContext context) async {
  final core = context.read<Core>();
  if (core.openFactory?.canWrite == false) return;
  final picked = await showModalBottomSheet<EntryAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NewEntrySheet(actions: entryActions(core)),
  );
  if (picked != null && context.mounted) await picked.open(context);
}

class _NewEntrySheet extends StatelessWidget {
  final List<EntryAction> actions;

  const _NewEntrySheet({required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('new_entry'.tr(), style: context.text.headlineSmall)),
                Material(
                  color: colors.surfaceAlt,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(Icons.close_rounded, size: 18, color: colors.inkSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.32,
              children: [
                for (final action in actions)
                  ActionTile(action: action, onTap: () => Navigator.of(context).pop(action)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A white tile with a tinted icon, a name and what it is for.
class ActionTile extends StatelessWidget {
  final EntryAction action;
  final VoidCallback onTap;

  const ActionTile({super.key, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: context.cardShadow),
      child: Material(
        color: context.colors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TintIcon(tint: action.tint, size: 42),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(fontSize: 16),
                    ),
                    Text(
                      action.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
