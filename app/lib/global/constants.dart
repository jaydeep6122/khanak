import 'package:easy_localization/easy_localization.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Khanak';

  /// The live API. A build can point elsewhere, e.g. at the backend on this
  /// computer: `fvm flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/v1`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://khanak.onrender.com/v1',
  );
}

// API enums. `value` is the wire string, `fromString` falls back to a safe
// default for unknown values, `displayName` is the translated label.

/// The languages the app speaks. Gujarati comes first: the first kilns
/// using Khanak are in Gujarat.
enum AppLanguage {
  gujarati('gu', 'ગુજરાતી'),
  hindi('hi', 'हिंदी'),
  english('en', 'English');

  const AppLanguage(this.code, this.nativeName);
  final String code;

  /// Always written in the language itself, so anyone can find their own.
  final String nativeName;

  static AppLanguage? byCode(String? code) =>
      AppLanguage.values.where((language) => language.code == code).firstOrNull;
}

/// owner > munim > supervisor.
enum MemberRole {
  supervisor('supervisor', 1),
  munim('munim', 2),
  owner('owner', 3);

  const MemberRole(this.value, this.rank);
  final String value;
  final int rank;

  static MemberRole fromString(String? value) => MemberRole.values.firstWhere(
    (e) => e.value == value,
    orElse: () => supervisor,
  );

  String get displayName => 'role_$value'.tr();

  bool atLeast(MemberRole minimum) => rank >= minimum.rank;
}

/// A season, or the off-season (monsoon) between seasons.
enum PeriodKind {
  season('season'),
  offSeason('off_season');

  const PeriodKind(this.value);
  final String value;

  static PeriodKind fromString(String? value) => PeriodKind.values.firstWhere(
    (e) => e.value == value,
    orElse: () => season,
  );

  String get displayName => 'period_$value'.tr();
}

/// Why bricks were counted.
enum CountReason {
  /// The drying ground is full, or the bricks are lifted from it.
  drying('drying'),

  /// Workers carried them into the kiln.
  kilnByWorkers('kiln_by_workers'),

  /// The truck carried them into the kiln.
  kilnByTruck('kiln_by_truck'),

  /// The season's last count, when the workers leave.
  finalCount('final');

  const CountReason(this.value);
  final String value;

  static CountReason fromString(String? value) => CountReason.values.firstWhere(
    (e) => e.value == value,
    orElse: () => drying,
  );

  String get displayName => 'count_reason_$value'.tr();

  bool get intoKiln => this == kilnByWorkers || this == kilnByTruck;
}

/// How a kind of work is paid.
enum PayUnit {
  per1000('per_1000'),
  perLakh('per_lakh'),
  perDay('per_day'),
  perMonth('per_month'),
  perTrip('per_trip'),
  lumpsum('lumpsum');

  const PayUnit(this.value);
  final String value;

  static PayUnit fromString(String? value) =>
      PayUnit.values.firstWhere((e) => e.value == value, orElse: () => lumpsum);

  String get displayName => 'pay_unit_$value'.tr();

  bool get hasRate => this != lumpsum && this != perMonth;

  /// Paid by the number of bricks.
  bool get byBricks => this == per1000 || this == perLakh;
}

/// Money between the factory and a worker.
enum TxnKind {
  /// Upad: paid to the worker against what they earn.
  advance('advance'),

  /// Chukti: paying off what the worker is owed.
  settlement('settlement'),

  /// The worker paid money back.
  recovery('recovery'),

  /// Forgiving what a worker owes (owner only).
  writeoff('writeoff');

  const TxnKind(this.value);
  final String value;

  static TxnKind fromString(String? value) =>
      TxnKind.values.firstWhere((e) => e.value == value, orElse: () => advance);

  String get displayName => 'txn_$value'.tr();

  /// Paid out to the worker (their balance goes down).
  bool get paidOut => this == advance || this == settlement;
}

/// What a worker mainly does. Forms list these workers first; pay still
/// comes from the work in each entry.
enum MainWork {
  molder('molder'),
  loader('loader'),
  stacker('stacker'),
  unloader('unloader'),
  driver('driver'),
  daily('daily'),
  other('other');

  const MainWork(this.value);
  final String value;

  static MainWork fromString(String? value) =>
      MainWork.values.firstWhere((e) => e.value == value, orElse: () => other);

  String get displayName => 'main_work_$value'.tr();

  /// A molder (per 1000 bricks) and a day worker (per day) each have their
  /// own rate, and must have one.
  bool get hasOwnRate => this == molder || this == daily;
}
