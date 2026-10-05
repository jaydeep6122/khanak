import 'package:khanak/helpers/json.dart';
import 'package:khanak/types/factory.dart';

/// Bricks in each stage.
class BrickStock {
  /// Kachi: made and counted, not yet in the kiln.
  final int raw;

  /// In the bhatha.
  final int kiln;

  /// Pakki: fired and taken out.
  final int fired;

  const BrickStock({required this.raw, required this.kiln, required this.fired});

  factory BrickStock.fromJson(Map<String, dynamic> json) => BrickStock(
    raw: asInt(json['raw']),
    kiln: asInt(json['kiln']),
    fired: asInt(json['fired']),
  );

  static const empty = BrickStock(raw: 0, kiln: 0, fired: 0);
}

/// The home screen's numbers.
class HomeSummary {
  final Period? period;
  final BrickStock stock;

  /// Owed to workers, summed over every worker the factory owes.
  final double payable;

  /// Owed by workers who took more than they earned.
  final double receivable;
  final int activeWorkers;
  final int madeToday;
  final int madeInPeriod;
  final int unloadedInPeriod;
  final double wagesInPeriod;
  final double advancesInPeriod;
  final double advancesToday;

  const HomeSummary({
    this.period,
    required this.stock,
    required this.payable,
    required this.receivable,
    required this.activeWorkers,
    required this.madeToday,
    required this.madeInPeriod,
    required this.unloadedInPeriod,
    required this.wagesInPeriod,
    required this.advancesInPeriod,
    required this.advancesToday,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final period = asMapOrNull(json['period']);
    final workers = asMap(json['workers']);
    final bricks = asMap(json['bricks']);
    final money = asMap(json['money']);
    return HomeSummary(
      period: period == null ? null : Period.fromJson(period),
      stock: BrickStock.fromJson(asMap(json['stock'])),
      payable: asDouble(workers['payable']),
      receivable: asDouble(workers['receivable']),
      activeWorkers: asInt(workers['active']),
      madeToday: asInt(bricks['made_today']),
      madeInPeriod: asInt(bricks['made_in_period']),
      unloadedInPeriod: asInt(bricks['unloaded_in_period']),
      wagesInPeriod: asDouble(money['wages_in_period']),
      advancesInPeriod: asDouble(money['advances_in_period']),
      advancesToday: asDouble(money['advances_today']),
    );
  }
}

/// Cash a supervisor holds to pay advances from.
class CashHolder {
  final String holderId;
  final String? name;
  final double given;
  final double returned;
  final double advancesPaid;

  /// Negative: the supervisor paid from their own pocket.
  final double inHand;
  final List<CashLine> lines;

  const CashHolder({
    required this.holderId,
    this.name,
    required this.given,
    required this.returned,
    required this.advancesPaid,
    required this.inHand,
    this.lines = const [],
  });

  factory CashHolder.fromJson(Map<String, dynamic> json) => CashHolder(
    holderId: json['holder_id'] as String,
    name: json['name'] as String?,
    given: asDouble(json['given']),
    returned: asDouble(json['returned']),
    advancesPaid: asDouble(json['advances_paid']),
    inHand: asDouble(json['in_hand']),
    lines: asMapList(json['lines']).map(CashLine.fromJson).toList(),
  );
}

class CashLine {
  /// 'handover' or 'advance'.
  final String lineKind;
  final String id;

  /// given / returned for a handover, advance for an advance.
  final String kind;
  final DateTime date;
  final double amount;
  final String? note;
  final String? workerName;

  const CashLine({
    required this.lineKind,
    required this.id,
    required this.kind,
    required this.date,
    required this.amount,
    this.note,
    this.workerName,
  });

  factory CashLine.fromJson(Map<String, dynamic> json) => CashLine(
    lineKind: asString(json['line_kind']),
    id: json['id'] as String,
    kind: asString(json['kind']),
    date: asDate(json['line_date']) ?? DateTime.now(),
    amount: asDouble(json['amount']),
    note: json['note'] as String?,
    workerName: json['worker_name'] as String?,
  );

  /// Cash going into the holder's hand.
  bool get isIn => lineKind == 'handover' && kind == 'given';
}

/// One thing someone created, changed or cancelled.
class Activity {
  final String action;
  final String entityType;
  final String? userName;
  final DateTime at;

  const Activity({required this.action, required this.entityType, this.userName, required this.at});

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    action: asString(json['action']),
    entityType: asString(json['entity_type']),
    userName: json['user_name'] as String?,
    at: asDate(json['created_at']) ?? DateTime.now(),
  );
}
