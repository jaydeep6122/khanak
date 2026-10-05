import 'package:easy_localization/easy_localization.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/helpers/json.dart';

// The names the server gives the built-in kinds of work. While the owner has
// not renamed one, the app shows its own translation instead.
const _builtInNames = {
  'molding': 'Brick making',
  'kiln_loading': 'Kiln loading',
  'stacking': 'Kiln stacking and firing',
  'unloading': 'Kiln unloading',
  'truck_loading': 'Truck loading',
  'daily': 'Day work',
  'salary': 'Monthly salary',
  'lumpsum': 'Lump sum',
};

/// The label for a kind of work: the translation for a built-in one the
/// owner kept, otherwise the owner's own name.
String workTypeLabel(String? code, String name) =>
    code != null && _builtInNames[code] == name ? 'work_type_$code'.tr() : name;

/// A kind of work and what it pays.
class WorkType {
  final String id;

  /// Built-in kinds: molding, kiln_loading, stacking, unloading,
  /// truck_loading, daily, salary, lumpsum. Null for the owner's own.
  final String? code;
  final String name;
  final PayUnit payUnit;
  final double? rate;

  /// One total shared by the workers who did it.
  final bool isGroup;
  final bool isActive;

  const WorkType({
    required this.id,
    this.code,
    required this.name,
    required this.payUnit,
    this.rate,
    required this.isGroup,
    required this.isActive,
  });

  factory WorkType.fromJson(Map<String, dynamic> json) => WorkType(
    id: json['id'] as String,
    code: json['code'] as String?,
    name: asString(json['name']),
    payUnit: PayUnit.fromString(json['pay_unit'] as String?),
    rate: asDoubleOrNull(json['rate']),
    isGroup: asBool(json['is_group']),
    isActive: asBool(json['is_active'], true),
  );

  String get label => workTypeLabel(code, name);

  /// Pay for [units]: bricks, days or trips. Null for lump sums and salary.
  double? payFor(num units) {
    final r = rate;
    if (r == null) return null;
    return switch (payUnit) {
      PayUnit.per1000 => units * r / 1000,
      PayUnit.perLakh => units * r / 100000,
      PayUnit.perDay || PayUnit.perTrip => units * r,
      _ => null,
    };
  }
}

/// One line of a worker's account.
class LedgerLine {
  /// 'work' or a [TxnKind] value.
  final String entryKind;
  final String entryId;
  final DateTime date;
  final String? workTypeId;
  final String? workTypeCode;
  final String? workTypeName;
  final PayUnit? payUnit;
  final double? quantity;
  final double? rate;
  final double? groupTotal;
  final int? groupSize;

  /// The factory owes the worker more.
  final double credit;

  /// The factory owes the worker less.
  final double debit;

  /// manual, brick_count, kiln_unloading or salary, for work lines.
  final String? source;
  final String? brickCountId;
  final String? kilnUnloadingId;
  final String? note;

  const LedgerLine({
    required this.entryKind,
    required this.entryId,
    required this.date,
    this.workTypeId,
    this.workTypeCode,
    this.workTypeName,
    this.payUnit,
    this.quantity,
    this.rate,
    this.groupTotal,
    this.groupSize,
    required this.credit,
    required this.debit,
    this.source,
    this.brickCountId,
    this.kilnUnloadingId,
    this.note,
  });

  factory LedgerLine.fromJson(Map<String, dynamic> json) {
    final payUnit = json['pay_unit'] as String?;
    return LedgerLine(
      entryKind: asString(json['entry_kind']),
      entryId: json['entry_id'] as String,
      date: asDate(json['entry_date']) ?? DateTime.now(),
      workTypeId: json['work_type_id'] as String?,
      workTypeCode: json['work_type_code'] as String?,
      workTypeName: json['work_type_name'] as String?,
      payUnit: payUnit == null ? null : PayUnit.fromString(payUnit),
      quantity: asDoubleOrNull(json['quantity']),
      rate: asDoubleOrNull(json['rate']),
      groupTotal: asDoubleOrNull(json['group_total']),
      groupSize: asIntOrNull(json['group_size']),
      credit: asDouble(json['credit']),
      debit: asDouble(json['debit']),
      source: json['source'] as String?,
      brickCountId: json['brick_count_id'] as String?,
      kilnUnloadingId: json['kiln_unloading_id'] as String?,
      note: json['note'] as String?,
    );
  }

