import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message_model.dart';
import '../services/ai_assistant_service.dart';
import 'service_providers.dart';

class AssistantState {
  final bool sending;
  final String? fallbackAnswer;

  const AssistantState({this.sending = false, this.fallbackAnswer});
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AiAssistantService _service;
  DateTime? _lastSentAt;

  AssistantNotifier(this._service) : super(const AssistantState());

  Future<void> send(String text, {VoidCallback? onAccepted}) async {
    if (text.isEmpty || state.sending) return;

    final now = DateTime.now();
    final lastSentAt = _lastSentAt;
    if (lastSentAt != null &&
        now.difference(lastSentAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastSentAt = now;

    state = AssistantState(sending: true, fallbackAnswer: state.fallbackAnswer);
    onAccepted?.call();

    try {
      final result = await _service.sendMessage(text);
      if (!mounted) return;
      state = AssistantState(
          fallbackAnswer: result.isFallback ? result.answer : null);
    } catch (_) {
      if (!mounted) return;
      state = const AssistantState(
          fallbackAnswer:
              'Your message could not be sent. Check your connection and try again.');
    }
  }

  Future<void> clearChat() async {
    if (state.sending) return;
    await _service.clearSession();
    if (!mounted) return;
    state = const AssistantState();
  }
}

final assistantProvider =
    StateNotifierProvider.autoDispose<AssistantNotifier, AssistantState>((ref) {
  return AssistantNotifier(ref.watch(aiAssistantServiceProvider));
});

final assistantMessagesProvider =
    StreamProvider.autoDispose<List<ChatMessageModel>>((ref) {
  return ref.watch(aiAssistantServiceProvider).watchSession();
});