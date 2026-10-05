import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/appTextField.dart';
import 'package:khanak/components/confirmationDialog.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/loadStateBody.dart';
import 'package:khanak/components/workerPicker.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/helpers/validators.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/worker.dart';

/// Who else can use the app for this factory: a munim, or a supervisor (the
/// khadkaniyo who runs the kiln while the owner is away). They sign up on
/// their own phone first; the owner adds them by that email.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<Core>().factory.fetchMembers());
  }

  Future<void> _remove(Member member) async {
    final ok = await showConfirmDialog(
      context,
      title: 'remove_member_title'.tr(),
      message: 'remove_member_message'.tr(namedArgs: {'name': member.name}),
      confirmText: 'remove'.tr(),
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    final module = context.read<Core>().factory;
    if (!await module.removeMember(member.userId)) showErrorToast(module.error ?? 'error_generic'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<Core>();
    final module = core.factory;
    final owner = core.can(MemberRole.owner);

    return Scaffold(
      appBar: AppBar(title: Text('members'.tr())),
      floatingActionButton: owner
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const _AddMemberSheet(),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('member_add'.tr()),
            )
          : null,
      body: LoadStateBody<List<Member>>(
        state: module.members,
        onRetry: () => module.fetchMembers(refresh: true).then((_) {}),
        builder: (context, members) => ListView(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.fabClearance),
          children: [
            Text('members_help'.tr(), style: context.text.bodyMedium),
            const SizedBox(height: AppTheme.spaceLg),
            for (final member in members) ...[
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: context.text.titleMedium),
                          Text(member.email, style: context.text.bodySmall),
                          Text(
                            [member.role.displayName, if (member.workerName != null) 'paid_as'.tr(namedArgs: {'name': member.workerName!})].join(' · '),
                            style: context.text.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    if (owner && member.role != MemberRole.owner)
                      IconButton(
                        tooltip: 'remove'.tr(),
                        icon: Icon(Icons.person_remove_alt_1_rounded, color: context.colors.danger),
                        onPressed: () => _remove(member),
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

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  MemberRole _role = MemberRole.supervisor;
  Worker? _worker;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final module = context.read<Core>().factory;
    setState(() => _busy = true);
    final ok = await module.addMember(
      email: _emailController.text.trim().toLowerCase(),
      role: _role.value,
      workerId: _worker?.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return showErrorToast(module.error ?? 'error_generic'.tr());
    showSuccessToast('member_added'.tr());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceLg),
          children: [
            Text('member_add'.tr(), style: context.text.titleLarge),
            const SizedBox(height: AppTheme.spaceSm),
            Text('member_add_help'.tr(), style: context.text.bodyMedium),
            const SizedBox(height: AppTheme.spaceLg),
            AppTextField(
              controller: _emailController,
              labelText: 'email'.tr(),
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: Validators.email,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ChoiceRow<MemberRole>(
              options: const [MemberRole.supervisor, MemberRole.munim],
              selected: _role,
              label: (role) => role.displayName,
              onSelected: (role) => setState(() => _role = role),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text('role_help_${_role.value}'.tr(), style: context.text.bodySmall),
            const SizedBox(height: AppTheme.spaceLg),
            OutlinedButton.icon(
              onPressed: () async {
                final worker = await pickWorker(context, title: 'member_worker'.tr());
                if (worker != null) setState(() => _worker = worker);
              },
              icon: const Icon(Icons.badge_outlined),
              label: Text(_worker == null ? 'member_worker'.tr() : 'paid_as'.tr(namedArgs: {'name': _worker!.name})),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text('member_worker_help'.tr(), style: context.text.bodySmall),
            const SizedBox(height: AppTheme.space2xl),
            AppButton(text: 'member_add'.tr(), isLoading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
