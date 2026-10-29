import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/features/chat/data/chat_repository.dart';
import 'package:nyaya/features/chat/domain/chat_message.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';

import 'support/fake_backend.dart';

void main() {
  final at = DateTime(2026, 10, 29);
  final history = [
    ChatMessage(role: ChatRole.user, text: 'What is a Zero FIR?', at: at),
    ChatMessage(role: ChatRole.assistant, text: '', at: at, isError: true),
    ChatMessage(role: ChatRole.user, text: 'What is a Zero FIR?', at: at),
  ];

  BackendChatRepository repoWith(Future<http.Response> Function(http.Request) handler) =>
      BackendChatRepository(ApiClient(baseUrl: 'https://api.test', client: MockClient(handler), tokens: signedInTokens()));

  Future<AssistantReply> ask(BackendChatRepository repo) =>
      repo.reply(history: history, language: AppLanguage.ta, persona: Persona.citizen);

  test('asks the API with the history, language and persona', () async {
    late Map<String, dynamic> sent;
    final repo = repoWith((req) async {
      expect(req.url.toString(), 'https://api.test/v1/chat');
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'reply': 'Any station must register it.', 'remaining_today': 49}), 200);
    });
    final reply = await ask(repo);
    expect(reply.text, 'Any station must register it.');
    expect(reply.offline, isFalse);
    expect(sent['language'], 'ta');
    expect(sent['persona'], 'citizen');
    // The failed turn is left out.
    expect(sent['messages'], [
      {'role': 'user', 'content': 'What is a Zero FIR?'},
      {'role': 'user', 'content': 'What is a Zero FIR?'},
    ]);
  });

  test('falls back to offline answers when the server is unreachable or has no AI', () async {
    for (final handler in <Future<http.Response> Function(http.Request)>[
      (_) async => throw http.ClientException('no network'),
      (_) async => http.Response(jsonEncode({'code': 'chat_unavailable', 'message': 'x'}), 503),
    ]) {
      final reply = await ask(repoWith(handler));
      expect(reply.offline, isTrue);
      expect(reply.text, contains('Zero FIR'));
    }
  });

  test('reports the daily limit and other errors', () async {
    final limited = repoWith((_) async => http.Response(jsonEncode({'code': 'chat_limit_reached', 'message': 'x'}), 429));
    await expectLater(ask(limited), throwsA(isA<ChatLimitException>()));
    final failed = repoWith((_) async => http.Response(jsonEncode({'code': 'chat_failed', 'message': 'x'}), 502));
    await expectLater(ask(failed), throwsA(isA<ChatException>()));
  });
}
