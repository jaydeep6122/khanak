import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/types/factory.dart';

extension CoreGetters on Core {
  Factory? get openFactory => factory.selected;

  /// The open factory's id. Only use on screens reached after one is open.
  String get factoryId => factory.selected!.id;

  MemberRole get role => factory.selected?.role ?? MemberRole.supervisor;

  /// Whether the signed-in member's role is at least [minimum].
  bool can(MemberRole minimum) => role.atLeast(minimum);

  bool get isSupervisor => role == MemberRole.supervisor;
}
