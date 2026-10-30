import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/catalog_providers.dart';
import '../../providers/voice_listing_provider.dart';
import '../../widgets/panel_ui.dart';
import 'voice_listing_confirm_screen.dart';

Future<bool?> showVoiceListingSheet(BuildContext context, String farmerId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoiceListingModal(farmerId: farmerId),
  );
}

class _VoiceListingModal extends ConsumerStatefulWidget {
  final String farmerId;

  const _VoiceListingModal({required this.farmerId});

  @override
  ConsumerState<_VoiceListingModal> createState() => _VoiceListingModalState();
}

class _VoiceListingModalState extends ConsumerState<_VoiceListingModal> {
  final _typeController = TextEditingController();
  bool _isTypingMode = false;

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  void _onStateChanged(VoiceListingState? prev, VoiceListingState next) {
    if (next.status == VoiceListingStatus.ready && next.draft != null) {
      final draft = next.draft!;
      ref.read(voiceListingProvider.notifier).reset();
      Navigator.of(context).pop(false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VoiceListingConfirmScreen(
          farmerId: widget.farmerId,
          initialDraft: draft,
        ),
      ));
    }
  }

  Future<void> _startRecording() async {
    final categories = ref.read(activeCategoriesProvider).valueOrNull ?? [];
    final notifier = ref.read(voiceListingProvider.notifier);
    await notifier.startRecording(categories);
  }

  Future<void> _stopRecording() async {
    final categories = ref.read(activeCategoriesProvider).valueOrNull ?? [];
    final notifier = ref.read(voiceListingProvider.notifier);
    await notifier.stopAndProcess(categories);
  }

  Future<void> _cancelRecording() async {
    final notifier = ref.read(voiceListingProvider.notifier);
    await notifier.cancel();
  }

  Future<void> _submitTypedText() async {
    final text = _typeController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final categories = ref.read(activeCategoriesProvider).valueOrNull ?? [];
    final notifier = ref.read(voiceListingProvider.notifier);
    await notifier.submitText(text, categories);
  }

  void _openManualForm() {
    ref.read(voiceListingProvider.notifier).reset();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceListingState>(voiceListingProvider, _onStateChanged);
    final state = ref.watch(voiceListingProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.mic_none_rounded,
                    color: PanelColors.brand, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Awaaz se Dukaan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PanelColors.textMain,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: PanelColors.textMuted),
                  onPressed: state.isProcessing ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Speak product details in Urdu, Punjabi, Roman Urdu or English.',
              style: TextStyle(fontSize: 13, color: PanelColors.textMuted),
            ),
            const SizedBox(height: 20),
            if (_isTypingMode)
              _buildTypeMode(state)
            else
              _buildVoiceMode(state),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMode(VoiceListingState state) {
    final recordSecs = state.recordSeconds;
    final timerString =
        '00:${recordSecs.toString().padLeft(2, '0')} / 00:${VoiceListingNotifier.maxRecordSeconds}';

    if (state.isProcessing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: PanelColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Extracting product details...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PanelColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Waiting for Gemini (max 12s)',
              style: TextStyle(fontSize: 12, color: PanelColors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _cancelRecording,
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PanelColors.dangerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: PanelColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                        fontSize: 13, color: PanelColors.danger),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (state.isRecording) ...[
          Text(
            timerString,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: PanelColors.brand,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Listening... Tap stop when finished',
            style: TextStyle(fontSize: 13, color: PanelColors.textMuted),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _cancelRecording,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _stopRecording,
                style:
                    FilledButton.styleFrom(backgroundColor: PanelColors.brand),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop & Extract'),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PanelColors.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    color: PanelColors.brand, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Example: "5 kilo tamatar, 80 rupay kilo"',
                    style: TextStyle(
                        fontSize: 13,
                        color: PanelColors.brand,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PanelColors.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PanelColors.brand.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap mic to start speaking',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PanelColors.textMain),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _isTypingMode = true),
                icon: const Icon(Icons.keyboard_outlined, size: 18),
                label: const Text('Type instead'),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _openManualForm,
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Manual form'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTypeMode(VoiceListingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PanelColors.dangerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(fontSize: 13, color: PanelColors.danger),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _typeController,
          enabled: !state.isProcessing,
          textCapitalization: TextCapitalization.sentences,
          decoration: panelInputDecoration(
            'Product details',
            hint: 'e.g. 5 kilo tamatar 80 rupees kilo',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: state.isProcessing ? null : _submitTypedText,
          style: FilledButton.styleFrom(backgroundColor: PanelColors.brand),
          child: state.isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Extract with AI',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: state.isProcessing
                  ? null
                  : () => setState(() => _isTypingMode = false),
              icon: const Icon(Icons.mic_outlined, size: 18),
              label: const Text('Use Voice'),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: state.isProcessing ? null : _openManualForm,
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text('Manual form'),
            ),
          ],
        ),
      ],
    );
  }
}
