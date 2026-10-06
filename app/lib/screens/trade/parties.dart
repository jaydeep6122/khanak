import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/emptyState.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/searchBar.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/trade/partyDetail.dart';
import 'package:khanak/types/trade.dart';

/// Customers and suppliers, opening on those with something outstanding:
/// what the market owes ("lena") and what the factory owes ("dena").
class PartiesScreen extends StatefulWidget {
  final String kind;

  /// Shown as a tab of the home screen, under the floating tab bar, rather
  /// than opened on its own.
  final bool asTab;

  const PartiesScreen({super.key, this.kind = 'customer', this.asTab = false});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  late String _kind = widget.kind;
  bool _onlyOutstanding = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().trade.fetchParties(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final trade = context.watch<Core>().trade;
    scheduleReload(trade.parties.needsReload, () => trade.fetchParties());
    final colors = context.colors;

    return Scaffold(
      appBar: widget.asTab ? null : AppBar(title: Text('credit'.tr())),
      body: SafeArea(
        bottom: false,
        top: widget.asTab,
        child: LoadStateBody<List<Party>>(
          state: trade.parties,
          onRetry: () => trade.fetchParties(refresh: true).then((_) {}),
          builder: (context, all) {
            final query = _search.toLowerCase();
            final ofKind = all.where((p) => p.kind == _kind).toList();
            final parties =
                ofKind
                    .where((p) => !_onlyOutstanding || p.balance.abs() >= 0.005)
                    .where(
                      (p) => query.isEmpty || p.name.toLowerCase().contains(query) || (p.phone ?? '').contains(query),
                    )
                    .toList()
                  ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
            final total = ofKind.fold(0.0, (sum, p) => sum + p.balance);
            final customers = _kind == 'customer';

            return RefreshIndicator(
              onRefresh: () => trade.fetchParties(refresh: true).then((_) {}),
              child: ListView(
                padding: EdgeInsets.only(bottom: widget.asTab ? AppTheme.fabClearance : AppTheme.space2xl),
                children: [
                  if (widget.asTab) LargeTitle(title: 'credit'.tr()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedControl<String>(
                          options: const ['customer', 'supplier'],
                          selected: _kind,
                          label: (kind) => kind == 'customer' ? 'customers'.tr() : 'suppliers'.tr(),
                          onChanged: (kind) => setState(() => _kind = kind),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        AppCard(
                          padding: const EdgeInsets.all(AppTheme.spaceXl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customers ? 'market_credit_total'.tr() : 'suppliers_total'.tr(),
                                style: context.text.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.formatCurrency(total.abs()),
                                  style: context.text.displaySmall?.copyWith(
                                    fontSize: 38,
                                    color: customers ? colors.success : colors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        AppSearchBar(hintText: 'search_party'.tr(), onChanged: (v) => setState(() => _search = v)),
                        const SizedBox(height: AppTheme.spaceMd),
                        Row(
                          children: [
                            QuickChip(
                              text: 'outstanding_only'.tr(),
                              selected: _onlyOutstanding,
                              onTap: () => setState(() => _onlyOutstanding = true),
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            QuickChip(
                              text: 'all'.tr(),
                              selected: !_onlyOutstanding,
                              onTap: () => setState(() => _onlyOutstanding = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        if (parties.isEmpty)
                          SizedBox(
                            height: 300,
                            child: EmptyState(icon: Icons.handshake_rounded, title: 'no_credit'.tr()),
                          )
                        else
                          GroupedSection(
                            children: [
                              for (final party in parties)
                                GroupedRow(
                                  onTap: () =>
                                      Navigator.of(context).push(getPageRoute(PartyDetailScreen(partyId: party.id))),
                                  chevron: false,
                                  leading: InitialBadge(
                                    letter: party.name.isEmpty ? '?' : party.name[0].toUpperCase(),
                                    size: 40,
                                  ),
                                  title: party.name,
                                  subtitle: party.phone != null || party.village != null
                                      ? [party.phone, party.village].whereType<String>().join(' · ')
                                      : null,
                                  trailing: PartyBalance(balance: party.balance),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "To get ₹5,400" when the party owes the factory, "To give ₹40,000" when
/// the factory owes them.
class PartyBalance extends StatelessWidget {
  final double balance;
  final bool large;

  const PartyBalance({super.key, required this.balance, this.large = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = balance > 0.004
        ? ('to_get'.tr(), colors.success)
        : balance < -0.004
        ? ('to_give'.tr(), colors.danger)
        : ('settled_up'.tr(), colors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (balance.abs() >= 0.005)
          Text(
            Formatters.formatCurrency(balance.abs()),
            style: (large ? context.text.headlineMedium : context.text.bodyLarge)?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(label, style: (large ? context.text.bodyLarge : context.text.bodySmall)?.copyWith(color: color)),
      ],
    );
  }
}
