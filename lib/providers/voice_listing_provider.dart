import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/voice_listing_draft.dart';
import '../services/voice_listing_service.dart';

enum VoiceListingStatus {
  idle,
  recording,
  processing,
  ready,
  failed,
}

class VoiceListingState {
  final VoiceListingStatus status;
  final VoiceListingDraft? draft;
  final String? errorMessage;
  final int recordSeconds;

  const VoiceListingState({
    this.status = VoiceListingStatus.idle,
    this.draft,
    this.errorMessage,
    this.recordSeconds = 0,
  });

  bool get isRecording => status == VoiceListingStatus.recording;
  bool get isProcessing => status == VoiceListingStatus.processing;

  VoiceListingState copyWith({
    VoiceListingStatus? status,
    VoiceListingDraft? draft,
    String? errorMessage,
    int? recordSeconds,
  }) {
    return VoiceListingState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      errorMessage: errorMessage ?? this.errorMessage,
      recordSeconds: recordSeconds ?? this.recordSeconds,
    );
  }
}

class VoiceListingNotifier extends StateNotifier<VoiceListingState> {
  final VoiceListingService _service;
  Timer? _recordTimer;
  String? _currentAudioPath;
  List<CategoryModel> _activeCategories = const [];

  VoiceListingNotifier(this._service) : super(const VoiceListingState());

  static const int maxRecordSeconds = 30;

  Future<bool> startRecording(List<CategoryModel> categories) async {
    if (state.isRecording || state.isProcessing) return false;

    _activeCategories = categories;
    final hasPerm = await _service.checkPermission();
    if (!hasPerm) {
      state = state.copyWith(
        status: VoiceListingStatus.failed,
        errorMessage:
            'Microphone permission is needed to record your listing. You can type instead.',
      );
      return false;
    }

    try {
      final tempPath =
          '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      _currentAudioPath = tempPath;
      await _service.startRecording(tempPath);

      state = state.copyWith(
        status: VoiceListingStatus.recording,
        recordSeconds: 0,
        errorMessage: null,
      );

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final next = state.recordSeconds + 1;
        if (next >= maxRecordSeconds) {
          timer.cancel();
          stopAndProcess(_activeCategories);
        } else {
          state = state.copyWith(recordSeconds: next);
        }
      });
      return true;
    } catch (_) {
      state = state.copyWith(
        status: VoiceListingStatus.failed,
        errorMessage: 'Could not start recording. You can type instead.',
      );
      return false;
    }
  }

  Future<void> stopAndProcess([List<CategoryModel>? categories]) async {
    _recordTimer?.cancel();
    _recordTimer = null;

    final targetCats = categories ?? _activeCategories;
    final path = _currentAudioPath;
    _currentAudioPath = null;

    state = state.copyWith(status: VoiceListingStatus.processing);

    await _service.stopRecording();

    if (path == null) {
      state = state.copyWith(
        status: VoiceListingStatus.failed,
        errorMessage: 'Recording failed. You can type instead.',
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      state = state.copyWith(
        status: VoiceListingStatus.failed,
        errorMessage: 'Audio file not found. You can type instead.',
      );
      return;
    }

    final result = await _service.processAudio(file, targetCats);
    switch (result) {
      case VoiceListingSuccess(:final draft):
        state = state.copyWith(
          status: VoiceListingStatus.ready,
          draft: draft,
          errorMessage: null,
        );
      case VoiceListingFailure(:final message):
        state = state.copyWith(
          status: VoiceListingStatus.failed,
          errorMessage: message,
        );
    }
  }

  Future<void> cancel() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    await _service.cancelRecording();

    final path = _currentAudioPath;
    if (path != null) {
      _currentAudioPath = null;
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    state = const VoiceListingState();
  }

  Future<void> submitText(
      String text, List<CategoryModel> categories) async {
    if (state.isProcessing) return;

    state = state.copyWith(status: VoiceListingStatus.processing);

    final result = await _service.processText(text, categories);
    switch (result) {
      case VoiceListingSuccess(:final draft):
        state = state.copyWith(
          status: VoiceListingStatus.ready,
          draft: draft,
          errorMessage: null,
        );
      case VoiceListingFailure(:final message):
        state = state.copyWith(
          status: VoiceListingStatus.failed,
          errorMessage: message,
        );
    }
  }

  void reset() {
    _recordTimer?.cancel();
    _recordTimer = null;
    state = const VoiceListingState();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final voiceListingServiceProvider = Provider<VoiceListingService>((ref) {
  final service = VoiceListingService();
  ref.onDispose(service.dispose);
  return service;
});

final voiceListingProvider =
    StateNotifierProvider.autoDispose<VoiceListingNotifier, VoiceListingState>(
        (ref) {
  return VoiceListingNotifier(ref.watch(voiceListingServiceProvider));
});
