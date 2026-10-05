import 'package:khanak/global/constants.dart';
import 'package:khanak/helpers/json.dart';

/// A worker. No photos are kept: two workers with the same name are told
/// apart by nickname or village.
class Worker {
  final String id;
  final String name;
  final String? nickname;
  final String? village;

  /// Not sent to a supervisor.
  final String? phone;
  final String? note;
  final MainWork mainWork;

  /// A molder's rate per 1000 bricks, or a day worker's rate per day. Not
  /// sent to a supervisor.
  final double? rate;
  final double? monthlySalary;
  final DateTime? salaryFrom;
  final bool isActive;
  final DateTime? leftOn;
  final bool shareEnabled;

  /// Positive: the factory owes the worker. Negative: the worker owes.
  /// Not sent to a supervisor.
  final double? balance;

  const Worker({
    required this.id,
    required this.name,
    this.nickname,
    this.village,
    this.phone,
    this.note,
    this.mainWork = MainWork.other,
    this.rate,
    this.monthlySalary,
    this.salaryFrom,
    required this.isActive,
    this.leftOn,
    this.shareEnabled = true,
    this.balance,
  });

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    id: json['id'] as String,
    name: asString(json['name']),
    nickname: json['nickname'] as String?,
    village: json['village'] as String?,
    phone: json['phone'] as String?,
    note: json['note'] as String?,
    mainWork: MainWork.fromString(json['main_work'] as String?),
    rate: asDoubleOrNull(json['rate']),
    monthlySalary: asDoubleOrNull(json['monthly_salary']),
    salaryFrom: asDate(json['salary_from']),
    isActive: asBool(json['is_active'], true),
    leftOn: asDate(json['left_on']),
    shareEnabled: asBool(json['share_enabled'], true),
    balance: asDoubleOrNull(json['balance']),
  );

  /// "Ramesh (Moto) · Bihar": enough to pick the right Ramesh.
  String get displayName {
    final extra = [
      if (nickname != null && nickname!.isNotEmpty) nickname!,
      if (village != null && village!.isNotEmpty) village!,
    ];
    return extra.isEmpty ? name : '$name · ${extra.join(' · ')}';
  }

  /// First letter for the round badge shown instead of a photo.
  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  bool get isSalaried => monthlySalary != null;
}

/// A worker's own link (no login), sent on WhatsApp.
class WorkerShare {
  final String token;
  final String url;
  final bool enabled;
  final String? phone;

  const WorkerShare({required this.token, required this.url, required this.enabled, this.phone});

  factory WorkerShare.fromJson(Map<String, dynamic> json) => WorkerShare(
    token: asString(json['token']),
    url: asString(json['url']),
    enabled: asBool(json['enabled'], true),
    phone: json['phone'] as String?,
  );
}
