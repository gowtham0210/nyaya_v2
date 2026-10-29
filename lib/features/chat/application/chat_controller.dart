import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../profile/application/profile_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

@immutable
class ChatState {
  const ChatState({this.messages = const [], this.sending = false, this.limitReached = false});

  final List<ChatMessage> messages;
  final bool sending;
  final bool limitReached;

  ChatState copyWith({List<ChatMessage>? messages, bool? sending, bool? limitReached}) => ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        limitReached: limitReached ?? this.limitReached,
      );
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  static const _key = 'chat_v1';
  static const _maxStored = 40;

  @override
  ChatState build() {
    final raw = ref.watch(localStoreProvider).readJsonList(_key) ?? const [];
    return ChatState(
      messages: [for (final m in raw) ChatMessage.fromJson(m as Map<String, dynamic>)],
    );
  }

  void _persist(List<ChatMessage> messages) {
    final keep = messages.where((m) => !m.isError).toList();
    final trimmed = keep.length > _maxStored ? keep.sublist(keep.length - _maxStored) : keep;
    ref.read(localStoreProvider).writeJson(_key, [for (final m in trimmed) m.toJson()]);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final profileCtl = ref.read(profileProvider.notifier);
    if (profileCtl.aiMessagesLeft <= 0) {
      state = state.copyWith(limitReached: true);
      return;
    }

    final now = ref.read(clockProvider)();
    // Drop a previous failed turn so history alternates user/assistant.
    final base = [...state.messages];
    if (base.isNotEmpty && base.last.isError) base.removeLast();
    if (base.isNotEmpty && base.last.role == ChatRole.user) base.removeLast();

    final history = [...base, ChatMessage(role: ChatRole.user, text: trimmed, at: now)];
    state = state.copyWith(messages: history, sending: true, limitReached: false);

    final profile = ref.read(profileProvider);
    try {
      final reply = await ref.read(chatRepositoryProvider).reply(
            history: history,
            language: profile.language,
            persona: profile.persona,
          );
      // Only successful answers count against the free quota.
      profileCtl.consumeAiMessage();
      final updated = [
        ...history,
        ChatMessage(
          role: ChatRole.assistant,
          text: reply.text,
          at: ref.read(clockProvider)(),
        ),
      ];
      state = state.copyWith(messages: updated, sending: false);
      _persist(updated);
    } on ChatLimitException {
      // Put the conversation back as it was; the limit banner explains why.
      state = state.copyWith(messages: base, sending: false, limitReached: true);
    } catch (_) {
      state = state.copyWith(
        messages: [
          ...history,
          ChatMessage(role: ChatRole.assistant, text: '', at: ref.read(clockProvider)(), isError: true),
        ],
        sending: false,
      );
    }
  }

  /// Re-sends the last user message after a failure.
  Future<void> retry() async {
    final lastUser = state.messages.lastWhere((m) => m.role == ChatRole.user, orElse: () => ChatMessage(role: ChatRole.user, text: '', at: DateTime.now()));
    if (lastUser.text.isEmpty) return;
    await send(lastUser.text);
  }

  void clear() {
    state = const ChatState();
    ref.read(localStoreProvider).remove(_key);
  }
}
