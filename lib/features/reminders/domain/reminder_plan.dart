import 'package:flutter/foundation.dart';

import '../../../core/utils/day.dart';

/// Which message a reminder carries.
enum ReminderKind { streak, learn, journey, rights }

@immutable
class PlannedReminder {
  const PlannedReminder({required this.id, required this.at, required this.kind});

  /// Notification id; one per day ahead, so a new plan replaces the old one.
  final int id;

  /// Local date and time it shows.
  final DateTime at;
  final ReminderKind kind;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder && other.id == id && other.at == at && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, at, kind);

  @override
  String toString() => 'PlannedReminder($id, $at, $kind)';
}

/// Days of reminders kept scheduled ahead. Opening the app tops them up, so a
/// learner who stops opening it gets a week of reminders, then quiet.
const reminderDaysAhead = 7;

const reminderIdBase = 1000;

/// The reminders to schedule from [now]: one a day at [minutes] after
/// midnight, for [reminderDaysAhead] days. Today is skipped when the learner
/// already practised ([lastActiveDay] is today) or the time has passed.
/// The first one mentions the streak when there is still one to keep; the
/// rest take turns with the other messages.
List<PlannedReminder> planReminders({
  required DateTime now,
  required bool on,
  required int minutes,
  required String? lastActiveDay,
  required int streak,
}) {
  if (!on) return const [];
  const others = [ReminderKind.learn, ReminderKind.journey, ReminderKind.rights];
  final today = DateTime(now.year, now.month, now.day);
  final out = <PlannedReminder>[];
  for (var i = 0; i < reminderDaysAhead; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    final at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    if (i == 0 && (lastActiveDay == Day.key(now) || !at.isAfter(now))) continue;
    // The streak is only still alive today, or tomorrow when today is done.
    final streakAlive = streak > 0 && (i == 0 || (i == 1 && lastActiveDay == Day.key(now)));
    final kind = out.isEmpty && streakAlive ? ReminderKind.streak : others[(day.day + i) % others.length];
    out.add(PlannedReminder(id: reminderIdBase + i, at: at, kind: kind));
  }
  return out;
}
