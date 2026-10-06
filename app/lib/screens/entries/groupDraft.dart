import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/components/amountDialog.dart';
import 'package:flutter/services.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/rateDialog.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
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

/// The rate to price [type] at: the one an edited entry was made with, unless
/// it was made with none, otherwise today's.
double? keptOrCurrentRate(double? saved, WorkType type) => (saved ?? 0) > 0 ? saved : type.rate;

/// Before saving: a group paid by a rate needs one, unless every share was
/// typed by hand. Work at each worker's own rate needs every worker's own rate (set on
/// the worker); another kind's rate is asked when missing (see
/// [ensureRate]). Returns false while a rate is still missing.
Future<bool> ensureGroupRate(BuildContext context, GroupDraft group, double? rate) async {
  if (group.workers.isEmpty || group.paidByHand) return true;
  if (group.type.atOwnRate) {
    // A supervisor does not see rates: the server checks them.
    if (!canSetRates(context)) return true;
    final missing = group.workers.where((w) => (group.rateOf(w) ?? 0) <= 0).firstOrNull;
    if (missing == null) return true;
    showErrorToast('worker_rate_missing'.tr(namedArgs: {'name': missing.name}));
    return false;
  }
  if (!group.type.payUnit.hasRate || (rate ?? 0) > 0) return true;
  final updated = await ensureRate(context, group.type);
  if (updated == null) return false;
  group.type = updated;
  group.amounts.clear();
  return true;
}

/// Marks the shares of a saved [group] that were typed by hand: those that
/// differ from what the rates give.
void markHandSetShares(GroupDraft draft, WorkGroup group, {required int bricks, int? trips}) {
  final byRate = draft.pay(bricks: bricks, trips: trips, rate: group.rate);
  final byHand = draft.type.atOwnRate
      ? [
          for (var i = 0; i < group.workers.length; i++)
            byRate[i] == null || (group.workers[i].amount - byRate[i]!).abs() > 0.001,
        ]
      : () {
          final equal = splitEqually(group.total, group.workers.length);
          return [for (var i = 0; i < group.workers.length; i++) (group.workers[i].amount - equal[i]).abs() > 0.001];
        }();
  for (var i = 0; i < group.workers.length && i < draft.workers.length; i++) {
    if (byHand[i]) draft.amounts[draft.workers[i].id] = group.workers[i].amount;
  }
}

/// Pay worked out to the paisa, like the server.
double _paisa(double amount) => (amount * 100).round() / 100;

/// One group of workers paid together while a count, unloading or sale is
/// being filled in: who they are, and any amounts the owner set by hand.
///
/// Work at each worker's own rate shares the bricks equally and pays each worker their
/// share at their own rate. Other work shares one total from the kind's
/// rate.
class GroupDraft {
  WorkType type;
  final List<Worker> workers;

  /// Amounts set by hand, by worker id.
  final Map<String, double> amounts;

  /// The rate each worker was paid at when an edited entry was made, by
  /// worker id (work per 1000 bricks). Kept while the worker stays in it.
  final Map<String, double> savedRates;

  GroupDraft({required this.type, List<Worker>? workers, Map<String, double>? amounts, Map<String, double>? savedRates})
    : workers = workers ?? [],
      amounts = amounts ?? {},
      savedRates = savedRates ?? {};

  bool get _atOwnRate => type.atOwnRate;

  /// [worker]'s rate per 1000 bricks: the one an edited entry was made with,
  /// otherwise theirs today. Null when not known.
  double? rateOf(Worker worker) {
    final saved = savedRates[worker.id] ?? 0;
    return saved > 0 ? saved : worker.brickRate;
  }

  /// Each worker's pay, in the order picked. Per 1000 bricks, a share set by
  /// hand leaves the others as they are, and a worker whose rate is not
  /// known has no pay (null). Otherwise the hand-set shares come out of the
  /// rate's total and the others share what is left.
  List<double?> pay({required int bricks, int? trips, double? rate}) {
    if (_atOwnRate) {
      final share = workers.isEmpty ? 0 : bricks / workers.length;
      return [
        for (final w in workers)
          amounts[w.id] ?? (rateOf(w) == null ? null : _paisa(type.payFor(share, rate: rateOf(w))!)),
      ];
    }
    return shares(total(bricks: bricks, trips: trips, rate: rate));
  }

