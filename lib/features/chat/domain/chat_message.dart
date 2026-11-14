import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant }

/// An official page (Supreme Court of India, India Code) an answer relied on.
@immutable
class ChatSource {
  const ChatSource({required this.site, required this.title, required this.url});

  final String site;
  final String title;
  final String url;

  Map<String, dynamic> toJson() => {'site': site, 'title': title, 'url': url};

  /// Null when the entry has no usable https link, so it is never shown.
  static ChatSource? tryParse(Object? j) {
    if (j is! Map) return null;
    final site = j['site'];
    final title = j['title'];
    final url = j['url'];
    if (site is! String || title is! String || url is! String) return null;
    final link = Uri.tryParse(url);
    if (link == null || !link.isScheme('https') || link.host.isEmpty) return null;
    return ChatSource(site: site, title: title, url: url);
  }

  static List<ChatSource> parseAll(Object? list) =>
      list is List ? [for (final e in list) ?tryParse(e)] : const [];
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.at,
    this.isError = false,
    this.sources = const [],
  });

  final ChatRole role;
  final String text;
  final DateTime at;
  final bool isError;
  final List<ChatSource> sources;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        if (isError) 'error': true,
        if (sources.isNotEmpty) 'sources': [for (final s in sources) s.toJson()],
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: ChatRole.values.asNameMap()[j['role']] ?? ChatRole.user,
        text: j['text'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        isError: j['error'] == true,
        sources: ChatSource.parseAll(j['sources']),
      );
}

/// Result of one assistant turn.
@immutable
class AssistantReply {
  const AssistantReply({required this.text, this.offline = false, this.sources = const []});

  final String text;
  final bool offline;
  final List<ChatSource> sources;
}

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;

  @override
  String toString() => 'ChatException: $message';
}

/// The server's daily AI answer limit is used up.
class ChatLimitException implements Exception {
  const ChatLimitException();
}
