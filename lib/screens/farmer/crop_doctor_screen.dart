import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/crop_doctor_provider.dart';
import '../../widgets/page_header.dart';
import '../../widgets/panel_ui.dart';

class CropDoctorScreen extends ConsumerStatefulWidget {
  const CropDoctorScreen({super.key});

  @override
  ConsumerState<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

class _CropDoctorScreenState extends ConsumerState<CropDoctorScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        ref.read(cropDoctorProvider.notifier).setImage(File(picked.path));
      }
    } catch (_) {
      // User cancelled or permission denied: stays on screen without crashing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cropDoctorProvider);
    final notifier = ref.read(cropDoctorProvider.notifier);

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              title: 'Crop Doctor',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _buildLanguageSelector(state, notifier),
                      const SizedBox(height: 14),
                      if (state.selectedImage == null) ...[
                        _buildTipCard(state.romanUrdu),
                        const SizedBox(height: 18),
                        _buildCaptureActions(state),
                      ] else ...[
                        _buildImagePreview(state, notifier),
                        const SizedBox(height: 16),
                        if (state.isProcessing)
                          _buildProcessingCard(state, notifier)
                        else if (state.hasResult && state.diagnosis != null)
                          _buildResultView(state, notifier)
                        else
                          _buildReadyActions(state, notifier),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    CropDoctorState state,
    CropDoctorNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Icon(Icons.language_rounded, size: 16, color: PanelColors.textMuted),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('English'),
          selected: !state.romanUrdu,
          onSelected: state.isProcessing
              ? null
              : (_) => notifier.setLanguage(romanUrdu: false),
          selectedColor: PanelColors.brand,
          backgroundColor: PanelColors.pageBg,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: !state.romanUrdu ? Colors.white : PanelColors.textBody,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Roman Urdu'),
          selected: state.romanUrdu,
          onSelected: state.isProcessing
              ? null
              : (_) => notifier.setLanguage(romanUrdu: true),
          selectedColor: PanelColors.brand,
          backgroundColor: PanelColors.pageBg,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: state.romanUrdu ? Colors.white : PanelColors.textBody,
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard(bool romanUrdu) {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PanelColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.light_mode_outlined,
              color: PanelColors.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  romanUrdu
                      ? 'Tasveer lene ki hidayat'
                      : 'Photography tip',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PanelColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  romanUrdu
                      ? 'Photograph one leaf, in daylight, close up. Saaf aur wazeh tasveer se sahi tajziya hota hai.'
                      : 'Photograph one leaf, in daylight, close up. Good lighting and clear focus give the best diagnosis.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: PanelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureActions(CropDoctorState state) {
    final romanUrdu = state.romanUrdu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('crop_doctor_camera_button'),
            onPressed: () => _pickImage(ImageSource.camera),
            style: FilledButton.styleFrom(
              backgroundColor: PanelColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(
              romanUrdu ? 'Nayi tasveer lein' : 'Take photo',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('crop_doctor_gallery_button'),
            onPressed: () => _pickImage(ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              foregroundColor: PanelColors.brand,
              side: const BorderSide(color: PanelColors.brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              romanUrdu ? 'Gallery se chunein' : 'Choose from gallery',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(CropDoctorState state, CropDoctorNotifier notifier) {
    final imageFile = state.selectedImage!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        width: double.infinity,
        color: Colors.black12,
        child: Image.file(
          imageFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyActions(CropDoctorState state, CropDoctorNotifier notifier) {
    final romanUrdu = state.romanUrdu;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('crop_doctor_retake_button'),
            onPressed: notifier.retake,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(romanUrdu ? 'Dobara lein' : 'Retake'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            key: const ValueKey('crop_doctor_analyse_button'),
            onPressed: state.isProcessing ? null : notifier.diagnose,
            style: FilledButton.styleFrom(
              backgroundColor: PanelColors.brand,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              romanUrdu ? 'Tajziya karein' : 'Analyse',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingCard(CropDoctorState state, CropDoctorNotifier notifier) {
    final romanUrdu = state.romanUrdu;

    return PanelCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: PanelColors.brand,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            romanUrdu
                ? 'Patte ka tajziya jari hai...'
                : 'Analysing leaf health with AI...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PanelColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            romanUrdu
                ? 'Zyada se zyada 12 second intezar karein'
                : 'Analysing plant symptoms (max 12s)',
            style: const TextStyle(fontSize: 12, color: PanelColors.textMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey('crop_doctor_cancel_button'),
            onPressed: notifier.cancel,
            child: Text(romanUrdu ? 'Mansookh karein' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(CropDoctorState state, CropDoctorNotifier notifier) {
    final diagnosis = state.diagnosis!;
    final romanUrdu = state.romanUrdu;

    if (!diagnosis.isPlant) {
      return PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PanelColors.amberBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: PanelColors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    romanUrdu
                        ? 'Podha nazar nahi aaya'
                        : 'Not a plant photo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PanelColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              diagnosis.likelyIssue,
              style: const TextStyle(fontSize: 14, color: PanelColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: notifier.retake,
              style: FilledButton.styleFrom(
                backgroundColor: PanelColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(romanUrdu ? 'Nayi tasveer lein' : 'Retake photo'),
            ),
          ],
        ),
      );
    }

    final confidence = diagnosis.confidence;
    Color confColor = PanelColors.brand;
    Color confBg = PanelColors.tint;
    String confLabel = romanUrdu ? 'Yaqeen: Zyada' : 'High confidence';
    if (confidence == 'medium') {
      confColor = const Color(0xFF0D5F7A);
      confBg = const Color(0xFFE4F4F8);
      confLabel = romanUrdu ? 'Yaqeen: Darmiyana' : 'Medium confidence';
    } else if (confidence == 'low') {
      confColor = PanelColors.amber;
      confBg = PanelColors.amberBg;
      confLabel = romanUrdu
          ? 'Kam yaqeen - saaf tasveer dobara lein'
          : 'Low confidence - retake recommended';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PanelColors.amberBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A5A00),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        PanelCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (diagnosis.cropName.isNotEmpty) ...[
                Text(
                  diagnosis.cropName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: PanelColors.brand,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                diagnosis.likelyIssue,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PanelColors.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: confBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  confLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: confColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const PanelSectionLabel('Recommended safe actions'),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < diagnosis.steps.length; i++) ...[
                if (i > 0) const Divider(height: 18, color: PanelColors.border),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: PanelColors.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PanelColors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        diagnosis.steps[i],
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: PanelColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (diagnosis.whenToSeeExpert.isNotEmpty) ...[
          const SizedBox(height: 14),
          PanelCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.supervised_user_circle_outlined,
                  color: PanelColors.brand,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        romanUrdu ? 'Mahir se kab milein?' : 'When to see an expert',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PanelColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diagnosis.whenToSeeExpert,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: PanelColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PanelColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: PanelColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  romanUrdu
                      ? 'AI estimate only. Not a replacement for an agriculture officer.'
                      : 'AI estimate only. Not a replacement for an agriculture officer.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PanelColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('crop_doctor_new_photo_button'),
          onPressed: notifier.retake,
          style: FilledButton.styleFrom(
            backgroundColor: PanelColors.brand,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(
            romanUrdu ? 'Doosri tasveer check karein' : 'Check another photo',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
