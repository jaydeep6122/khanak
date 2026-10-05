import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/sectionHeader.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/auth/login.dart';
import 'package:khanak/screens/cash/detail.dart';
import 'package:khanak/screens/cash/list.dart';
import 'package:khanak/screens/factory/form.dart';
import 'package:khanak/screens/factory/list.dart';
import 'package:khanak/screens/more/activity.dart';
import 'package:khanak/screens/more/kilns.dart';
import 'package:khanak/screens/more/members.dart';
import 'package:khanak/screens/more/season.dart';
import 'package:khanak/screens/more/trucks.dart';
import 'package:khanak/screens/settings/language.dart';
import 'package:khanak/screens/settings/rates.dart';

/// Everything that is not an everyday entry, with a one-line description so
/// it is clear what each row is for.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'logout_title'.tr(),
      message: 'logout_message'.tr(),
      confirmText: 'logout'.tr(),
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    await context.read<Core>().auth.logout();
    navigator.pushAndRemoveUntil(getPageRoute(const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final factory = core.openFactory!;
    final manager = core.can(MemberRole.munim);
    final owner = core.can(MemberRole.owner);
    final subscription = factory.subscription;

    void open(Widget screen) => Navigator.of(context).push(getPageRoute(screen));

    return Scaffold(
      appBar: AppBar(title: Text('tab_more'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.space2xl),
        children: [
          SectionHeader(title: factory.name),
          _Group(
            rows: [
              if (owner) _Row(Icons.factory_outlined, 'factory_edit'.tr(), 'factory_edit_desc'.tr(), () => open(FactoryFormScreen(factory: factory))),
              if (core.factory.factories.length > 1 || owner)
                _Row(Icons.swap_horiz_rounded, 'factories'.tr(), 'factories_desc'.tr(), () => open(const FactoryListScreen())),
              if (owner)
                _Row(
                  Icons.workspace_premium_outlined,
                  'subscription'.tr(),
                  subscription == null
                      ? 'subscription_none'.tr()
                      : 'subscription_until'.tr(namedArgs: {
                          'plan': subscription.isTrial ? 'trial'.tr() : (subscription.planName ?? subscription.planCode),
                          'date': subscription.endsAt == null ? '' : Formatters.formatDate(subscription.endsAt!.toLocal()),
                        }),
                  null,
                ),
            ],
          ),
          if (manager) ...[
            SectionHeader(title: 'setup'.tr()),
            _Group(
              rows: [
                _Row(Icons.price_change_outlined, 'rates'.tr(), 'rates_desc'.tr(), () => open(const RatesScreen())),
                _Row(Icons.event_repeat_rounded, 'season'.tr(), 'season_desc'.tr(), () => open(const SeasonScreen())),
                _Row(Icons.local_fire_department_outlined, 'kilns'.tr(), 'kilns_desc'.tr(), () => open(const KilnsScreen())),
                _Row(Icons.local_shipping_outlined, 'trucks'.tr(), 'trucks_desc'.tr(), () => open(const TrucksScreen())),
                _Row(Icons.manage_accounts_outlined, 'members'.tr(), 'members_desc'.tr(), () => open(const MembersScreen())),
              ],
            ),
            SectionHeader(title: 'checks'.tr()),
            _Group(
              rows: [
                _Row(Icons.account_balance_wallet_outlined, 'supervisor_cash'.tr(), 'supervisor_cash_desc'.tr(), () => open(const CashListScreen())),
                _Row(Icons.history_rounded, 'activity'.tr(), 'activity_desc'.tr(), () => open(const ActivityScreen())),
              ],
            ),
          ] else ...[
            SectionHeader(title: 'checks'.tr()),
            _Group(
              rows: [
                _Row(
                  Icons.account_balance_wallet_outlined,
                  'my_cash'.tr(),
                  'my_cash_desc'.tr(),
                  () => open(CashDetailScreen(holderId: core.auth.user!.id, holderName: core.auth.user!.name)),
                ),
              ],
            ),
          ],
          SectionHeader(title: 'app'.tr()),
          _Group(
            rows: [
              _Row(Icons.translate_rounded, 'language'.tr(), core.settings.language?.nativeName ?? '', () => open(const LanguageScreen())),
              _Row(Icons.logout_rounded, 'logout'.tr(), core.auth.user?.email ?? '', () => _logout(context), danger: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool danger;

  const _Row(this.icon, this.title, this.description, this.onTap, {this.danger = false});
}

class _Group extends StatelessWidget {
  final List<_Row> rows;

  const _Group({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final row in rows) ...[
            ListTile(
              minVerticalPadding: 12,
              leading: Icon(row.icon, color: row.danger ? colors.danger : colors.primary),
              title: Text(row.title, style: context.text.titleSmall?.copyWith(color: row.danger ? colors.danger : null)),
              subtitle: row.description.isEmpty ? null : Text(row.description),
              trailing: row.onTap == null ? null : Icon(Icons.chevron_right_rounded, color: colors.muted),
              onTap: row.onTap,
            ),
            if (row != rows.last) const Divider(indent: 56),
          ],
        ],
      ),
    );
  }
}