  /// What the whole group earns: from the rates, or the hand-set amounts when
  /// every worker has one.
  double total({required int bricks, int? trips, required double? rate}) {
    if (paidByHand) return workers.fold(0.0, (sum, w) => sum + amounts[w.id]!);
    if (_atOwnRate) return pay(bricks: bricks).fold(0.0, (sum, amount) => sum + (amount ?? 0));
    final units = type.payUnit == PayUnit.perTrip ? (trips ?? 0) : bricks;
    return type.payFor(units, rate: rate) ?? 0;
  }

  /// Every worker's amount was typed by hand, so no rate is needed.
  bool get paidByHand => workers.isNotEmpty && workers.every((w) => amounts.containsKey(w.id));

  /// Each worker's share of [total] (work at the kind's rate), in the order
  /// picked.
  List<double> shares(double total) {
    final setByHand = workers.where((w) => amounts.containsKey(w.id)).fold(0.0, (sum, w) => sum + amounts[w.id]!);
    final others = workers.where((w) => !amounts.containsKey(w.id)).length;
    final split = splitEqually((total - setByHand).clamp(0, double.infinity), others);
    var next = 0;
    return [for (final w in workers) amounts[w.id] ?? split[next++]];
  }

  /// Hand-set amounts must leave something (or exactly nothing) for the
  /// rest. Per 1000 bricks, a share set by hand takes nothing from the others.
  bool fits(double total) {
    if (_atOwnRate) return true;
    final setByHand = workers.where((w) => amounts.containsKey(w.id)).fold(0.0, (sum, w) => sum + amounts[w.id]!);
    final others = workers.length - workers.where((w) => amounts.containsKey(w.id)).length;
    return others == 0 || setByHand <= total + 0.001;
  }

