import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/cash/detail.dart';
import 'package:khanak/screens/cash/handOver.dart';
import 'package:khanak/types/report.dart';

/// Cash left with supervisors to pay advances from, and what each has in hand.
class CashListScreen extends StatefulWidget {
  const CashListScreen({super.key});

  @override
  State<CashListScreen> createState() => _CashListScreenState();
}

class _CashListScreenState extends State<CashListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final core = context.read<Core>();
      core.report.fetchCashHolders();
      core.factory.fetchMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final report = core.report;
    scheduleReload(report.cashHolders.needsReload, () => report.fetchCashHolders());
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text('supervisor_cash'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(getPageRoute(const HandOverScreen())),
        icon: const Icon(Icons.payments_rounded),
        label: Text('give_cash'.tr()),
      ),
      body: LoadStateBody<List<CashHolder>>(
        state: report.cashHolders,
        onRetry: () => report.fetchCashHolders(refresh: true).then((_) {}),
        builder: (context, holders) => holders.isEmpty
            ? EmptyState(icon: Icons.account_balance_wallet_rounded, title: 'no_cash_yet'.tr(), description: 'no_cash_help'.tr())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.fabClearance),
                children: [
                  for (final holder in holders) ...[
                    AppCard(
                      onTap: () => Navigator.of(context).push(
                        getPageRoute(CashDetailScreen(holderId: holder.holderId, holderName: holder.name)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(holder.name ?? '', style: context.text.titleMedium)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatters.formatCurrency(holder.inHand.abs()),
                                style: context.text.titleMedium?.copyWith(
                                  color: holder.inHand < 0 ? colors.danger : colors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(holder.inHand < 0 ? 'cash_spent_own'.tr() : 'cash_in_hand'.tr(), style: context.text.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                  ],
                ],
              ),
      ),
    );
  }
}