  bool get isWork => entryKind == 'work';
  TxnKind? get txnKind => isWork ? null : TxnKind.fromString(entryKind);

  /// Positive when the line adds to what the factory owes the worker.
  double get amount => credit - debit;

  String get title => isWork
      ? workTypeLabel(workTypeCode, workTypeName ?? '')
      : txnKind!.displayName;
}

/// What a worker's account adds up to.
class LedgerTotals {
  final double earned;
  final double advances;
  final double settled;
  final double recovered;

  const LedgerTotals({
    required this.earned,
    required this.advances,
    required this.settled,
    required this.recovered,
  });

  factory LedgerTotals.fromJson(Map<String, dynamic> json) => LedgerTotals(
    earned: asDouble(json['earned']),
    advances: asDouble(json['advances']),
    settled: asDouble(json['settled']),
    recovered: asDouble(json['recovered']),
  );

  static const empty = LedgerTotals(earned: 0, advances: 0, settled: 0, recovered: 0);
}

/// One worker's share in group work.
class GroupShare {
  final String workerId;
  final String name;
  final String? nickname;
  final double amount;

  const GroupShare({
    required this.workerId,
    required this.name,
    this.nickname,
    required this.amount,
  });

  factory GroupShare.fromJson(Map<String, dynamic> json) => GroupShare(
    workerId: json['worker_id'] as String,
    name: asString(json['name']),
    nickname: json['nickname'] as String?,
    amount: asDouble(json['amount']),
  );
}

/// The workers paid together for one kind of work in a count or unloading.
class WorkGroup {
  final String workTypeId;
  final String? workTypeCode;
  final String workTypeName;
  final PayUnit payUnit;
  final double? rate;
  final double total;
  final List<GroupShare> workers;

  const WorkGroup({
    required this.workTypeId,
    this.workTypeCode,
    required this.workTypeName,
    required this.payUnit,
    this.rate,
    required this.total,
    required this.workers,
  });

  factory WorkGroup.fromJson(Map<String, dynamic> json) => WorkGroup(
    workTypeId: json['work_type_id'] as String,
    workTypeCode: json['work_type_code'] as String?,
    workTypeName: asString(json['work_type_name']),
    payUnit: PayUnit.fromString(json['pay_unit'] as String?),
    rate: asDoubleOrNull(json['rate']),
    total: asDouble(json['total']),
    workers: asMapList(json['workers']).map(GroupShare.fromJson).toList(),
  );

  String get label => workTypeLabel(workTypeCode, workTypeName);
}

/// A stock problem the server noticed after saving (it never refuses a save
/// for it): a stage went below zero.
class StockWarning {
  final String stage;
  final int quantity;

  const StockWarning({required this.stage, required this.quantity});

  static List<StockWarning> listFrom(Object? value) => asMapList(value)
      .where((json) => json['code'] == 'negative_stock')
      .map((json) => StockWarning(stage: asString(json['stage']), quantity: asInt(json['quantity'])))
      .toList();
}

/// A brick count ("ginti").
class BrickCount {
  final String id;
  final DateTime countedOn;
  final CountReason reason;
  final int quantity;
  final String? molderId;
  final String? molderName;
  final bool alreadyCounted;
  final String? truckId;
  final String? truckNumber;
  final int? trips;
  final String? note;
  final String? createdBy;
  final String? createdByName;
  final DateTime? cancelledAt;
  final double? molderPay;
  final double? molderRate;
  final List<WorkGroup> groups;

  /// Only in lists.
  final double? totalPay;
  final List<StockWarning> warnings;

  const BrickCount({
    required this.id,
    required this.countedOn,
    required this.reason,
    required this.quantity,
    this.molderId,
    this.molderName,
    required this.alreadyCounted,
    this.truckId,
    this.truckNumber,
    this.trips,
    this.note,
    this.createdBy,
    this.createdByName,
    this.cancelledAt,
    this.molderPay,
    this.molderRate,
    this.groups = const [],
    this.totalPay,
    this.warnings = const [],
  });

