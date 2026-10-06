import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/components/amountDialog.dart';
import 'package:provider/provider.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/work.dart';

/// True when [type] is paid by a rate that has not been set yet.
bool rateMissing(WorkType type) => type.payUnit.hasRate && (type.rate ?? 0) <= 0;

/// The owner and munim set rates; there is no rates screen, so a rate is
/// asked the first time a kind of work is used.
bool canSetRates(BuildContext context) => context.read<Core>().can(MemberRole.munim);

/// Makes sure [type] has a rate before work is priced by it: asks the owner
/// or munim for it right there, and tells a supervisor to ask the owner.
/// Returns the kind of work with its rate, or null while it has none.
Future<WorkType?> ensureRate(BuildContext context, WorkType type) async {
  if (!rateMissing(type)) return type;
  if (!canSetRates(context)) {
    showErrorToast('rate_ask_owner'.tr());
    return null;
  }
  final updated = await askRate(context, type);
  return updated == null || rateMissing(updated) ? null : updated;
}

/// Asks the owner or munim for [type]'s rate and saves it for good. Returns the kind
/// of work with its new rate, or null when cancelled or it failed. A new rate
/// applies to new entries only.
Future<WorkType?> askRate(BuildContext context, WorkType type) async {
  final value = await showAmountDialog(
    context,
    title: type.label,
    initialValue: (type.rate ?? 0) == 0 ? '' : Formatters.formatDouble(type.rate!),
    help: 'rate_ask_help'.tr(),
    suffixText: 'rate_unit_${type.payUnit.value}'.tr(),
  );
  if (value == null || value.isEmpty || !context.mounted) return null;
  if ((double.tryParse(value) ?? 0) <= 0) {
    showErrorToast('rate_above_zero'.tr());
    return null;
  }

  final factory = context.read<Core>().factory;
  if (!await factory.updateWorkType(type.id, {'rate': value})) {
    showErrorToast(factory.error ?? 'error_generic'.tr());
    return null;
  }
  return factory.workTypes.value?.where((t) => t.id == type.id).firstOrNull;
}
