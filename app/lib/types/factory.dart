import 'package:khanak/global/constants.dart';
import 'package:khanak/helpers/json.dart';

/// A season or the off-season between seasons. Exactly one is open.
class Period {
  final String id;
  final PeriodKind kind;
  final String? name;
  final DateTime startedOn;
  final DateTime? endedOn;

  const Period({
    required this.id,
    required this.kind,
    this.name,
    required this.startedOn,
    this.endedOn,
  });

  factory Period.fromJson(Map<String, dynamic> json) => Period(
    id: json['id'] as String,
    kind: PeriodKind.fromString(json['kind'] as String?),
    name: json['name'] as String?,
    startedOn: asDate(json['started_on']) ?? DateTime.now(),
    endedOn: asDate(json['ended_on']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.value,
    'name': name,
    'started_on': apiDate(startedOn),
    'ended_on': endedOn == null ? null : apiDate(endedOn!),
  };

  bool get isOpen => endedOn == null;
}

class Subscription {
  final String planCode;
  final String? planName;
  final bool isTrial;
  final DateTime? endsAt;

  const Subscription({
    required this.planCode,
    this.planName,
    required this.isTrial,
    this.endsAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    planCode: asString(json['plan_code']),
    planName: json['plan_name'] as String?,
    isTrial: asBool(json['is_trial']),
    endsAt: asDate(json['ends_at']),
  );

  Map<String, dynamic> toJson() => {
    'plan_code': planCode,
    'plan_name': planName,
    'is_trial': isTrial,
    'ends_at': endsAt?.toUtc().toIso8601String(),
  };

  int get daysLeft => endsAt == null ? 0 : endsAt!.difference(DateTime.now()).inDays;
}

/// A brick kiln, as the signed-in member sees it.
class Factory {
  final String id;
  final String name;
  final String? ownerName;
  final String? phone;
  final String? city;
  final String? state;
  final MemberRole role;

  /// The worker this member is paid as (a supervisor is usually the
  /// khadkaniyo). Their own account, and never an advance to themselves.
  final String? workerId;

  /// Only in the full view (not in the list of factories).
  final Period? period;
  final Subscription? subscription;

  const Factory({
    required this.id,
    required this.name,
    this.ownerName,
    this.phone,
    this.city,
    this.state,
    required this.role,
    this.workerId,
    this.period,
    this.subscription,
  });

  factory Factory.fromJson(Map<String, dynamic> json) {
    final period = asMapOrNull(json['period']);
    final subscription = asMapOrNull(json['subscription']);
    return Factory(
      id: json['id'] as String,
      name: asString(json['name']),
      ownerName: json['owner_name'] as String?,
      phone: json['phone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      role: MemberRole.fromString(json['role'] as String?),
      workerId: json['worker_id'] as String?,
      period: period == null ? null : Period.fromJson(period),
      subscription: subscription == null ? null : Subscription.fromJson(subscription),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'owner_name': ownerName,
    'phone': phone,
    'city': city,
    'state': state,
    'role': role.value,
    'worker_id': workerId,
    'period': period?.toJson(),
    'subscription': subscription?.toJson(),
  };

  bool can(MemberRole minimum) => role.atLeast(minimum);
  bool get isSupervisor => role == MemberRole.supervisor;
  bool get isOwner => role == MemberRole.owner;

  /// Without a running subscription the factory can be read but not changed.
  bool get canWrite => subscription != null;
}

class Member {
  final String userId;
  final String name;
  final String email;
  final MemberRole role;
  final String? workerId;
  final String? workerName;

  const Member({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.workerId,
    this.workerName,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    userId: json['user_id'] as String,
    name: asString(json['name']),
    email: asString(json['email']),
    role: MemberRole.fromString(json['role'] as String?),
    workerId: json['worker_id'] as String?,
    workerName: json['worker_name'] as String?,
  );
}

class Truck {
  final String id;
  final String number;
  final String? name;
  final bool isActive;

  const Truck({required this.id, required this.number, this.name, required this.isActive});

  factory Truck.fromJson(Map<String, dynamic> json) => Truck(
    id: json['id'] as String,
    number: asString(json['number']),
    name: json['name'] as String?,
    isActive: asBool(json['is_active'], true),
  );

  String get label => name == null || name!.isEmpty ? number : '$number · $name';
}
