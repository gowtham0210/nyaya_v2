/// Calendar helpers. Daily systems (energy, streak, daily challenge) key off
/// the user's *local* calendar day, stored as `yyyy-mm-dd`.
abstract final class Day {
  static String key(DateTime t) {
    final d = DateTime(t.year, t.month, t.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// Whole calendar days from [from] to [to] (DST-safe).
  static int between(String from, String to) {
    final a = parse(from);
    final b = parse(to);
    return DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
  }

  static Duration untilMidnight(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1).difference(now);

  /// ISO-like week id (`2026-W43`) with weeks starting Monday — used for
  /// weekly leagues.
  static String weekKey(DateTime t) {
    final monday = weekStart(t);
    final thursday = monday.add(const Duration(days: 3));
    final firstThursday = _firstThursday(thursday.year);
    final week = 1 + DateTime.utc(thursday.year, thursday.month, thursday.day)
            .difference(firstThursday)
            .inDays ~/
        7;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static DateTime weekStart(DateTime t) {
    final d = DateTime(t.year, t.month, t.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static Duration untilWeekEnd(DateTime now) =>
      weekStart(now).add(const Duration(days: 7)).difference(now);

  static DateTime _firstThursday(int year) {
    var d = DateTime.utc(year, 1, 1);
    while (d.weekday != DateTime.thursday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}

String formatCountdown(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m ${d.inSeconds % 60}s';
}
