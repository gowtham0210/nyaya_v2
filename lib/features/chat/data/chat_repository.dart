import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../profile/domain/user_profile.dart';
import '../domain/chat_message.dart';

/// Build-time AI configuration:
///
///   flutter run --dart-define=NYAYA_AI_BASE_URL=https://your-proxy.example.com \
///               --dart-define=NYAYA_AI_KEY=...
///
/// Production builds should point NYAYA_AI_BASE_URL at your own backend proxy
/// that holds the Anthropic key server-side — never ship a raw API key in a
/// mobile binary. With no key configured the app uses [OfflineChatRepository].
abstract final class AiConfig {
  static const baseUrl = String.fromEnvironment('NYAYA_AI_BASE_URL', defaultValue: 'https://api.anthropic.com');
  static const apiKey = String.fromEnvironment('NYAYA_AI_KEY');
  static const model = String.fromEnvironment('NYAYA_AI_MODEL', defaultValue: 'claude-opus-5-5');

  static bool get isConfigured => apiKey.isNotEmpty;
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (AiConfig.isConfigured) {
    final client = http.Client();
    ref.onDispose(client.close);
    return ClaudeChatRepository(client: client);
  }
  return const OfflineChatRepository();
});

abstract interface class ChatRepository {
  bool get isOnline;

  Future<AssistantReply> reply({
    required List<ChatMessage> history,
    required AppLanguage language,
    required Persona persona,
  });
}

String nyayaSystemPrompt(AppLanguage language, Persona persona) {
  final audience = switch (persona) {
    Persona.advocate =>
      'The user is a practising advocate: be precise, cite sections, landmark judgments and procedure.',
    Persona.aspirant =>
      'The user is a law aspirant (CLAT/AIBE/judiciary): explain clearly, cite sections and add a one-line exam tip when useful.',
    Persona.citizen =>
      'The user is a common citizen: use very simple everyday language, avoid jargon, and focus on practical next steps.',
  };
  return '''
You are Nyaya AI, a legal information assistant inside the Nyaya app, focused on the law of India.

$audience

How to answer:
- Reply in ${language.englishName}${language == AppLanguage.en ? '' : ' (${language.nativeName})'}. Keep statute names, section numbers and case names accurate; you may add the English term in brackets.
- Criminal law changed on 1 July 2024: the Bharatiya Nyaya Sanhita (BNS), Bharatiya Nagarik Suraksha Sanhita (BNSS) and Bharatiya Sakshya Adhiniyam (BSA) replaced the IPC, CrPC and Indian Evidence Act for offences after that date. Cite the new sections, and mention the old IPC/CrPC equivalent when it helps.
- Be concise for a phone screen: a short direct answer first, then up to 5 short bullet points starting with "• ". Plain text only — no markdown headings or tables; **bold** is fine for key terms.
- If you are not sure of a section number or a recent change, say so rather than guessing.
- You give general legal information, not legal advice. For a specific case, suggest consulting an advocate or the free legal aid helpline 15100 (NALSA). In an emergency, tell the user to call 112.
- Politely decline requests to evade the law, harm others or fabricate documents, and offer a lawful alternative.
- For questions unrelated to law, briefly steer back to legal topics.
''';
}

/// Claude Messages API over HTTP (Dart has no official Anthropic SDK).
class ClaudeChatRepository implements ChatRepository {
  ClaudeChatRepository({required this._client});

  final http.Client _client;

  @override
  bool get isOnline => true;

