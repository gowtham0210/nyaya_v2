import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../data/mock_exam_api.dart';
import '../domain/mock_exam_models.dart';

/// The exams the learner API shows right now, in the app's fixed order.
///
/// Each known slug is asked once with a read; an exam that is switched off
/// answers 404 and stays out of sight. Nothing here starts an attempt or turns
/// an exam on. When every check fails (no connection) this throws, so the
/// screen can offer a retry instead of claiming there is nothing.
final availableMockExamsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  if (ref.watch(authProvider) == null) return const [];
  final api = ref.watch(mockExamApiProvider);
  Object? failure;
  final checks = await Future.wait([
    for (final slug in MockExamSlugs.all)
      api.isAvailable(slug).then<bool>((v) => v).catchError((Object e) {
        failure = e;
        return false;
      }),
  ]);
  final shown = [
    for (final (i, slug) in MockExamSlugs.all.indexed)
      if (checks[i]) slug,
  ];
  if (shown.isEmpty && failure != null) throw failure!;
  return shown;
}, retry: (_, _) => null);

/// Every published paper of an exam (a few pages at most).
final mockExamPapersProvider = FutureProvider.autoDispose.family<List<PaperSummary>, String>((ref, slug) async {
  final api = ref.watch(mockExamApiProvider);
  final out = <PaperSummary>[];
  String? cursor;
  for (var page = 0; page < 5; page++) {
    final p = await api.papers(slug, cursor: cursor);
    out.addAll(p.items);
    cursor = p.nextCursor;
    if (cursor == null) break;
  }
  return out;
}, retry: (_, _) => null);

/// The unfinished attempt for an exam, or null. Reads only.
final activeMockAttemptProvider = FutureProvider.autoDispose.family<Attempt?, String>((ref, slug) async {
  try {
    return await ref.watch(mockExamApiProvider).activeAttempt(slug);
  } on ApiException catch (e) {
    // Offline: the cached attempt is offered by the attempt screen itself.
    if (e.isNetwork) return null;
    rethrow;
  }
}, retry: (_, _) => null);

final attemptResultProvider = FutureProvider.autoDispose.family<AttemptResult, String>(
  (ref, id) => ref.watch(mockExamApiProvider).result(id),
  retry: (_, _) => null,
);

/// Only asked for after the attempt is submitted; never cached on the device.
final attemptReviewProvider = FutureProvider.autoDispose.family<AttemptReview, String>(
  (ref, id) => ref.watch(mockExamApiProvider).review(id),
  retry: (_, _) => null,
);

final attemptHistoryProvider = FutureProvider.autoDispose.family<List<AttemptSummary>, String?>((ref, exam) async {
  final api = ref.watch(mockExamApiProvider);
  final out = <AttemptSummary>[];
  String? cursor;
  for (var page = 0; page < 5; page++) {
    final p = await api.history(exam: exam, cursor: cursor);
    out.addAll(p.items);
    cursor = p.nextCursor;
    if (cursor == null) break;
  }
  return out;
}, retry: (_, _) => null);

final examStatsProvider = FutureProvider.autoDispose<List<ExamStats>>(
  (ref) => ref.watch(mockExamApiProvider).stats(),
  retry: (_, _) => null,
);
