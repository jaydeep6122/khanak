import 'package:easy_localization/easy_localization.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/types/work.dart';

/// A customer or a supplier. Most are one-off: one is only needed when money
/// is left owing.
class Party {
  final String id;

  /// 'customer' or 'supplier'.
  final String kind;
  final String name;
  final String? phone;
  final String? village;
  final bool isActive;

  /// What they owe the factory; negative when the factory owes them (a
  /// supplier, or a customer's advance).
  final double balance;

  const Party({
    required this.id,
    required this.kind,
    required this.name,
    this.phone,
    this.village,
    required this.isActive,
    this.balance = 0,
  });

  factory Party.fromJson(Map<String, dynamic> json) => Party(
    id: json['id'] as String,
    kind: asString(json['kind'], 'customer'),
    name: asString(json['name']),
    phone: json['phone'] as String?,
    village: json['village'] as String?,
    isActive: asBool(json['is_active'], true),
    balance: asDouble(json['balance']),
  );

  bool get isCustomer => kind == 'customer';
}

/// One line of a party's account.
class PartyLine {
  /// sale, truck_hire, expense, received, paid or writeoff.
  final String kind;
  final String entryId;
  final DateTime date;

  /// What it adds to what the party owes (negative: what the factory owes).
  final double owed;
  final double amount;
  final double? paidAmount;
  final int? quantity;
  final double? rate;
  final String? note;

  const PartyLine({
    required this.kind,
    required this.entryId,
    required this.date,
    required this.owed,
    required this.amount,
    this.paidAmount,
    this.quantity,
    this.rate,
    this.note,
  });

  factory PartyLine.fromJson(Map<String, dynamic> json) => PartyLine(
    kind: asString(json['entry_kind']),
    entryId: json['entry_id'] as String,
    date: asDate(json['entry_date']) ?? DateTime.now(),
    owed: asDouble(json['owed']),
    amount: asDouble(json['amount']),
    paidAmount: asDoubleOrNull(json['paid_amount']),
    quantity: asDoubleOrNull(json['quantity'])?.round(),
    rate: asDoubleOrNull(json['rate']),
    note: json['note'] as String?,
  );

  String get title => 'party_line_$kind'.tr();
  bool get isPayment => kind == 'received' || kind == 'paid' || kind == 'writeoff';
}

/// How the bricks went: the factory's own truck, the customer's vehicle, or
/// a hired truck.
enum Delivery {
  ownTruck('own_truck'),
  customer('customer'),
  hired('hired');

  const Delivery(this.value);
  final String value;

  static Delivery fromString(String? value) =>
      Delivery.values.firstWhere((e) => e.value == value, orElse: () => customer);

  String get displayName => 'delivery_$value'.tr();
}

/// A load of fired bricks sold.
class Sale {
  final String id;
  final DateTime soldOn;
  final String? partyId;
  final String? partyName;
  final String? partyPhone;
  final String? customerName;
  final int quantity;

  /// Per 1000 bricks.
  final double rate;
  final double bricksAmount;
  final double? bhadu;
  final double total;
  final double paidAmount;
  final Delivery delivery;
  final String? truckId;
  final String? truckNumber;
  final String? driverId;
  final String? driverName;
  final int? trips;
  final String? destination;
  final String? hirePartyId;
  final String? hirePartyName;
  final double? hireAmount;
  final String? note;
  final DateTime? cancelledAt;
  final List<WorkGroup> groups;

  /// The customer's whole balance after this sale (details only).
  final double? partyBalance;
  final List<StockWarning> warnings;

  const Sale({
    required this.id,
    required this.soldOn,
    this.partyId,
    this.partyName,
    this.partyPhone,
    this.customerName,
    required this.quantity,
    required this.rate,
    required this.bricksAmount,
    this.bhadu,
    required this.total,
    required this.paidAmount,
    required this.delivery,
    this.truckId,
    this.truckNumber,
    this.driverId,
    this.driverName,
    this.trips,
    this.destination,
    this.hirePartyId,
    this.hirePartyName,
    this.hireAmount,
    this.note,
    this.cancelledAt,
    this.groups = const [],
    this.partyBalance,
    this.warnings = const [],
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    soldOn: asDate(json['sold_on']) ?? DateTime.now(),
    partyId: json['party_id'] as String?,
    partyName: json['party_name'] as String?,
    partyPhone: json['party_phone'] as String?,
    customerName: json['customer_name'] as String?,
    quantity: asInt(json['quantity']),
    rate: asDouble(json['rate']),
    bricksAmount: asDouble(json['bricks_amount']),
    bhadu: asDoubleOrNull(json['bhadu']),
    total: asDouble(json['total']),
    paidAmount: asDouble(json['paid_amount']),
    delivery: Delivery.fromString(json['delivery'] as String?),
    truckId: json['truck_id'] as String?,
    truckNumber: json['truck_number'] as String?,
    driverId: json['driver_id'] as String?,
    driverName: json['driver_name'] as String?,
    trips: asIntOrNull(json['trips']),
    destination: json['destination'] as String?,
    hirePartyId: json['hire_party_id'] as String?,
    hirePartyName: json['hire_party_name'] as String?,
    hireAmount: asDoubleOrNull(json['hire_amount']),
    note: json['note'] as String?,
    cancelledAt: asDate(json['cancelled_at']),
    groups: asMapList(json['groups']).map(WorkGroup.fromJson).toList(),
    partyBalance: asDoubleOrNull(json['party_balance']),
    warnings: StockWarning.listFrom(json['warnings']),
  );

  bool get isCancelled => cancelledAt != null;
  double get due => total - paidAmount;

  /// Who bought: the customer on record, the name typed, or nobody.
  String? get buyer => partyName ?? customerName;
}

/// What the factory spends on.
enum ExpenseCategory {
  soil('soil'),
  coal('coal'),
  husk('husk'),
  diesel('diesel'),
  truckUpkeep('truck_upkeep'),
  other('other');