  /// The group as the API takes it. Without hand-set amounts the server
  /// works the pay out itself; with any, every worker's amount is sent.
  Map<String, dynamic> toJson({required int bricks, int? trips, double? rate}) {
    if (amounts.isEmpty) {
      return {
        'work_type_id': type.id,
        'workers': [
          for (final w in workers) {'worker_id': w.id},
        ],
      };
    }
    final shares = [for (final amount in pay(bricks: bricks, trips: trips, rate: rate)) amount ?? 0.0];
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
/// workers picked, and what each gets. The owner or munim can tap a share to
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

  /// Save was tried with nobody picked: the pick row shows in red.
  final bool missing;

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
    this.missing = false,
  });

  /// No rate is set for this kind of work yet, so the group would earn
  /// nothing. (Work per 1000 bricks is paid at each worker's own rate.)
  bool get _rateMissing => group.type.payUnit.hasRate && !group.type.atOwnRate && (rate ?? 0) <= 0;

  Future<void> _pickWorkers(BuildContext context) async {
    // A worker paid by the day is never paid a group's share.
    final picked = await pickWorkers(context, title: title, role: role, initial: group.workers, paidByDay: false);
    if (picked == null) return;
    group.workers
      ..clear()
      ..addAll(picked);
    group.amounts.removeWhere((id, _) => !picked.any((w) => w.id == id));
    group.savedRates.removeWhere((id, _) => !picked.any((w) => w.id == id));
    onChanged();
    // The first time this kind of work is used, the owner sets its rate
    // right here instead of in a separate screen.
    if (picked.isNotEmpty && _rateMissing && context.mounted && canSetRates(context)) {
      await _setRate(context);
    }
  }

  Future<void> _setRate(BuildContext context) async {
    final updated = await askRate(context, group.type);
    if (updated == null) return;
    group.type = updated;
    group.amounts.clear();
    onChanged();
  }

  Future<void> _editAmount(BuildContext context, Worker worker, double? current) async {
    final value = await showAmountDialog(
      context,
      title: worker.name,
      initialValue: current == null ? '' : Formatters.formatDouble(current),
      helperText: group.type.atOwnRate ? null : 'share_hand_help'.tr(),
      resetText: group.amounts.containsKey(worker.id) ? 'share_equal'.tr() : null,
    );
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
    final shares = group.pay(bricks: bricks, trips: trips, rate: rate);
    final canSet = canSetRates(context);
    final empty = group.workers.isEmpty;
    final atOwnRate = group.type.atOwnRate;

    /// Per 1000 bricks: each worker's share of the bricks at their rate.
    String? ownRateLine(Worker worker) {
      if (!atOwnRate || !canSet) return null;
      final own = group.rateOf(worker);
      if (own == null) return 'worker_rate_not_set'.tr();
      return 'worker_share_line'.tr(
        namedArgs: {
          'bricks': Formatters.formatCount(bricks / group.workers.length),
          'rate': Formatters.formatCurrency(own),
        },
      );
    }

    final rows = <Widget>[
      for (var i = 0; i < group.workers.length; i++)
        GroupedRow(
          onTap: canChangeAmounts ? () => _editAmount(context, group.workers[i], shares[i]) : null,
          chevron: false,
          leading: InitialBadge(letter: group.workers[i].initial, size: 34),
          title: group.workers[i].displayName,
          // A share set by hand shows in amber; the others split the rest.
          subtitle: group.amounts.containsKey(group.workers[i].id)
              ? 'share_set_by_hand'.tr()
              : ownRateLine(group.workers[i]),
          value: shares[i] == null ? '—' : Formatters.formatCurrency(shares[i]!),
          valueColor: group.amounts.containsKey(group.workers[i].id) ? colors.warning : null,
        ),
      GroupedRow(
        onTap: () {
          HapticFeedback.selectionClick();
          _pickWorkers(context);
        },
        chevron: false,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: missing ? colors.dangerSoft : colors.primarySoft, shape: BoxShape.circle),
          child: Icon(
            empty ? Icons.group_add_rounded : Icons.edit_rounded,
            size: 18,
            color: missing ? colors.danger : colors.primary,
          ),
        ),
        title: empty ? 'pick_workers'.tr() : 'change_workers'.tr(),
        titleColor: missing ? colors.danger : colors.primary,
      ),
    ];

    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppTheme.radiusLg), boxShadow: context.cardShadow),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 14, AppTheme.spaceLg, 4),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: context.text.titleSmall)),
                  if (!empty && (total > 0 || !atOwnRate || canSet))
                    Text(Formatters.formatCurrency(total), style: context.text.titleSmall),
                ],
              ),
            ),
            if (!empty && !atOwnRate && rate != null && rate! > 0)
              // The owner or munim taps the rate to change it; the new rate
              // is used from now on.
              InkWell(
                onTap: canSet ? () => _setRate(context) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: 2),
                  child: Row(
                    children: [
                      Flexible(
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
                      if (canSet) ...[
                        const SizedBox(width: AppTheme.spaceXs),
                        Icon(Icons.edit_rounded, size: 13, color: colors.muted),
                      ],
                    ],
                  ),
                ),
              ),
            if (typeChoices.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, AppTheme.spaceSm, AppTheme.spaceLg, 0),
                child: Wrap(
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceSm,
                  children: [
                    for (final type in typeChoices)
                      _TypeChip(
                        text: '${type.label} · ${'pay_unit_${type.payUnit.value}'.tr()}',
                        selected: type.id == group.type.id,
                        onTap: () {
                          group.type = type;
                          group.amounts.clear();
                          onChanged();
                        },
                      ),
                  ],
                ),
              ),
            if (_rateMissing)
              Container(
                margin: const EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceSm, AppTheme.spaceMd, 0),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  AppTheme.spaceXs,
                  AppTheme.spaceXs,
                  AppTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: colors.warningSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, size: 18, color: colors.warning),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        canSet ? 'rate_missing_line'.tr() : 'rate_ask_owner'.tr(),
                        style: context.text.bodySmall?.copyWith(color: colors.warning),
                      ),
                    ),
                    if (canSet) TextButton(onPressed: () => _setRate(context), child: Text('set_rate'.tr())),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.spaceXs),
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(indent: 62, height: 0.6), rows[i]],
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        if (!group.fits(total))
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceXs, left: AppTheme.spaceXs),
            child: Text('shares_too_much'.tr(), style: context.text.bodySmall?.copyWith(color: colors.danger)),
          ),
      ],
    );
  }
}

/// A kind of work to pay the group as.
class _TypeChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.ink : colors.surfaceAlt,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            text,
            style: context.text.labelMedium?.copyWith(
              color: selected ? colors.onInk : colors.inkSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
