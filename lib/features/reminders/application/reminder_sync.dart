import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/storage/local_store.dart';
import '../../profile/application/profile_controller.dart';
import '../data/reminder_notifications.dart';
import '../domain/reminder_plan.dart';

/// Keeps the phone's daily reminders in step with the profile: the switch,
/// the time, the language, and whether today's practice is done. Watch it once
/// near the root so it stays alive; call [refresh] when the app comes back.
final reminderSyncProvider = NotifierProvider<ReminderSync, void>(ReminderSync.new);

class ReminderSync extends Notifier<void> {
  /// Set once the learner has been asked, so the question comes only once.
  static const _askedKey = 'reminder_permission_asked_v1';

  /// Runs one refresh after another, never two at once.
  Future<void> _queue = Future.value();

  ReminderNotifications get _notifications => ref.read(reminderNotificationsProvider);
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  void build() {
    ref.listen(
      profileProvider.select(
        (p) => (p.onboarded, p.remindersOn, p.reminderMinutes, p.lastActiveDay, p.streak, p.language),
      ),
      (_, _) => refresh(),
      fireImmediately: true,
    );
  }

  /// Schedules the coming week's reminders afresh (or clears them).
  Future<void> refresh() => _queue = _queue.then((_) => _refresh()).catchError((Object e) {
        // A reminder that could not be set must never break the app.
        debugPrint('Reminders not updated: $e');
      });

  /// Turns reminders on from Settings: asks the phone first. False when
  /// notifications are blocked, and reminders stay off.
  Future<bool> enable() async {
    final allowed = await _notifications.requestPermission();
    await _prefs.setBool(_askedKey, true);
    ref.read(profileProvider.notifier).setReminders(allowed);
    return allowed;
  }

  Future<void> _refresh() async {
    final p = ref.read(profileProvider);
    if (!p.onboarded) return _notifications.replaceAll(const []);
    // Reminders start on; the phone's question comes right after onboarding.
    if (p.remindersOn && !(_prefs.getBool(_askedKey) ?? false) && !await _askOnce()) return;
    final plan = planReminders(
      now: ref.read(clockProvider)(),
      on: p.remindersOn,
      minutes: p.reminderMinutes,
      lastActiveDay: p.lastActiveDay,
      streak: p.streak,
    );
    final l = lookupAppLocalizations(Locale(p.language.code));
    await _notifications.replaceAll([
      for (final r in plan) (id: r.id, at: r.at, title: l.reminderTitle, body: _body(l, r.kind, p.streak)),
    ]);
  }

  /// Asks for permission the first time. When it is refused, reminders turn
  /// off (which schedules nothing) and false is returned.
  Future<bool> _askOnce() async {
    await _prefs.setBool(_askedKey, true);
    final allowed = await _notifications.requestPermission();
    if (!allowed) ref.read(profileProvider.notifier).setReminders(false);
    return allowed;
  }

  static String _body(AppLocalizations l, ReminderKind kind, int streak) => switch (kind) {
        ReminderKind.streak => l.reminderStreak(streak),
        ReminderKind.learn => l.reminderLearn,
        ReminderKind.journey => l.reminderJourney,
        ReminderKind.rights => l.reminderRights,
      };
}