  @override
  Future<AssistantReply> reply({
    required List<ChatMessage> history,
    required AppLanguage language,
    required Persona persona,
  }) async {
    final messages = [
      for (final m in history.where((m) => !m.isError))
        {
          'role': m.role == ChatRole.user ? 'user' : 'assistant',
          'content': m.role == ChatRole.assistant && m.rawContent != null ? m.rawContent : m.text,
        },
    ];

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('${AiConfig.baseUrl}/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': AiConfig.apiKey,
              'anthropic-version': '2023-06-01',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode({
              'model': AiConfig.model,
              // Answers are deliberately short for a phone screen.
              'max_tokens': 4096,
              'system': nyayaSystemPrompt(language, persona),
              'output_config': {'effort': 'medium'},
              // Re-runs a classifier-declined request on a suitable model.
              'fallbacks': 'default',
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const ChatException('timeout');
    } on http.ClientException catch (e) {
      throw ChatException(e.message);
    }

    if (res.statusCode != 200) throw ChatException('HTTP ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = body['content'] as List<dynamic>? ?? const [];

    if (body['stop_reason'] == 'refusal') {
      return const AssistantReply(
        text: 'I can\'t help with that request. I can explain the relevant law, your rights, or how to get free legal aid (call 15100).',
      );
    }

    final text = content
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n')
        .trim();
    if (text.isEmpty) throw const ChatException('empty');
    return AssistantReply(text: text, rawContent: content);
  }
}

/// Works with no network or key: matches common questions to vetted short
/// answers so the tab is never a dead end.
class OfflineChatRepository implements ChatRepository {
  const OfflineChatRepository();

  @override
  bool get isOnline => false;

  static const _answers = <List<String>, String>{
    ['zero fir', 'zero-fir', 'e-fir', 'efir', 'fir']:
        'A **Zero FIR** lets you report a cognizable offence at ANY police station, no matter where the crime happened. The station must register it and transfer it to the station with jurisdiction.\n'
            '• Recognised in **Section 173(1), BNSS 2023**.\n'
            '• You can also give information electronically (e-FIR); sign it within 3 days.\n'
            '• You are entitled to a free copy of the FIR.\n'
            '• If police refuse, you can approach the Superintendent of Police (Section 173(4)) or a Magistrate.',
    ['arrest', 'arrested', 'custody', 'detained']:
        'If you are arrested, you have important rights:\n'
            '• To be told the grounds of arrest (Article 22(1); Section 47, BNSS).\n'
            '• To have a relative or friend informed (Section 48, BNSS).\n'
            '• To meet an advocate of your choice during interrogation (Section 38, BNSS).\n'
            '• To be produced before a Magistrate within 24 hours (Article 22(2); Section 58, BNSS).\n'
            '• To free legal aid — call **15100**.',
    ['rti', 'right to information']:
        'Under the **RTI Act, 2005** any citizen can request information from a public authority.\n'
            '• Write to the Public Information Officer (PIO) or file online at rtionline.gov.in for Central bodies.\n'
            '• Fee is ₹10 (exempt for BPL applicants).\n'
            '• Reply is due within 30 days (48 hours if life or liberty is involved).\n'
            '• If unhappy, file a first appeal within 30 days.',
    ['consumer', 'refund', 'defective', 'complaint']:
        'You can file a consumer complaint under the **Consumer Protection Act, 2019**.\n'
            '• District Commission: claims up to ₹50 lakh; State: ₹50 lakh–₹2 crore; National: above ₹2 crore.\n'
            '• File online on the e-Daakhil portal; you can file where you live or work.\n'
            '• Limitation: generally within 2 years of the cause of action.\n'
            '• Try the National Consumer Helpline 1915 first for quick mediation.',
    ['bail']:
        '**Bail** depends on whether the offence is bailable.\n'
            '• Bailable offences: bail is a right (Section 478, BNSS).\n'
            '• Non-bailable: the court decides (Sections 480 and 483, BNSS).\n'
            '• Anticipatory bail can be sought before arrest (Section 482, BNSS).\n'
            'Consult an advocate or call 15100 for free legal aid.',
    ['legal aid', 'free lawyer', 'nalsa', 'lawyer']:
        'Free legal aid is available under the **Legal Services Authorities Act, 1987** (Section 12) for women, children, SC/ST members, persons in custody, persons with disabilities, disaster victims and low-income people.\n'
            '• Visit your District Legal Services Authority.\n'
            '• Call the NALSA helpline **15100**.',
    ['cyber', 'fraud', 'scam', 'upi', 'online']:
        'For cyber fraud, act fast:\n'
            '• Call **1930** (National Cyber Crime Helpline) immediately to try to freeze the money.\n'
            '• Report at **cybercrime.gov.in**.\n'
            '• Tell your bank and keep screenshots, transaction IDs and numbers.\n'
            '• Cheating is punishable under Section 318, BNS; identity theft under Section 66C, IT Act.',
  };

  @override
  Future<AssistantReply> reply({
    required List<ChatMessage> history,
    required AppLanguage language,
    required Persona persona,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final q = history.lastWhere((m) => m.role == ChatRole.user).text.toLowerCase();
    for (final e in _answers.entries) {
      if (e.key.any(q.contains)) return AssistantReply(text: e.value, offline: true);
    }
    return const AssistantReply(
      offline: true,
      text: 'I\'m running in offline mode, so I can answer only common topics right now — try asking about a Zero FIR, '
          'your rights on arrest, RTI, consumer complaints, bail, cyber fraud or free legal aid.\n'
          '• For personal legal help, call the free NALSA helpline **15100**.',
    );
  }
}
