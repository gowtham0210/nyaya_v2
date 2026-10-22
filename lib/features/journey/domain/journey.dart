import 'package:material_ui/material_ui.dart';

enum NodeKind { level, chest }

/// Static description of one chapter on the map.
@immutable
class ChapterMeta {
  const ChapterMeta({
    required this.id,
    required this.icon,
    required this.color,
    required this.levels,
  });

  final String id;
  final IconData icon;
  final Color color;
  final int levels;
}

/// One stop on the Candy-Crush-style road.
@immutable
class JourneyNode {
  const JourneyNode({
    required this.id,
    required this.kind,
    required this.chapter,
    required this.chapterIndex,
    required this.level,
    required this.globalIndex,
  });

  /// `constitution_2` for levels, `constitution_chest` for chests.
  final String id;
  final NodeKind kind;
  final ChapterMeta chapter;
  final int chapterIndex;

  /// 1-based level within chapter (0 for chests).
  final int level;

  /// Position on the whole road, 0-based from the start.
  final int globalIndex;

  /// Every third level is a "Landmark" boss level with a gold frame.
  bool get isLandmark => kind == NodeKind.level && level == chapter.levels;
}

enum NodeStatus { locked, current, completed }

abstract final class JourneyCatalog {
  static const levelsPerChapter = 3;

  static const chapters = <ChapterMeta>[
    ChapterMeta(id: 'constitution', icon: Icons.account_balance_rounded, color: Color(0xFF3B4BB0), levels: levelsPerChapter),
    ChapterMeta(id: 'rights', icon: Icons.front_hand_rounded, color: Color(0xFF0E9F6E), levels: levelsPerChapter),
    ChapterMeta(id: 'criminal', icon: Icons.gavel_rounded, color: Color(0xFFC2410C), levels: levelsPerChapter),
    ChapterMeta(id: 'procedure', icon: Icons.policy_rounded, color: Color(0xFF7C3AED), levels: levelsPerChapter),
    ChapterMeta(id: 'civil', icon: Icons.handshake_rounded, color: Color(0xFF0369A1), levels: levelsPerChapter),
    ChapterMeta(id: 'everyday', icon: Icons.diversity_3_rounded, color: Color(0xFFBE185D), levels: levelsPerChapter),
  ];

  static final List<JourneyNode> nodes = _build();

  static List<JourneyNode> _build() {
    final out = <JourneyNode>[];
    for (var c = 0; c < chapters.length; c++) {
      final ch = chapters[c];
      for (var l = 1; l <= ch.levels; l++) {
        out.add(JourneyNode(
          id: '${ch.id}_$l',
          kind: NodeKind.level,
          chapter: ch,
          chapterIndex: c,
          level: l,
          globalIndex: out.length,
        ));
      }
      out.add(JourneyNode(
        id: '${ch.id}_chest',
        kind: NodeKind.chest,
        chapter: ch,
        chapterIndex: c,
        level: 0,
        globalIndex: out.length,
      ));
    }
    return out;
  }

  static JourneyNode? byId(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  static ChapterMeta chapter(String id) =>
      chapters.firstWhere((c) => c.id == id, orElse: () => chapters.first);
}
