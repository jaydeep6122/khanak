import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/brickMark.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// [total] split into [count] shares that add up exactly: the same to the
/// paisa, leftover paise one each to the first. Matches the server.
List<double> splitEqually(double total, int count) {
  if (count == 0) return const [];
  final paise = (total * 100).round();
  final base = paise ~/ count;
  final leftover = paise - base * count;
  return [for (var i = 0; i < count; i++) (base + (i < leftover ? 1 : 0)) / 100];
}

/// One group of workers paid together while a count or unloading is being
/// filled in: who they are, and any amounts the owner set by hand.
class GroupDraft {
  WorkType type;
  final List<Worker> workers;

  /// Amounts set by hand, by worker id. The rest share what is left.
  final Map<String, double> amounts;

  GroupDraft({required this.type, List<Worker>? workers, Map<String, double>? amounts})
    : workers = workers ?? [],
      amounts = amounts ?? {};

  /// What the whole group earns: from the rate, or the hand-set amounts when
  /// every worker has one.
  double total({required int bricks, int? trips, required double? rate}) {
    if (workers.isNotEmpty && workers.every((w) => amounts.containsKey(w.id))) {
      return workers.fold(0.0, (sum, w) => sum + amounts[w.id]!);
    }
    final units = type.payUnit == PayUnit.perTrip ? (trips ?? 0) : bricks;
    final withRate = WorkType(
      id: type.id,
      code: type.code,
      name: type.name,
      payUnit: type.payUnit,
      rate: rate,
      isGroup: true,
      isActive: true,
    );
    return withRate.payFor(units) ?? 0;
  }

  /// Each worker's share, in the order picked.
  List<double> shares(double total) {
    final setByHand = workers.where((w) => amounts.containsKey(w.id)).fold(0.0, (sum, w) => sum + amounts[w.id]!);
    final others = workers.where((w) => !amounts.containsKey(w.id)).length;
    final split = splitEqually((total - setByHand).clamp(0, double.infinity), others);
    var next = 0;
    return [for (final w in workers) amounts[w.id] ?? split[next++]];
  }

  /// Hand-set amounts must leave something (or exactly nothing) for the rest.
  bool fits(double total) {
    final setByHand = workers.where((w) => amounts.containsKey(w.id)).fold(0.0, (sum, w) => sum + amounts[w.id]!);
    final others = workers.length - workers.where((w) => amounts.containsKey(w.id)).length;
    return others == 0 || setByHand <= total + 0.001;
  }

  /// The group as the API takes it. Without hand-set amounts the server
  /// splits the rate's total itself.
  Map<String, dynamic> toJson(double total) {
    if (amounts.isEmpty) {
      return {
        'work_type_id': type.id,
        'workers': [for (final w in workers) {'worker_id': w.id}],
      };
    }
    final shares = this.shares(total);
    return {
      'work_type_id': type.id,
      'total_amount': shares.fold(0.0, (a, b) => a + b).toStringAsFixed(2),
      'workers': [
        for (var i = 0; i < workers.length; i++) {'worker_id': workers[i].id, 'amount': shares[i].toStringAsFixed(2)},
      ],
    };
  }
}

/// A group's card on a form: its kind of work (when there is a choice), the
/// workers ticked, and what each gets. The owner or munim can tap a share to
/// change it; the others then share what is left.
class GroupEditor extends StatelessWidget {
  final String title;
  final GroupDraft group;

  /// Whose main work this is: they are listed when picking.
  final MainWork role;
  final List<WorkType> typeChoices;
  final int bricks;
  final int? trips;
  final double? rate;
  final bool canChangeAmounts;
  final VoidCallback onChanged;

  const GroupEditor({
    super.key,
    required this.title,
    required this.group,
    required this.role,
    required this.typeChoices,
    required this.bricks,
    required this.trips,
    required this.rate,
    required this.canChangeAmounts,
    required this.onChanged,
  });

  Future<void> _pickWorkers(BuildContext context) async {
    final picked = await pickWorkers(context, title: title, role: role, initial: group.workers);
    if (picked == null) return;
    group.workers
      ..clear()
      ..addAll(picked);
    group.amounts.removeWhere((id, _) => !picked.any((w) => w.id == id));
    onChanged();
  }

  Future<void> _editAmount(BuildContext context, Worker worker, double current) async {
    final controller = TextEditingController(text: Formatters.formatDouble(current));
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(worker.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [DecimalInputFormatter(decimals: 2)],
          style: context.text.headlineSmall,
          decoration: InputDecoration(prefixText: '₹ ', helperText: 'share_hand_help'.tr()),
        ),
        actions: [
          if (group.amounts.containsKey(worker.id))
            TextButton(onPressed: () => Navigator.of(context).pop(''), child: Text('share_equal'.tr())),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: Text('save'.tr())),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final amount = double.tryParse(value);
    if (value.isEmpty || amount == null) {
      group.amounts.remove(worker.id);
    } else {
      group.amounts[worker.id] = amount;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = group.total(bricks: bricks, trips: trips, rate: rate);
    final shares = group.shares(total);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              if (group.workers.isNotEmpty)
                Text(Formatters.formatCurrency(total), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          if (typeChoices.length > 1) ...[
            const SizedBox(height: AppTheme.spaceSm),
            ChoiceRow<WorkType>(
              options: typeChoices,
              selected: typeChoices.where((t) => t.id == group.type.id).firstOrNull,
              label: (type) => '${type.label} · ${'pay_unit_${type.payUnit.value}'.tr()}',
              onSelected: (type) {
                group.type = type;
                group.amounts.clear();
                onChanged();
              },
            ),
          ],
          if (group.workers.isNotEmpty && rate != null && rate! > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceXs),
              child: Text(
                'group_rate_line'.tr(
                  namedArgs: {
                    'rate': Formatters.formatCurrency(rate!),
                    'unit': 'pay_unit_${group.type.payUnit.value}'.tr(),
                    'count': '${group.workers.length}',
                  },
                ),
                style: context.text.bodySmall,
              ),
            ),
          const SizedBox(height: AppTheme.spaceSm),
          for (var i = 0; i < group.workers.length; i++)
            InkWell(
              onTap: canChangeAmounts ? () => _editAmount(context, group.workers[i], shares[i]) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs + 2),
                child: Row(
                  children: [
                    InitialBadge(letter: group.workers[i].initial, size: 32),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(child: Text(group.workers[i].displayName, style: context.text.bodyLarge)),
                    Text(
                      Formatters.formatCurrency(shares[i]),
                      style: context.text.titleSmall?.copyWith(
                        color: group.amounts.containsKey(group.workers[i].id) ? colors.warning : colors.ink,
                      ),
                    ),
                    if (canChangeAmounts) ...[
                      const SizedBox(width: AppTheme.spaceXs),
                      Icon(Icons.edit_rounded, size: 16, color: colors.muted),
                    ],
                  ],
                ),
              ),
            ),
          if (!group.fits(total))
            Text('shares_too_much'.tr(), style: context.text.bodySmall?.copyWith(color: colors.danger)),
          const SizedBox(height: AppTheme.spaceXs),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              _pickWorkers(context);
            },
            icon: Icon(group.workers.isEmpty ? Icons.group_add_rounded : Icons.edit_note_rounded),
            label: Text(group.workers.isEmpty ? 'pick_workers'.tr() : 'change_workers'.tr()),
          ),
        ],
      ),
    );
  }
}
