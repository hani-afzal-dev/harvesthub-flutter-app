import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../models/chat_message_model.dart';
import '../../../providers/assistant_providers.dart';
import '../../../widgets/animated_chat_launcher.dart';
import '../../../widgets/async_error_view.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _border = Color(0xFFE3E9DA);
const Color _pageBg = Color(0xFFF6F8F3);

const List<String> _suggestions = [
  'Which fruits are rich in Vitamin C?',
  'How should tomatoes be stored?',
  'Which vegetables are in season now?',
  'Health benefits of spinach',
  'Vegetables for a healthy salad',
];

class AiAssistantPanel extends ConsumerStatefulWidget {
  const AiAssistantPanel({super.key});

  @override
  ConsumerState<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends ConsumerState<AiAssistantPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    HapticFeedback.lightImpact();
    _scrollToBottom();
    await ref
        .read(assistantProvider.notifier)
        .send(message, onAccepted: _controller.clear);
    if (!mounted) return;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
            'All messages will be deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(assistantProvider.notifier).clearChat();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear chat. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(assistantMessagesProvider);
    final assistant = ref.watch(assistantProvider);

    Widget body;
    if (messagesAsync.hasError && !messagesAsync.hasValue) {
      body = AsyncErrorView(
        compact: true,
        title: 'Chat did not load',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(assistantMessagesProvider),
      );
    } else if (!messagesAsync.hasValue) {
      body = const Center(child: AnimatedThinkingLoader(size: 30));
    } else {
      final messages = messagesAsync.value!;
      if (messages.isEmpty && !assistant.sending) {
        body = _WelcomeView(
          onAsk: assistant.sending ? null : _send,
        );
      } else {
        _scrollToBottom();
        body = LayoutBuilder(
          builder: (context, constraints) {
            final maxBubble = constraints.maxWidth * 0.78;
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              itemCount: messages.length + (assistant.sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == messages.length) return const _TypingRow();
                final message = messages[i];
                final isFallback = message.role == ChatRole.assistant &&
                    message.content == assistant.fallbackAnswer;
                return _MessageBubble(
                  message: message,
                  maxWidth: maxBubble,
                  isFallback: isFallback,
                );
              },
            );
          },
        );
      }
    }

    final canSend = _hasText && !assistant.sending;

    return ColoredBox(
      color: _pageBg,
      child: Column(
        children: [
          _Header(
            onClear: assistant.sending ||
                    !(messagesAsync.valueOrNull?.isNotEmpty ?? false)
                ? null
                : _confirmClear,
          ),
          Expanded(child: body),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('assistant_input'),
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: canSend ? _send : null,
                    style: const TextStyle(fontSize: 14, color: _textMain),
                    decoration: InputDecoration(
                      hintText: 'Ask about produce...',
                      hintStyle:
                          const TextStyle(fontSize: 14, color: _textMuted),
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: _pageBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: _brand, width: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  enabled: canSend,
                  label: 'Send message',
                  child: Tooltip(
                    message: 'Send',
                    child: InkResponse(
                      key: const ValueKey('assistant_send_button'),
                      onTap: canSend ? () => _send(_controller.text) : null,
                      radius: 24,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: canSend ? _brand : const Color(0xFFDDE3D5),
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 22,
                          color:
                              canSend ? Colors.white : const Color(0xFF8A9380),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final VoidCallback? onClear;

  const _Header({this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F8A1A), _brand, _brandDark],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'HarvestHub Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('AI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: online
                              ? const Color(0xFFB5E07A)
                              : const Color(0xFFF3CF8C),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        online
                            ? 'Online · replies in a few seconds'
                            : 'Offline · basic answers only',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClear != null)
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (_) => onClear!(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear', child: Text('Clear chat')),
              ],
            ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: const Icon(Icons.smart_toy_outlined, size: 16, color: _brand),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  final ValueChanged<String>? onAsk;

  const _WelcomeView({required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final ask = onAsk;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AssistantAvatar(),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  "Hi, I'm the HarvestHub assistant. Ask me about fruits, "
                  'vegetables, nutrition or how to store fresh produce.',
                  style:
                      TextStyle(fontSize: 14, height: 1.45, color: _textMain),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'TRY ASKING',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: _textMuted),
          ),
        ),
        for (final question in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: ask == null ? null : () => ask(question),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textMain),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.north_east_rounded,
                          size: 16, color: _brand),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'AI answers can be wrong. Check with a doctor for health advice.',
                style: TextStyle(fontSize: 11, height: 1.4, color: _textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Assistant is typing',
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _AssistantAvatar(),
            SizedBox(width: 8),
            AnimatedThinkingLoader(size: 26),
            SizedBox(width: 8),
            Flexible(
              child: Text('Thinking...',
                  style: TextStyle(fontSize: 12, color: _textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final double maxWidth;
  final bool isFallback;

  const _MessageBubble({
    required this.message,
    required this.maxWidth,
    required this.isFallback,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: isUser ? _brand : Colors.white,
        border: isUser ? null : Border.all(color: _border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 16 : 4),
          topRight: Radius.circular(isUser ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            message.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: isUser ? Colors.white : _textMain,
            ),
          ),
          if (isFallback) ...[
            const SizedBox(height: 6),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 12, color: _textMuted),
                SizedBox(width: 4),
                Flexible(
                  child: Text('Offline answer',
                      style: TextStyle(fontSize: 11, color: _textMuted)),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}