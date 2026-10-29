import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/journey.dart';

@immutable
class JourneyProgress {
  const JourneyProgress({this.stars = const {}, this.openedChests = const {}});

  final Map<String, int> stars;
  final Set<String> openedChests;

  bool isDone(JourneyNode n) => n.kind == NodeKind.chest ? openedChests.contains(n.id) : (stars[n.id] ?? 0) > 0;

  /// The first node not yet completed; null when the whole road is done.
  JourneyNode? get current {
    for (final n in JourneyCatalog.nodes) {
      if (!isDone(n)) return n;
    }
    return null;
  }

  NodeStatus status(JourneyNode n) {
    if (isDone(n)) return NodeStatus.completed;
    return current?.id == n.id ? NodeStatus.current : NodeStatus.locked;
  }

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  int completedLevelsIn(String chapterId) =>
      JourneyCatalog.nodes.where((n) => n.chapter.id == chapterId && n.kind == NodeKind.level && isDone(n)).length;

  /// Chapters the learner has reached — used to pick Daily Docket / Exam
  /// questions they have context for (always includes the first chapter).
  Set<String> get reachedChapters {
    final cur = current;
    final upto = cur?.chapterIndex ?? JourneyCatalog.chapters.length - 1;
    return {for (var i = 0; i <= upto; i++) JourneyCatalog.chapters[i].id};
  }

  JourneyProgress copyWith({Map<String, int>? stars, Set<String>? openedChests}) =>
      JourneyProgress(stars: stars ?? this.stars, openedChests: openedChests ?? this.openedChests);

  Map<String, dynamic> toJson() => {'stars': stars, 'chests': openedChests.toList()};

  factory JourneyProgress.fromJson(Map<String, dynamic> j) => JourneyProgress(
    stars: (j['stars'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v as int)),
    openedChests: (j['chests'] as List<dynamic>? ?? []).cast<String>().toSet(),
  );
}

final journeyProvider = NotifierProvider<JourneyController, JourneyProgress>(JourneyController.new);

class JourneyController extends Notifier<JourneyProgress> {
  static const _key = 'journey_v1';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  JourneyProgress build() {
    final json = ref.watch(localStoreProvider).readJson(_key);
    return json == null ? const JourneyProgress() : JourneyProgress.fromJson(json);
  }

  void _set(JourneyProgress p) {
    state = p;
    _store.writeJson(_key, p.toJson());
  }

  /// Copies the server's best stars and opened chests (the server owns them).
  void applyServer({required Map<String, int> stars, required Set<String> openedChests}) =>
      _set(JourneyProgress(stars: stars, openedChests: openedChests));

  /// Until the server's figures arrive, show a level result straight away.
  void showBest(String levelId, int stars) {
    if (stars <= (state.stars[levelId] ?? 0)) return;
    _set(state.copyWith(stars: {...state.stars, levelId: stars}));
  }

  void reset() => _set(const JourneyProgress());
}
