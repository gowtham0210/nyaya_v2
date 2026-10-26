import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';
import '../../profile/application/profile_controller.dart';
import '../application/chat_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialPrompt});

  /// Prefilled (not auto-sent) — e.g. from "Ask AI about this".
  final String? initialPrompt;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _showDisclaimer = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) _input.text = widget.initialPrompt!;
  }

  @override
  void didUpdateWidget(ChatScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialPrompt != null && widget.initialPrompt != old.initialPrompt) {
      _input.text = widget.initialPrompt!;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final msg = text ?? _input.text;
    if (msg.trim().isEmpty) return;
    ref.read(feedbackProvider).play(Haptic.tap);
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(msg);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chat = ref.watch(chatControllerProvider);
    final profile = ref.watch(profileProvider);
    final left = ref.read(profileProvider.notifier).aiMessagesLeft;
    final online = ref.watch(chatRepositoryProvider).isOnline;
    ref.listen(chatControllerProvider.select((s) => s.messages.length), (_, _) => _scrollToEnd());

    final items = chat.messages.reversed.toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, 8, AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.nyaya.hero,
                    ),
                    child: const Icon(Icons.balance_rounded, color: AppPalette.ochre),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.chatTitle, style: context.text.titleLarge),
                        Text(
                          online ? l.chatSubtitle : l.chatOfflineNote,
                          style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (chat.messages.isNotEmpty)
                    IconButton(
                      tooltip: l.chatClear,
                      onPressed: ref.read(chatControllerProvider.notifier).clear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                ],
              ),
            ),
            if (_showDisclaimer)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                decoration: BoxDecoration(
                  color: context.colors.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppPalette.ochreText),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.chatDisclaimer, style: context.text.bodySmall)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l.commonClose,
                      onPressed: () => setState(() => _showDisclaimer = false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),

            // ── Messages ────────────────────────────────────────────────────
            Expanded(
              child: chat.messages.isEmpty
                  ? _Welcome(onSuggestion: _send)
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
                      itemCount: items.length + (chat.sending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (chat.sending && i == 0) return const _TypingBubble();
                        final m = items[i - (chat.sending ? 1 : 0)];
                        return _Bubble(
                          message: m,
                          onRetry: ref.read(chatControllerProvider.notifier).retry,
                        );
                      },
                    ),
            ),

            // ── Quota / limit ───────────────────────────────────────────────
            if (!profile.isPremium)
              if (left <= 0 || chat.limitReached)
                _LimitBanner(onUpgrade: () => context.push(Routes.premium))
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    l.chatLimitLeft(left),
                    style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary),
                  ),
                ),

            // ── Composer ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, 8, 8),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.nyaya.cardBorder)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l.chatHint,
                        counterText: '',
                        fillColor: context.colors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _input,
                    builder: (context, _) {
                      final enabled = _input.text.trim().isNotEmpty && !chat.sending;
                      return IconButton.filled(
                        tooltip: l.commonNext,
                        onPressed: enabled ? _send : null,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          backgroundColor: context.colors.primary,
                        ),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final suggestions = [
      (Icons.local_police_rounded, l.chatSuggest1),
      (Icons.gavel_rounded, l.chatSuggest2),
      (Icons.description_rounded, l.chatSuggest3),
      (Icons.shopping_bag_rounded, l.chatSuggest4),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.nyaya.hero,
              boxShadow: [BoxShadow(color: AppPalette.terracotta.withValues(alpha: 0.25), blurRadius: 24)],
            ),
            child: const Icon(Icons.auto_awesome, color: AppPalette.ochre, size: 40),
          ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.chatWelcome,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(height: 1.5),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: AppSpacing.lg),
        for (final (i, (icon, text)) in suggestions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              onTap: () => onSuggestion(text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: context.nyaya.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: context.colors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: context.text.titleSmall)),
                    Icon(Icons.north_east_rounded, size: 18, color: context.nyaya.textSecondary),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (200 + 60 * i).ms).slideY(begin: 0.2),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onRetry});

  final ChatMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isUser = message.role == ChatRole.user;

    if (message.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 40),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.nyaya.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.chatError, style: context.text.bodyMedium),
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(l.commonRetry)),
            ],
          ),
        ),
      );
    }

    final bg = isUser ? context.colors.primary : context.colors.surface;
    final fg = isUser ? context.colors.onPrimary : context.colors.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatCopy)));
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: isUser ? null : Border.all(color: context.nyaya.cardBorder),
          ),
          child: Text.rich(
            _richText(message.text, context.text.bodyMedium!.copyWith(color: fg, height: 1.5)),
          ),
        ),
      ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.1),
    );
  }

  /// Minimal **bold** support — the system prompt keeps answers plain text.
  static TextSpan _richText(String text, TextStyle style) {
    final parts = text.split('**');
    return TextSpan(
      style: style,
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.nyaya.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(begin: 0, end: -5, delay: (150 * i).ms, duration: 300.ms)
                  .then()
                  .moveY(begin: -5, end: 0, duration: 300.ms),
            const SizedBox(width: 10),
            Text(context.l10n.chatThinking, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _LimitBanner extends StatelessWidget {
  const _LimitBanner({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppPalette.sand,
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: AppPalette.deepEarth),
          const SizedBox(width: 10),
          Expanded(child: Text(l.chatLimitReached, style: context.text.bodySmall?.copyWith(color: AppPalette.deepEarth))),
          TextButton(
            onPressed: onUpgrade,
            style: TextButton.styleFrom(foregroundColor: AppPalette.deepEarth),
            child: Text(l.settingsPremiumUpgrade),
          ),
        ],
      ),
    );
  }
}
