import 'package:khanak/helpers/json.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.isActive,
    this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: asString(json['name']),
      email: asString(json['email']),
      phone: json['phone'] as String?,
      isActive: asBool(json['is_active'], true),
      createdAt: asDate(json['created_at']),
      lastLoginAt: asDate(json['last_login_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'is_active': isActive,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'last_login_at': lastLoginAt?.toUtc().toIso8601String(),
  };

  User copyWith({String? name, String? phone}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      isActive: isActive,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }

  /// Up to two initials for an avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'U' : letters;
  }
}