  const ExpenseCategory(this.value);
  final String value;

  static ExpenseCategory fromString(String? value) =>
      ExpenseCategory.values.firstWhere((e) => e.value == value, orElse: () => other);

  String get displayName => 'expense_$value'.tr();

  bool get forTruck => this == diesel || this == truckUpkeep;
  bool get hasQuantity => this == soil || this == coal || this == husk;
}

class Expense {
  final String id;
  final DateTime spentOn;
  final ExpenseCategory category;
  final double? quantity;
  final String? unit;
  final double amount;
  final double paidAmount;
  final String? partyId;
  final String? partyName;
  final String? truckId;
  final String? truckNumber;
  final double? litres;
  final int? odometer;
  final String? note;
  final DateTime? cancelledAt;

  const Expense({
    required this.id,
    required this.spentOn,
    required this.category,
    this.quantity,
    this.unit,
    required this.amount,
    required this.paidAmount,
    this.partyId,
    this.partyName,
    this.truckId,
    this.truckNumber,
    this.litres,
    this.odometer,
    this.note,
    this.cancelledAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    spentOn: asDate(json['spent_on']) ?? DateTime.now(),
    category: ExpenseCategory.fromString(json['category'] as String?),
    quantity: asDoubleOrNull(json['quantity']),
    unit: json['unit'] as String?,
    amount: asDouble(json['amount']),
    paidAmount: asDouble(json['paid_amount']),
    partyId: json['party_id'] as String?,
    partyName: json['party_name'] as String?,
    truckId: json['truck_id'] as String?,
    truckNumber: json['truck_number'] as String?,
    litres: asDoubleOrNull(json['litres']),
    odometer: asIntOrNull(json['odometer']),
    note: json['note'] as String?,
    cancelledAt: asDate(json['cancelled_at']),
  );

  bool get isCancelled => cancelledAt != null;
  double get due => amount - paidAmount;
}

/// One full-tank diesel fill and what it covered since the one before.
class FuelFill {
  final String expenseId;
  final DateTime date;
  final double amount;
  final double? litres;
  final int? odometer;
  final int? trips;
  final int? km;
  final double? kmPerLitre;
  final double? perTrip;
  final bool lowAverage;

  const FuelFill({
    required this.expenseId,
    required this.date,
    required this.amount,
    this.litres,
    this.odometer,
    this.trips,
    this.km,
    this.kmPerLitre,
    this.perTrip,
    required this.lowAverage,
  });

  factory FuelFill.fromJson(Map<String, dynamic> json) => FuelFill(
    expenseId: json['id'] as String,
    date: asDate(json['spent_on']) ?? DateTime.now(),
    amount: asDouble(json['amount']),
    litres: asDoubleOrNull(json['litres']),
    odometer: asIntOrNull(json['odometer']),
    trips: asIntOrNull(json['trips']),
    km: asIntOrNull(json['km']),
    kmPerLitre: asDoubleOrNull(json['km_per_litre']),
    perTrip: asDoubleOrNull(json['per_trip']),
    lowAverage: asBool(json['low_average']),
  );
}

/// What a truck did and earned between two dates.
class TruckReport {
  final int salesTrips;
  final int kilnTrips;
  final int totalTrips;
  final int tripsWithoutBhadu;
  final int bricksSold;
  final double bhadu;
  final double diesel;
  final double litres;
  final double upkeep;
  final double loaders;
  final double profit;
  final double? profitPerTrip;
  final List<FuelFill> fuel;

  const TruckReport({
    required this.salesTrips,
    required this.kilnTrips,
    required this.totalTrips,
    required this.tripsWithoutBhadu,
    required this.bricksSold,
    required this.bhadu,
    required this.diesel,
    required this.litres,
    required this.upkeep,
    required this.loaders,
    required this.profit,
    this.profitPerTrip,
    required this.fuel,
  });

  factory TruckReport.fromJson(Map<String, dynamic> json) {
    final trips = asMap(json['trips']);
    final costs = asMap(json['costs']);
    return TruckReport(
      salesTrips: asInt(trips['sales']),
      kilnTrips: asInt(trips['kiln']),
      totalTrips: asInt(trips['total']),
      tripsWithoutBhadu: asInt(trips['without_bhadu']),
      bricksSold: asInt(asMap(json['bricks'])['sold']),
      bhadu: asDouble(asMap(json['earned'])['bhadu']),
      diesel: asDouble(costs['diesel']),
      litres: asDouble(costs['litres']),
      upkeep: asDouble(costs['upkeep']),
      loaders: asDouble(costs['loaders']),
      profit: asDouble(json['profit']),
      profitPerTrip: asDoubleOrNull(json['profit_per_trip']),
      fuel: asMapList(json['fuel']).map(FuelFill.fromJson).toList(),
    );
  }
}
