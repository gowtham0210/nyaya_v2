import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../domain/mock_exam_models.dart';

/// Exam names are acronyms, the same in every language.
String mockExamName(String slug) => switch (slug) {
      MockExamSlugs.aibe => 'AIBE',
      MockExamSlugs.clat => 'CLAT',
      MockExamSlugs.ailet => 'AILET',
      _ => slug.toUpperCase(),
    };

/// The exam's full name, shown under its acronym. Proper nouns, so not translated.
String? mockExamFullName(String slug) => switch (slug) {
      MockExamSlugs.aibe => 'All India Bar Examination',
      MockExamSlugs.clat => 'Common Law Admission Test',
      MockExamSlugs.ailet => 'All India Law Entrance Test',
      _ => null,
    };

/// 1:05:09 for long times, 5:09 for short ones.
String formatCountdown(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// 12 for whole marks, 12.25 otherwise.
String formatMarks(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// A message for a failed start of an attempt, from the API's error code.
String startErrorMessage(AppLocalizations l, Object e) {
  if (e is! ApiException) return l.mockStartFailed;
  if (e.isNetwork) return l.mockNetworkError;
  return switch (e.code) {
    'no_current_blueprint' => l.mockStartNoBlueprint,
    'mock_pool_insufficient' || 'mock_blueprint_invalid' => l.mockStartPoolShort,
    'attempt_in_progress' => l.mockStartInProgress,
    'timed_mode_not_allowed' => l.mockStartTimedRefused,
    _ => l.mockStartFailed,
  };
}
