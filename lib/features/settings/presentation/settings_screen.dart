import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/config/game_rules.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../chat/application/chat_controller.dart';
import '../../journey/application/journey_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_profile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final ctl = ref.read(profileProvider.notifier);
    final stars = ref.watch(journeyProvider).totalStars;

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        children: [
          // ── Profile card ──────────────────────────────────────────────────
          NyayaCard(
            color: context.nyaya.hero,
            bordered: false,
            child: Row(
              children: [
                InitialsAvatar(name: p.name, size: 60, ring: AppPalette.ochre),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: context.text.titleLarge?.copyWith(color: Colors.white)),
                      Text(l.personaName(p.persona), style: context.text.bodyMedium?.copyWith(color: Colors.white70)),
                      if (p.isPremium)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.workspace_premium_rounded, size: 16, color: AppPalette.ochre),
                              const SizedBox(width: 4),
                              Text(l.settingsPremiumActive,
                                  style: context.text.labelMedium?.copyWith(color: AppPalette.ochreSoft)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.settingsEditName,
                  onPressed: () => _editName(context, ref, p.name),
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Stats ─────────────────────────────────────────────────────────
          _Header(l.settingsStats),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              _Stat(Icons.diamond_rounded, '${p.totalXp}', l.settingsTotalXp, context.colors.primary),
              _Stat(Icons.local_fire_department_rounded, '${p.longestStreak}', l.settingsLongestStreak, context.nyaya.streak),
              _Stat(Icons.star_rounded, '$stars', l.statStars, AppPalette.ochre),
              _Stat(Icons.task_alt_rounded, '${p.quizzesCompleted}', l.settingsQuizzes, context.nyaya.success),
              _Stat(Icons.track_changes_rounded, '${(p.accuracy * 100).round()}%', l.settingsAccuracy, AppPalette.slate),
              _Stat(Icons.sports_kabaddi_rounded, '${p.duelsWon}/${p.duelsPlayed}', l.settingsDuelRecord, AppPalette.umber),
            ],
          ),

          // ── Premium & store ───────────────────────────────────────────────
          _Header(l.settingsStore),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.workspace_premium_rounded, color: AppPalette.ochreText),
              title: Text(l.settingsPremium),
              subtitle: Text(p.isPremium ? l.settingsPremiumActive : l.settingsPremiumUpgrade),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.premium),
            ),
            ListTile(
              leading: const Icon(Icons.ac_unit_rounded, color: AppPalette.frost),
              title: Text(l.settingsStreakFreeze),
              subtitle: Text(l.settingsStreakFreezeSub(p.streakFreezes, GameRules.maxStreakFreezes)),
              trailing: FilledButton.tonal(
                onPressed: () {
                  final msg = p.streakFreezes >= GameRules.maxStreakFreezes
                      ? l.settingsFreezeFull
                      : (ctl.buyStreakFreeze() ? l.settingsFreezeBought : l.energyNotEnoughCoins);
                  ref.read(feedbackProvider).play(Haptic.tap);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on_rounded, size: 16, color: AppPalette.ochreText),
                    SizedBox(width: 4),
                    Text('${GameRules.streakFreezeCoinCost}'),
                  ],
                ),
              ),
            ),
          ]),

          // ── Learning ──────────────────────────────────────────────────────
          _Header(l.settingsProfile),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: Text(l.settingsLanguage),
              subtitle: Text(p.language.nativeName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pick<AppLanguage>(
                context,
                title: l.settingsLanguage,
                values: AppLanguage.values,
                selected: p.language,
                label: (v) => '${v.nativeName}  ·  ${v.englishName}',
                onSelected: ctl.setLanguage,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: Text(l.settingsLearningAs),
              subtitle: Text(l.personaName(p.persona)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pick<Persona>(
                context,
                title: l.settingsLearningAs,
                values: Persona.values,
                selected: p.persona,
                label: l.personaName,
                onSelected: ctl.setPersona,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: Text(l.settingsDailyGoal),
              subtitle: Text(l.goalQuizzesPerDay(p.dailyGoal)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pick<int>(
                context,
                title: l.settingsDailyGoal,
                values: const [1, 3, 5],
                selected: p.dailyGoal,
                label: l.goalQuizzesPerDay,
                onSelected: ctl.setDailyGoal,
              ),
            ),
          ]),

          // ── App ───────────────────────────────────────────────────────────
          _Header(l.settingsAppearance),
          _Group(children: [
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
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_rounded),
              title: Text(l.settingsReminders),
              subtitle: Text(l.settingsRemindersSub),
              value: p.remindersOn,
              onChanged: ctl.setReminders,
            ),
          ]),

          // ── About ─────────────────────────────────────────────────────────
          _Header(l.settingsAbout),
          _Group(children: [
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
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: context.nyaya.error),
              title: Text(l.settingsReset, style: TextStyle(color: context.nyaya.error)),
              onTap: () => _reset(context, ref),
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

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final l = context.l10n;
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsEditName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l.onbNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(l.commonDone)),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) ref.read(profileProvider.notifier).setName(name);
  }

  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: context.text.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<T>(
              groupValue: selected,
              onChanged: (v) {
                if (v != null) onSelected(v);
                Navigator.pop(context);
              },
              child: Column(
                children: [
                  for (final v in values) RadioListTile<T>(value: v, title: Text(label(v))),
                ],
              ),
            ),
          ],
        ),
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
    await ref.read(profileProvider.notifier).resetAll();
    ref.read(journeyProvider.notifier).reset();
    ref.read(chatControllerProvider.notifier).clear();
    if (context.mounted) context.go(Routes.onboarding);
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelMedium?.copyWith(color: context.nyaya.textSecondary, letterSpacing: 1.1),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (not a DecoratedBox) so ListTile ink and backgrounds render.
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: context.nyaya.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, this.color);

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NyayaCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(value, style: context.text.titleMedium, maxLines: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary),
          ),
        ],
      ),
    );
  }
}