  factory BrickCount.fromJson(Map<String, dynamic> json) {
    final molderPay = asMapOrNull(json['molder_pay']);
    return BrickCount(
      id: json['id'] as String,
      countedOn: asDate(json['counted_on']) ?? DateTime.now(),
      reason: CountReason.fromString(json['reason'] as String?),
      quantity: asInt(json['quantity']),
      molderId: json['molder_id'] as String?,
      molderName: json['molder_name'] as String?,
      alreadyCounted: asBool(json['already_counted']),
      truckId: json['truck_id'] as String?,
      truckNumber: json['truck_number'] as String?,
      trips: asIntOrNull(json['trips']),
      note: json['note'] as String?,
      createdBy: json['created_by'] as String?,
      createdByName: json['created_by_name'] as String?,
      cancelledAt: asDate(json['cancelled_at']),
      molderPay: asDoubleOrNull(molderPay?['amount']),
      molderRate: asDoubleOrNull(molderPay?['rate']),
      groups: asMapList(json['groups']).map(WorkGroup.fromJson).toList(),
      totalPay: asDoubleOrNull(json['total_pay']),
      warnings: StockWarning.listFrom(json['warnings']),
    );
  }

  bool get isCancelled => cancelledAt != null;

  double get pay => totalPay ?? (molderPay ?? 0) + groups.fold(0.0, (sum, g) => sum + g.total);
}

/// Fired bricks taken out of the kiln ("nikasi").
class KilnUnloading {
  final String id;
  final DateTime unloadedOn;
  final int quantity;
  final String? note;
  final String? createdBy;
  final String? createdByName;
  final DateTime? cancelledAt;
  final List<WorkGroup> groups;
  final double? totalPay;
  final List<StockWarning> warnings;

  const KilnUnloading({
    required this.id,
    required this.unloadedOn,
    required this.quantity,
    this.note,
    this.createdBy,
    this.createdByName,
    this.cancelledAt,
    this.groups = const [],
    this.totalPay,
    this.warnings = const [],
  });

  factory KilnUnloading.fromJson(Map<String, dynamic> json) => KilnUnloading(
    id: json['id'] as String,
    unloadedOn: asDate(json['unloaded_on']) ?? DateTime.now(),
    quantity: asInt(json['quantity']),
    note: json['note'] as String?,
    createdBy: json['created_by'] as String?,
    createdByName: json['created_by_name'] as String?,
    cancelledAt: asDate(json['cancelled_at']),
    groups: asMapList(json['groups']).map(WorkGroup.fromJson).toList(),
    totalPay: asDoubleOrNull(json['total_pay']),
    warnings: StockWarning.listFrom(json['warnings']),
  );

  bool get isCancelled => cancelledAt != null;

  double get pay => totalPay ?? groups.fold(0.0, (sum, g) => sum + g.total);
}

/// Work typed in by hand: day work, a lump sum.
class WorkEntry {
  final String id;
  final String workerId;
  final String workerName;
  final String workTypeId;
  final String? workTypeCode;
  final String workTypeName;
  final DateTime entryDate;
  final double? quantity;
  final double? rate;
  final double amount;
  final String source;
  final String? note;
  final DateTime? cancelledAt;

  const WorkEntry({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.workTypeId,
    this.workTypeCode,
    required this.workTypeName,
    required this.entryDate,
    this.quantity,
    this.rate,
    required this.amount,
    required this.source,
    this.note,
    this.cancelledAt,
  });

  factory WorkEntry.fromJson(Map<String, dynamic> json) => WorkEntry(
    id: json['id'] as String,
    workerId: json['worker_id'] as String,
    workerName: asString(json['worker_name']),
    workTypeId: json['work_type_id'] as String,
    workTypeCode: json['work_type_code'] as String?,
    workTypeName: asString(json['work_type_name']),
    entryDate: asDate(json['entry_date']) ?? DateTime.now(),
    quantity: asDoubleOrNull(json['quantity']),
    rate: asDoubleOrNull(json['rate']),
    amount: asDouble(json['amount']),
    source: asString(json['source'], 'manual'),
    note: json['note'] as String?,
    cancelledAt: asDate(json['cancelled_at']),
  );

  String get label => workTypeLabel(workTypeCode, workTypeName);
  bool get isCancelled => cancelledAt != null;
}
