import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';
import '../../providers/semester_providers.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/action_row.dart';
import '../../widgets/feedback.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/new_password_fields.dart';
import '../../widgets/section_header.dart';
import '../semester/semester_sheets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider);
    final name = ref.watch(displayNameProvider);

    final term = ref.watch(semesterTodayProvider);
    final semesters = ref.watch(semesterListProvider).value ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _IdentityCard(
            name: name,
            email: user?.email,
            joinedAt: profile.value?.createdAt,
            isLoadingProfile: profile.isLoading,
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            icon: Icons.school_rounded,
            accent: AppColors.primary,
            title: 'Semester',
          ),
          const SizedBox(height: 12),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                ActionRow(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.gold,
                  label: term?.semester.name ?? 'Set your current semester',
                  subtitle: term == null
                      ? 'Courses, week numbers and the routine follow it'
                      : term.label.replaceFirst(
                          '${term.semester.name}  ·  ',
                          '',
                        ),
                  onTap: () => semesters.isEmpty
                      ? showSemesterEditor(context)
                      : _pickCurrent(context, ref),
                ),
                const RowDivider(),
                ActionRow(
                  icon: Icons.date_range_rounded,
                  label: 'Semesters and vacations',
                  subtitle: semesters.isEmpty
                      ? 'Add your first semester'
                      : '${AppDate.plural(semesters.length, 'semester')}  ·  '
                            'start dates, vacations, end of classes',
                  onTap: () => context.go(AppRoutes.profileSemesters),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            icon: Icons.settings_rounded,
            accent: AppColors.blue,
            title: 'Account',
          ),
          const SizedBox(height: 12),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ActionRow(
                  icon: Icons.badge_outlined,
                  label: 'Edit your name',
                  onTap: () => showGlassSheet<void>(
                    context: context,
                    builder: (context) => _RenameSheet(initialName: name),
                  ),
                ),
                const RowDivider(),
                ActionRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change password',
                  onTap: () => showGlassSheet<void>(
                    context: context,
                    builder: (context) => const _ChangePasswordSheet(),
                  ),
                ),
                const RowDivider(),
                ActionRow(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  isDestructive: true,
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'UniFriend',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lists the semesters to choose the current one from.
  Future<void> _pickCurrent(BuildContext context, WidgetRef ref) {
    final semesters = ref.read(semesterListProvider).value ?? const [];
    final current = ref.read(currentSemesterProvider);
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => GlassSheet(
        title: 'Current semester',
        child: GlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              for (final semester in semesters.reversed) ...[
                ActionRow(
                  icon: semester.id == current?.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  iconColor: semester.id == current?.id
                      ? AppColors.primary
                      : AppColors.textHint,
                  label: semester.name,
                  subtitle:
                      'Started ${AppDate.dayMonthYear(semester.startsOn)}',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await runAction(
                      context,
                      () => ref
                          .read(profileProvider.notifier)
                          .setCurrentSemester(semester.id),
                    );
                  },
                ),
                if (semester != semesters.first) const RowDivider(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirm(
      context,
      title: 'Sign out?',
      message:
          'Your data stays on your account. The copy saved on this phone is '
          'removed.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !context.mounted) return;
    // The auth stream drives the router redirect, so there is no manual
    // navigation here.
    await runAction(context, () => ref.read(signOutAction)());
  }
}

class _IdentityCard extends StatelessWidget {
  final String name;
  final String? email;
  final DateTime? joinedAt;
  final bool isLoadingProfile;

  const _IdentityCard({
    required this.name,
    required this.email,
    required this.joinedAt,
    required this.isLoadingProfile,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'S' : name[0].toUpperCase();

    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          if (isLoadingProfile)
            Text(
              'Loading profile...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            )
          else if (email != null)
            Text(
              email!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          if (joinedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Joined ${AppDate.dayMonthYear(joinedAt!)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      navigator.pop();
    }, successMessage: 'Password changed');

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: 'Change password',
      actions: [
        SheetAction(
          label: 'Save password',
          icon: Icons.check_rounded,
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: NewPasswordFields(
          password: _password,
          confirmation: _confirmation,
        ),
      ),
    );
  }
}

class _RenameSheet extends ConsumerStatefulWidget {
  final String initialName;

  const _RenameSheet({required this.initialName});

  @override
  ConsumerState<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends ConsumerState<_RenameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      showGlassSnack(
        context,
        'Name cannot be empty',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    await runAction(context, () async {
      await ref.read(profileProvider.notifier).rename(name);
      navigator.pop();
    });

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: 'Your name',
      actions: [
        SheetAction(
          label: 'Save',
          icon: Icons.check_rounded,
          onPressed: _save,
          isBusy: _isSaving,
        ),
      ],
      child: GlassTextField(
        controller: _controller,
        label: 'Name',
        icon: Icons.badge_outlined,
        hintText: 'What should we call you?',
        textInputAction: TextInputAction.done,
        autofocus: true,
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
