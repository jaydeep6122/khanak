import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khanak/components/initialBadge.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/optionSheet.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/whatsapp.dart';
import 'package:khanak/screens/trade/expenseForm.dart';
import 'package:khanak/screens/trade/paymentForm.dart';
import 'package:khanak/screens/trade/saleForm.dart';
import 'package:khanak/types/trade.dart';

/// One customer's or supplier's account: what is outstanding, every sale,
/// purchase and payment, and from here money received or paid, and a
/// WhatsApp reminder for what a customer owes.
class PartyDetailScreen extends StatefulWidget {
  final String partyId;

  const PartyDetailScreen({super.key, required this.partyId});

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    final trade = context.read<Core>().trade;
    await Future.wait([
      trade.fetchParty(widget.partyId, refresh: refresh),
      trade.fetchPartyLedger(widget.partyId, refresh: refresh),
    ]);
  }

  Future<void> _push(Widget screen) async {
    final changed = await Navigator.of(context).push(getPageRoute(screen));
    if (changed != null && mounted) _load(refresh: true);
  }

  Future<void> _remind(Party party) async {
    final message = 'credit_reminder'.tr(
      namedArgs: {
        'name': party.name,
        'amount': Formatters.formatCurrency(party.balance),
        'factory': context.read<Core>().openFactory?.name ?? '',
      },
    );
    await openWhatsApp(party.phone, message);
  }

  Future<void> _openLine(PartyLine line) async {
    switch (line.kind) {
      case 'sale':
      case 'truck_hire':
        return _push(SaleFormScreen(saleId: line.entryId));
      case 'expense':
        return _push(ExpenseFormScreen(expenseId: line.entryId));
    }
    final party = context.read<Core>().trade.party(widget.partyId).value;
    if (party == null) return;
    final action = await pickOption<String>(
      context,
      title: line.title,
      options: const ['edit', 'cancel'],
      label: (a) => a == 'edit' ? 'edit_payment'.tr() : 'cancel_entry'.tr(),
      leading: (a) => TintIcon(
        tint: a == 'edit' ? Tint.money : Tint.neutral,
        icon: a == 'edit' ? Icons.edit_rounded : Icons.block_rounded,
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'edit') {
      return _push(PaymentFormScreen(party: party, kind: line.kind, paymentId: line.entryId));
    }
    final reason = await showReasonDialog(
      context,
      title: 'cancel_payment_title'.tr(),
      message: 'cancel_txn_message'.tr(namedArgs: {'amount': Formatters.formatCurrency(line.amount)}),
      confirmText: 'cancel_entry'.tr(),
    );
    if (reason == null || !mounted) return;
    final trade = context.read<Core>().trade;
    if (!await trade.cancelPayment(line.entryId, reason: reason.isEmpty ? null : reason)) {
      return showErrorToast(trade.error ?? 'error_generic'.tr());
    }
    showSuccessToast('entry_cancelled'.tr());
    _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final trade = core.trade;
    final state = trade.party(widget.partyId);
    final account = trade.account(widget.partyId);
    scheduleReload(state.needsReload || account.lines.needsReload, () => _load(refresh: true));
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(),
      body: LoadStateBody<Party>(
        state: state,
        onRetry: () => _load(refresh: true),
        builder: (context, party) {
          final customer = party.isCustomer;
          final owes = customer && party.balance > 0.004;
          final (label, color) = party.balance > 0.004
              ? ('to_get'.tr(), colors.success)
              : party.balance < -0.004
              ? ('to_give'.tr(), colors.danger)
              : ('settled_up'.tr(), colors.muted);

          // The day of each line, newest first.
          final days = <DateTime, List<PartyLine>>{};
          for (final line in account.lines.items) {
            days.putIfAbsent(DateTime(line.date.year, line.date.month, line.date.day), () => []).add(line);
          }

          Widget action(String text, Color background, Color foreground, VoidCallback onTap, [IconData? icon]) =>
              Expanded(
                child: Material(
                  color: background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: onTap,
                    child: SizedBox(
                      height: 46,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[Icon(icon, size: 17, color: foreground), const SizedBox(width: 6)],
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelLarge?.copyWith(color: foreground, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

          return RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceXl, 0, AppTheme.spaceXl, AppTheme.space3xl),
              children: [
                Row(
                  children: [
                    InitialBadge(letter: party.name.isEmpty ? '?' : party.name[0].toUpperCase(), size: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(party.name, style: context.text.headlineMedium),
                          Text(
                            [customer ? 'customer'.tr() : 'supplier'.tr(), ?party.village, ?party.phone].join(' · '),
                            style: context.text.bodyMedium?.copyWith(color: colors.muted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    if (party.phone != null)
                      CircleButton(
                        icon: Icons.call_rounded,
                        tooltip: 'call'.tr(),
                        onTap: () => launchUrl(Uri.parse('tel:${party.phone}')),
                      ),
                    if (owes && core.can(MemberRole.owner))
                      Padding(
                        padding: const EdgeInsets.only(left: AppTheme.spaceSm),
                        child: PopupMenuButton<String>(
                          onSelected: (_) => _push(PaymentFormScreen(party: party, kind: 'writeoff')),
                          itemBuilder: (_) => [PopupMenuItem(value: 'writeoff', child: Text('writeoff'.tr()))],
                          child: const CircleButton(icon: Icons.more_horiz_rounded),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXl),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXl),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: context.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(label, style: context.text.bodySmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.formatCurrency(party.balance.abs()),
                          style: context.text.displaySmall?.copyWith(fontSize: 40, color: color),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                      Row(
                        spacing: AppTheme.spaceSm,
                        children: [
                          if (customer)
                            action(
                              'payment_received'.tr(),
                              colors.ink,
                              colors.onInk,
                              () => _push(PaymentFormScreen(party: party, kind: 'received')),
                            )
                          else
                            action(
                              'payment_paid'.tr(),
                              colors.ink,
                              colors.onInk,
                              () => _push(PaymentFormScreen(party: party, kind: 'paid')),
                            ),
                          if (customer)
                            action(
                              'action_sale'.tr(),
                              colors.background,
                              colors.ink,
                              () => _push(SaleFormScreen(customer: party)),
                            ),
                          if (owes && party.phone != null)
                            action(
                              'send_reminder'.tr(),
                              colors.successSoft,
                              colors.success,
                              () => _remind(party),
                              Icons.chat_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space2xl),
                if (account.lines.isLoading && account.lines.items.isEmpty)
                  const SizedBox(height: 200, child: LoadingIndicator())
                else if (account.lines.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.space2xl),
                    child: Text('no_lines_yet'.tr(), textAlign: TextAlign.center, style: context.text.bodyMedium),
                  )
                else ...[
                  for (final MapEntry(key: day, value: lines) in days.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceLg),
                      child: GroupedSection(
                        caption: Formatters.formatRelativeDate(day, today: 'today'.tr(), yesterday: 'yesterday'.tr()),
                        children: [
                          for (final line in lines)
                            GroupedRow(
                              onTap: () => _openLine(line),
                              chevron: false,
                              leading: TintIcon(
                                tint: switch (line.kind) {
                                  'sale' || 'truck_hire' => Tint.truck,
                                  'expense' => Tint.expense,
                                  'writeoff' => Tint.neutral,
                                  _ => Tint.money,
                                },
                              ),
                              title: line.title,
                              subtitle: [
                                if (line.quantity != null && line.kind == 'sale')
                                  'party_line_bricks'.tr(
                                    namedArgs: {
                                      'bricks': Formatters.formatCount(line.quantity!),
                                      'amount': Formatters.formatCurrency(line.amount),
                                    },
                                  ),
                                ?line.note,
                              ].join(' · '),
                              value: '${line.owed >= 0 ? '+' : '−'}${Formatters.formatCurrency(line.owed.abs())}',
                              valueColor: line.owed >= 0 ? colors.success : colors.danger,
                            ),
                        ],
                      ),
                    ),
                  if (account.lines.data.hasMore)
                    TextButton(
                      onPressed: () => trade.fetchPartyLedger(widget.partyId, more: true),
                      child: Text('load_more'.tr()),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
