import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/profile/application/profile_controller.dart';
import 'package:nyaya/features/reminders/application/reminder_sync.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
import 'package:nyaya/features/reminders/domain/reminder_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

void main() {
  group('planReminders', () {
    final morning = DateTime(2026, 11, 2, 9, 30);
    List<PlannedReminder> plan({
      DateTime? now,
      bool on = true,
      int minutes = 19 * 60,
      String? lastActiveDay,
      int streak = 0,
    }) =>
        planReminders(now: now ?? morning, on: on, minutes: minutes, lastActiveDay: lastActiveDay, streak: streak);

    test('one a day at the chosen time for a week, starting today', () {
      final p = plan(minutes: 20 * 60 + 15);
      expect(p, hasLength(7));
      expect(p.first.at, DateTime(2026, 11, 2, 20, 15));
      expect(p.last.at, DateTime(2026, 11, 8, 20, 15));
      expect(p.map((r) => r.id).toSet(), hasLength(7));
    });

    test('skips today once the learner has practised, or when the time has passed', () {
      expect(plan(lastActiveDay: '2026-11-02').first.at, DateTime(2026, 11, 3, 19));
      expect(plan(now: DateTime(2026, 11, 2, 21)).first.at, DateTime(2026, 11, 3, 19));
      // Practised on another day: today still counts.
      expect(plan(lastActiveDay: '2026-11-01').first.at, DateTime(2026, 11, 2, 19));
    });

    test('nothing when reminders are off', () {
      expect(plan(on: false), isEmpty);
    });

    test('mentions the streak only while it can still be kept', () {
      expect(plan(streak: 4).first.kind, ReminderKind.streak);
      // Done today: tomorrow's reminder keeps the streak going.
      expect(plan(streak: 4, lastActiveDay: '2026-11-02').first.kind, ReminderKind.streak);
      // Missed today and the time has passed: the streak is gone by tomorrow.
      expect(plan(streak: 4, now: DateTime(2026, 11, 2, 21)).first.kind, isNot(ReminderKind.streak));
      expect(plan(streak: 0).first.kind, isNot(ReminderKind.streak));
      expect(plan(streak: 4).skip(1).where((r) => r.kind == ReminderKind.streak), isEmpty);
    });
  });

  group('ReminderSync', () {
    late FakeReminderNotifications phone;

    Future<ProviderContainer> start({Map<String, Object> profile = const {}, Map<String, Object> prefs = const {}}) async {
      SharedPreferences.setMockInitialValues({
        'profile_v1': jsonEncode({'onboarded': true, 'name': 'Ravi', 'language': 'ta', ...profile}),
        ...prefs,
      });
      final sp = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        reminderNotificationsProvider.overrideWithValue(phone),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
      ]);
      addTearDown(c.dispose);
      c.read(reminderSyncProvider);
      await c.read(reminderSyncProvider.notifier).refresh();
      return c;
    }

    setUp(() => phone = FakeReminderNotifications());

    test('asks once after onboarding, then schedules the week in the learner\'s language', () async {
      final c = await start();
      expect(phone.permissionAsks, 1);
      expect(phone.scheduled, hasLength(7));
      expect(phone.scheduled.first.at, DateTime(2026, 11, 2, 19));
      expect(phone.scheduled.first.title, 'இன்றைய பயிற்சிக்கான நேரம்');
      await c.read(reminderSyncProvider.notifier).refresh();
      expect(phone.permissionAsks, 1, reason: 'asked only once');
    });

    test('turns reminders off when the phone says no', () async {
      phone.allow = false;
      final c = await start();
      await c.read(reminderSyncProvider.notifier).refresh();
      expect(c.read(profileProvider).remindersOn, isFalse);
      expect(phone.scheduled, isEmpty);
    });

    test('follows the time and the switch, and asks again when turned on in Settings', () async {
      final c = await start();
      c.read(profileProvider.notifier).setReminderTime(7 * 60 + 30);
      await c.read(reminderSyncProvider.notifier).refresh();
      expect(phone.scheduled.first.at, DateTime(2026, 11, 3, 7, 30), reason: '7:30 today has passed');

      c.read(profileProvider.notifier).setReminders(false);
      await c.read(reminderSyncProvider.notifier).refresh();
      expect(phone.scheduled, isEmpty);

      phone.allow = false;
      expect(await c.read(reminderSyncProvider.notifier).enable(), isFalse);
      expect(c.read(profileProvider).remindersOn, isFalse);
      phone.allow = true;
      expect(await c.read(reminderSyncProvider.notifier).enable(), isTrue);
      await c.read(reminderSyncProvider.notifier).refresh();
      expect(phone.scheduled, hasLength(6), reason: 'today at 7:30 has passed; the next six days remain');
    });

    test('schedules nothing before onboarding and does not ask', () async {
      await start(profile: {'onboarded': false});
      expect(phone.permissionAsks, 0);
      expect(phone.scheduled, isEmpty);
    });
  });
}
