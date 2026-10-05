import 'package:easy_localization/easy_localization.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/work.dart';

/// Stock never stops an entry, since counts are sometimes off. When a stage
/// went below zero, say so, so the count can be checked.
void showStockWarnings(List<StockWarning> warnings) {
  if (warnings.isEmpty) return;
  final lines = warnings.map(
    (w) => 'stock_negative'.tr(
      namedArgs: {
        'stage': w.kilnName ?? 'stock_${w.stage}'.tr(),
        'quantity': Formatters.formatNumber(w.quantity.toDouble()),
      },
    ),
  );
  // After the "saved" toast, so both are read.
  Future.delayed(const Duration(milliseconds: 900), () => showInfoToast(lines.join('\n'), durationSeconds: 6));
}
