import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.at,
    this.rawContent,
    this.isError = false,
  });

  final ChatRole role;
  final String text;
  final DateTime at;

  /// The provider's raw assistant content blocks, re-sent unchanged on the
  /// next turn so the conversation history stays append-only.
  final List<dynamic>? rawContent;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        if (rawContent != null) 'raw': rawContent,
        if (isError) 'error': true,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: ChatRole.values.asNameMap()[j['role']] ?? ChatRole.user,
        text: j['text'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        rawContent: j['raw'] as List<dynamic>?,
        isError: j['error'] == true,
      );
}

/// Result of one assistant turn.
@immutable
class AssistantReply {
  const AssistantReply({required this.text, this.rawContent, this.offline = false});

  final String text;
  final List<dynamic>? rawContent;
  final bool offline;
}

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;

  @override
  String toString() => 'ChatException: $message';
}
