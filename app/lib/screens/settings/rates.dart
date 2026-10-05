import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/screens/home/home.dart';
import 'package:khanak/types/work.dart';

/// What each kind of work pays. Changing a rate only affects new entries:
/// every entry keeps the rate of its day. Only the owner can change them.
class RatesScreen extends StatefulWidget {
  final bool isOnboarding;

  const RatesScreen({super.key, this.isOnboarding = false});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().factory.fetchWorkTypes());
  }

  String _unitText(PayUnit unit) => 'rate_unit_${unit.value}'.tr();

  Future<void> _editRate(WorkType type) async {
    final controller = TextEditingController(
      text: type.rate == null || type.rate == 0 ? '' : Formatters.formatDouble(type.rate!),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type.label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [DecimalInputFormatter(decimals: 2)],
          style: context.text.headlineSmall,
          decoration: InputDecoration(prefixText: '₹ ', suffixText: _unitText(type.payUnit)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: Text('save'.tr())),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;

    final module = context.read<Core>().factory;
    final ok = await module.updateWorkType(type.id, {'rate': value});
    if (!ok) showErrorToast(module.error ?? 'error_generic'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final module = core.factory;
    final isOwner = core.can(MemberRole.owner);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text('rates'.tr()),
      ),
      body: LoadStateBody<List<WorkType>>(
        state: module.workTypes,
        onRetry: () => module.fetchWorkTypes(refresh: true).then((_) {}),
        builder: (context, types) {
          // Monthly salary is set on each driver, not here.
          final shown = types.where((t) => t.isActive && t.payUnit != PayUnit.perMonth).toList();
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            children: [
              Text(
                widget.isOnboarding ? 'rates_onboarding'.tr() : 'rates_help'.tr(),
                style: context.text.bodyLarge?.copyWith(color: colors.inkSecondary),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              for (final type in shown) ...[
                AppCard(
                  onTap: isOwner && type.payUnit.hasRate ? () => _editRate(type) : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type.label, style: context.text.titleMedium),
                            Text(
                              type.isGroup ? 'rate_shared_by_group'.tr() : 'rate_per_worker'.tr(),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (type.payUnit.hasRate)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              (type.rate ?? 0) == 0 ? 'rate_not_set'.tr() : Formatters.formatCurrency(type.rate!),
                              style: context.text.titleMedium?.copyWith(
                                color: (type.rate ?? 0) == 0 ? colors.danger : colors.ink,
                              ),
                            ),
                            Text(_unitText(type.payUnit), style: context.text.bodySmall),
                          ],
                        )
                      else
                        Text('rate_typed_each_time'.tr(), style: context.text.bodySmall),
                      if (isOwner && type.payUnit.hasRate) ...[
                        const SizedBox(width: AppTheme.spaceSm),
                        Icon(Icons.edit_rounded, size: 20, color: colors.muted),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
              ],
              if (widget.isOnboarding) ...[
                const SizedBox(height: AppTheme.spaceLg),
                AppButton(
                  text: 'continue'.tr(),
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    getPageRoute(const HomeScreen()),
                    (_) => false,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
