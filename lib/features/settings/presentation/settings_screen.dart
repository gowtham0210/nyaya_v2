import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/monitoring/monitoring.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_widgets.dart';
import '../../chat/application/chat_controller.dart';
import '../../journey/application/journey_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../../reminders/application/reminder_sync.dart';
import '../../profile/domain/user_profile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final ctl = ref.read(profileProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        children: [
          // ── Learning preferences ──────────────────────────────────────────
          ListHeader(l.settingsLearningPrefs),
          SectionGroup(children: [
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: Text(l.settingsLanguage),
              subtitle: Text(p.language.nativeName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showPickerSheet<AppLanguage>(
                context,
                title: l.settingsLanguage,
                values: AppLanguage.values,
                selected: p.language,
                label: (v) => '${v.nativeName}  ·  ${v.englishName}',
                onSelected: (v) {
                  ctl.setLanguage(v);
                  unawaited(ref.read(progressSyncProvider.notifier).pushSettings());
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: Text(l.settingsDailyGoal),
              subtitle: Text(l.goalQuizzesPerDay(p.dailyGoal)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showPickerSheet<int>(
                context,
                title: l.settingsDailyGoal,
                values: const [1, 3, 5],
                selected: p.dailyGoal,
                label: l.goalQuizzesPerDay,
                onSelected: (v) {
                  ctl.setDailyGoal(v);
                  unawaited(ref.read(progressSyncProvider.notifier).pushSettings());
                },
              ),
            ),
          ]),

          // ── Appearance ────────────────────────────────────────────────────
          ListHeader(l.settingsAppearance),
          SectionGroup(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(l.settingsThemeSystem), icon: const Icon(Icons.brightness_auto_rounded)),
                  ButtonSegment(value: ThemeMode.light, label: Text(l.settingsThemeLight), icon: const Icon(Icons.light_mode_rounded)),
                  ButtonSegment(value: ThemeMode.dark, label: Text(l.settingsThemeDark), icon: const Icon(Icons.dark_mode_rounded)),
                ],
                selected: {p.themeMode},
                onSelectionChanged: (s) => ctl.setThemeMode(s.first),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: Text(l.settingsHaptics),
              value: p.hapticsOn,
              onChanged: ctl.setHaptics,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: Text(l.settingsSound),
              value: p.soundOn,
              onChanged: ctl.setSound,
            ),
          ]),

          // ── Notifications ─────────────────────────────────────────────────
          ListHeader(l.settingsNotifications),
          SectionGroup(children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_rounded),
              title: Text(l.settingsReminders),
              subtitle: Text(l.settingsRemindersSub),
              value: p.remindersOn,
              onChanged: (on) async {
                if (!on) return ctl.setReminders(false);
                // Turning on asks the phone; when notifications are blocked it says where to allow them.
                final messenger = ScaffoldMessenger.of(context);
                if (!await ref.read(reminderSyncProvider.notifier).enable()) {
                  messenger.showSnackBar(SnackBar(content: Text(l.settingsRemindersBlocked)));
                }
              },
            ),
            if (p.remindersOn)
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(l.settingsReminderTime),
                trailing: Text(
                  TimeOfDay(hour: p.reminderMinutes ~/ 60, minute: p.reminderMinutes % 60).format(context),
                  style: context.text.titleSmall?.copyWith(color: context.colors.primary),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: p.reminderMinutes ~/ 60, minute: p.reminderMinutes % 60),
                  );
                  if (picked != null) ctl.setReminderTime(picked.hour * 60 + picked.minute);
                },
              ),
          ]),

          // ── Data management ───────────────────────────────────────────────
          ListHeader(l.settingsData),
          SectionGroup(children: [
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: context.nyaya.error),
              title: Text(l.settingsReset, style: TextStyle(color: context.nyaya.error)),
              onTap: () => _reset(context, ref),
            ),
          ]),

          // ── About and support ─────────────────────────────────────────────
          ListHeader(l.settingsAboutSupport),
          SectionGroup(children: [
            ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: Text(l.settingsDisclaimer),
              onTap: () => _info(context, l.settingsDisclaimer, l.settingsDisclaimerBody),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: Text(l.settingsPrivacy),
              onTap: () => _info(context, l.settingsPrivacy, l.settingsPrivacyBody),
            ),
            // Debug builds with a Sentry key only: checks the setup. Never shown to learners.
            if (kDebugMode && Monitoring.enabled)
              ListTile(
                leading: const Icon(Icons.bug_report_rounded),
                title: const Text('Send a test error (debug)'),
                onTap: () async {
                  await Monitoring.sendTestError();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test error sent')));
                  }
                },
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              l.settingsVersion('0.1.0'),
              style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _info(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonOk))],
      ),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsReset),
        content: Text(l.settingsResetConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.nyaya.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.settingsResetAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final sync = ref.read(progressSyncProvider.notifier);
    await ref.read(profileProvider.notifier).resetAll(sameAccount: true);
    ref.read(journeyProvider.notifier).reset();
    ref.read(chatControllerProvider.notifier).clear();
    // The account says it finished onboarding; tell it to start over first,
    // or the refresh below would skip onboarding again.
    await sync.pushSettings();
    // XP, stars and streaks belong to the account, so they come back.
    unawaited(sync.refresh());
    if (context.mounted) context.go(Routes.onboarding);
  }
}
