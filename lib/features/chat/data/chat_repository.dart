import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => BackendChatRepository(ref.watch(apiClientProvider)),
);

abstract interface class ChatRepository {
  bool get isOnline;

  Future<AssistantReply> reply({
    required List<ChatMessage> history,
    required AppLanguage language,
    required Persona persona,
  });
}

/// Ask AI through the Nyaya API (`POST /v1/chat`), which holds the model key
/// and the instructions. When the server can't be reached, or has no AI
/// configured, falls back to [OfflineChatRepository] so the tab still helps.
class BackendChatRepository implements ChatRepository {
  BackendChatRepository(this._api, {this.offline = const OfflineChatRepository()});

  final ApiClient _api;
  final ChatRepository offline;

  /// The server keeps at most this many turns of history.
  static const maxTurns = 20;

  @override
  bool get isOnline => true;

  @override
  Future<AssistantReply> reply({
    required List<ChatMessage> history,
    required AppLanguage language,
    required Persona persona,
  }) async {
    final turns = history.where((m) => !m.isError && m.text.isNotEmpty).toList();
    final recent = turns.length > maxTurns ? turns.sublist(turns.length - maxTurns) : turns;
    try {
      final res = await _api.post('/v1/chat', body: {
        'messages': [
          for (final m in recent) {'role': m.role.name, 'content': m.text},
        ],
        'language': language.code,
        'persona': persona.name,
      }) as Map<String, dynamic>;
      return AssistantReply(text: res['reply'] as String);
    } on ApiException catch (e) {
      if (e.isNetwork || e.code == 'chat_unavailable') {
        return offline.reply(history: history, language: language, persona: persona);
      }
      if (e.code == 'chat_limit_reached') throw const ChatLimitException();
      throw ChatException(e.code);
    }
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
