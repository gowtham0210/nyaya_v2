/// The Daily Tip changes at 00:00 India time, whatever the phone's own time
/// zone is. India keeps one fixed offset all year (no daylight saving), so
/// no time-zone database is needed.
const indiaOffset = Duration(hours: 5, minutes: 30);

/// The India calendar day (`2026-11-17`) at the instant [now].
String indiaDay(DateTime now) {
  final d = now.toUtc().add(indiaOffset);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// How long from [now] until the next 00:00 in India; always above zero.
Duration untilIndiaMidnight(DateTime now) {
  final d = now.toUtc().add(indiaOffset);
  return DateTime.utc(d.year, d.month, d.day + 1).difference(d);
}
