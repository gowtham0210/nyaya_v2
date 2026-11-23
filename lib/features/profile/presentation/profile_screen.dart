import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/config/features.dart';
import '../../../core/config/game_rules.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/section_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/chat_controller.dart';
import '../../journey/application/journey_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../../settings/presentation/delete_account_dialog.dart';
import '../../settings/presentation/edit_name_dialog.dart';
import '../application/profile_controller.dart';
import '../domain/user_profile.dart';

/// My Profile: who the learner is, their progress, the store and the account.
/// App preferences live in Settings.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.openStore = false});

  /// Opened from the coins pill or "Open the Store": scrolls to the store.
  final bool openStore;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _storeKey = GlobalKey();

  /// Set once the learner scrolls themselves, so nothing pulls the page back.
  bool _userScrolled = false;

  /// The Store card glows for a moment after "Open the Store", so it is easy to spot.
  bool _highlightStore = false;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    if (!widget.openStore) return;
    _highlightStore = true;
    _timers.add(
      Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _highlightStore = false);
      }),
    );
    // Scroll once the page is laid out, then again as it settles: the sync,
    // a late font or the premium badge can change the height above the Store
    // after the first scroll and leave the heading off its place.
    WidgetsBinding.instance.addPostFrameCallback((_) => _alignStore(animate: true));
    for (final ms in const [400, 900, 1800]) {
      _timers.add(Timer(Duration(milliseconds: ms), () => _alignStore(animate: false)));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _alignStore({required bool animate}) {
    final target = _storeKey.currentContext;
    if (!mounted || _userScrolled || target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final stars = ref.watch(journeyProvider).totalStars;
    final account = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          if (n.dragDetails != null) _userScrolled = true;
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
          children: [
            // ── Header ────────────────────────────────────────────────────────
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
                        Text(
                          p.name.isEmpty ? l.onbNameHint : p.name,
                          style: context.text.titleLarge?.copyWith(color: Colors.white),
                        ),
                        if (account != null)
                          Text(
                            account.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        if (p.isPremium)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.workspace_premium_rounded, size: 16, color: AppPalette.ochre),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    l.settingsPremiumActive,
                                    style: context.text.labelMedium?.copyWith(color: AppPalette.ochreSoft),
                                  ),
                                ),
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

            // ── Learning identity ─────────────────────────────────────────────
            ListHeader(l.profileIdentity),
            SectionGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_rounded),
                  title: Text(l.settingsLearningAs),
                  subtitle: Text(l.personaName(p.persona)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showPickerSheet<Persona>(
                    context,
                    title: l.settingsLearningAs,
                    values: Persona.values,
                    selected: p.persona,
                    label: l.personaName,
                    onSelected: (v) {
                      ref.read(profileProvider.notifier).setPersona(v);
                      unawaited(ref.read(progressSyncProvider.notifier).pushSettings());
                    },
                  ),
                ),
              ],
            ),

            // ── Progress ──────────────────────────────────────────────────────
            ListHeader(l.profileProgress),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // Taller tiles when the phone uses larger text.
              childAspectRatio: 1.05 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, double.infinity),
              children: [
                StatTile(Icons.diamond_rounded, '${p.totalXp}', l.settingsTotalXp, context.colors.primary),
                StatTile(
                  Icons.local_fire_department_rounded,
                  '${p.longestStreak}',
                  l.settingsLongestStreak,
                  context.nyaya.streak,
                ),
                StatTile(Icons.star_rounded, '$stars', l.statStars, AppPalette.ochre),
                StatTile(Icons.task_alt_rounded, '${p.quizzesCompleted}', l.settingsQuizzes, context.nyaya.success),
                StatTile(
                  Icons.track_changes_rounded,
                  '${(p.accuracy * 100).round()}%',
                  l.settingsAccuracy,
                  AppPalette.slate,
                ),
                StatTile(
                  Icons.sports_kabaddi_rounded,
                  '${p.duelsWon}/${p.duelsPlayed}',
                  l.settingsDuelRecord,
                  AppPalette.umber,
                ),
              ],
            ),

            // ── Store and membership ──────────────────────────────────────────
            KeyedSubtree(key: _storeKey, child: ListHeader('${l.settingsStore} · ${p.coins} ${l.statCoins}')),
            AnimatedContainer(
              key: const Key('store-card'),
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: _highlightStore
                    ? [
                        BoxShadow(
                          color: context.colors.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: SectionGroup(
                borderColor: _highlightStore ? context.colors.primary : null,
                children: [
                  if (Features.premium)
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
                      onPressed: () => _buyFreeze(context, ref, p),
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
                ],
              ),
            ),

            // ── App settings entry ────────────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            SectionGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: Text(l.settingsTitle),
                  subtitle: Text(l.profileSettingsSub),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.settings),
                ),
              ],
            ),

            // ── Account ───────────────────────────────────────────────────────
            ListHeader(l.settingsAccount),
            SectionGroup(
              children: [
                if (account == null)
                  ListTile(
                    leading: const Icon(Icons.login_rounded),
                    title: Text(l.settingsSignIn),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(Routes.signIn),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(l.settingsSignOut),
                    onTap: () => _signOut(context, ref),
                  ),
              ],
            ),

            // ── Danger zone ───────────────────────────────────────────────────
            if (account != null) ...[
              ListHeader(l.profileDangerZone, color: context.nyaya.error),
              SectionGroup(
                borderColor: context.nyaya.error,
                children: [
                  ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: context.nyaya.error),
                    title: Text(
                      l.profileDangerBody,
                      style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.person_off_rounded, color: context.nyaya.error),
                    title: Text(l.settingsDeleteAccount, style: TextStyle(color: context.nyaya.error)),
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EditNameDialog(current: current),
    );
    if (name == null || name.trim().isEmpty) return;
    final clean = name.trim();
    // One name: the profile is what every screen shows; the sign-in snapshot
    // follows it, and the server gets it through the existing settings call.
    ref.read(profileProvider.notifier).setName(clean);
    unawaited(ref.read(authProvider.notifier).updateDisplayName(clean));
    unawaited(ref.read(progressSyncProvider.notifier).pushSettings());
  }

  Future<void> _buyFreeze(BuildContext context, WidgetRef ref, UserProfile p) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(feedbackProvider).play(Haptic.tap);
    if (p.streakFreezes >= GameRules.maxStreakFreezes) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsFreezeFull)));
      return;
    }
    final failed = await ref.read(progressSyncProvider.notifier).buyStreakFreeze();
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (failed) {
          null => l.settingsFreezeBought,
          'not_enough_coins' => l.energyNotEnoughCoins,
          'freezes_full' => l.settingsFreezeFull,
          _ => l.commonSomethingWrong,
        }),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.profileSignOutTitle),
        content: Text(l.profileSignOutBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.settingsSignOut)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authProvider.notifier).signOut();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final gone = await showDialog<bool>(context: context, builder: (_) => const DeleteAccountDialog());
    if (gone != true || !context.mounted) return;
    // The server holds no data any more; clear what the phone kept and start over.
    await ref.read(profileProvider.notifier).resetAll();
    ref.read(journeyProvider.notifier).reset();
    ref.read(chatControllerProvider.notifier).clear();
    if (context.mounted) context.go(Routes.onboarding);
  }
}
