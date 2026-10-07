import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/pageHeader.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/support.dart';
import 'package:khanak/screens/auth/login.dart';
import 'package:khanak/screens/cash/detail.dart';
import 'package:khanak/screens/cash/list.dart';
import 'package:khanak/screens/entries/list.dart';
import 'package:khanak/screens/factory/form.dart';
import 'package:khanak/screens/factory/list.dart';
import 'package:khanak/screens/more/activity.dart';
import 'package:khanak/screens/more/kilns.dart';
import 'package:khanak/screens/more/members.dart';
import 'package:khanak/screens/more/season.dart';
import 'package:khanak/screens/more/trucks.dart';
import 'package:khanak/screens/settings/language.dart';
import 'package:khanak/screens/settings/profile.dart';

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
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppTheme.fabClearance),
          children: [
            LargeTitle(title: 'tab_more'.tr()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Group(
                    caption: factory.name,
                    rows: [
                      if (owner)
                        _Row(
                          Tint.bricks,
                          Icons.factory_rounded,
                          'factory_edit'.tr(),
                          'factory_edit_desc'.tr(),
                          () => open(FactoryFormScreen(factory: factory)),
                        ),
                      if (core.factory.factories.length > 1 || owner)
                        _Row(
                          Tint.neutral,
                          Icons.swap_horiz_rounded,
                          'factories'.tr(),
                          'factories_desc'.tr(),
                          () => open(const FactoryListScreen()),
                        ),
                      if (owner)
                        _Row(
                          Tint.fire,
                          Icons.workspace_premium_rounded,
                          'subscription'.tr(),
                          subscription == null
                              ? 'subscription_none'.tr()
                              : 'subscription_until'.tr(
                                  namedArgs: {
                                    'plan': subscription.isTrial
                                        ? 'trial'.tr()
                                        : (subscription.planName ?? subscription.planCode),
                                    'date': subscription.endsAt == null
                                        ? ''
                                        : Formatters.formatDate(subscription.endsAt!.toLocal()),
                                  },
                                ),
                          null,
                        ),
                    ],
                  ),
                  if (manager) ...[
                    _Group(
                      caption: 'setup'.tr(),
                      rows: [
                        _Row(
                          Tint.money,
                          Icons.event_repeat_rounded,
                          'season'.tr(),
                          'season_desc'.tr(),
                          () => open(const SeasonScreen()),
                        ),
                        _Row(
                          Tint.fire,
                          Icons.local_fire_department_rounded,
                          'kilns'.tr(),
                          'kilns_desc'.tr(),
                          () => open(const KilnsScreen()),
                        ),
                        _Row(
                          Tint.truck,
                          Icons.local_shipping_rounded,
                          'trucks'.tr(),
                          'trucks_desc'.tr(),
                          () => open(const TrucksScreen()),
                        ),
                        _Row(
                          Tint.expense,
                          Icons.manage_accounts_rounded,
                          'members'.tr(),
                          'members_desc'.tr(),
                          () => open(const MembersScreen()),
                        ),
                      ],
                    ),
                    _Group(
                      caption: 'checks'.tr(),
                      rows: [
                        _Row(
                          Tint.bricks,
                          Icons.receipt_long_rounded,
                          'all_entries'.tr(),
                          'all_entries_desc'.tr(),
                          () => open(const EntriesTab()),
                        ),
                        _Row(
                          Tint.money,
                          Icons.account_balance_wallet_rounded,
                          'supervisor_cash'.tr(),
                          'supervisor_cash_desc'.tr(),
                          () => open(const CashListScreen()),
                        ),
                        _Row(
                          Tint.neutral,
                          Icons.history_rounded,
                          'activity'.tr(),
                          'activity_desc'.tr(),
                          () => open(const ActivityScreen()),
                        ),
                      ],
                    ),
                  ] else
                    _Group(
                      caption: 'checks'.tr(),
                      rows: [
                        _Row(
                          Tint.money,
                          Icons.account_balance_wallet_rounded,
                          'my_cash'.tr(),
                          'my_cash_desc'.tr(),
                          () => open(CashDetailScreen(holderId: core.auth.user!.id, holderName: core.auth.user!.name)),
                        ),
                      ],
                    ),
                  _Group(
                    caption: 'app'.tr(),
                    rows: [
                      _Row(
                        Tint.bricks,
                        Icons.person_rounded,
                        'profile'.tr(),
                        core.auth.user?.name ?? '',
                        () => open(const ProfileScreen()),
                      ),
                      _Row(
                        Tint.truck,
                        Icons.translate_rounded,
                        'language'.tr(),
                        core.settings.language?.nativeName ?? '',
                        () => open(const LanguageScreen()),
                      ),
                    ],
                  ),
                  _Group(
                    caption: 'help'.tr(),
                    rows: [
                      _Row(
                        Tint.money,
                        Icons.chat_rounded,
                        'contact_us'.tr(),
                        'contact_us_desc'.tr(),
                        openSupportChat,
                      ),
                      _Row(
                        Tint.neutral,
                        Icons.description_outlined,
                        'terms'.tr(),
                        '',
                        () => openLegalPage(LegalPage.terms),
                      ),
                      _Row(
                        Tint.neutral,
                        Icons.privacy_tip_outlined,
                        'privacy_policy'.tr(),
                        '',
                        () => openLegalPage(LegalPage.privacy),
                      ),
                    ],
                  ),
                  _Group(
                    rows: [
                      _Row(
                        Tint.neutral,
                        Icons.logout_rounded,
                        'logout'.tr(),
                        core.auth.user?.email ?? '',
                        () => _logout(context),
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  final Tint tint;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool danger;

  const _Row(this.tint, this.icon, this.title, this.description, this.onTap, {this.danger = false});
}

class _Group extends StatelessWidget {
  final String? caption;
  final List<_Row> rows;

  const _Group({this.caption, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (rows.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2xl),
      child: GroupedSection(
        caption: caption,
        children: [
          for (final row in rows)
            GroupedRow(
              leading: row.danger
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: colors.dangerSoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(row.icon, size: 19, color: colors.danger),
                    )
                  : TintIcon(tint: row.tint, icon: row.icon),
              title: row.title,
              titleColor: row.danger ? colors.danger : null,
              subtitle: row.description.isEmpty ? null : row.description,
              onTap: row.onTap,
            ),
        ],
      ),
    );
  }
}
