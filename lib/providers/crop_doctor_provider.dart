import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crop_diagnosis.dart';
import '../services/crop_doctor_service.dart';

enum CropDoctorStatus {
  idle,
  imageReady,
  processing,
  result,
  failed,
}

class CropDoctorState {
  final CropDoctorStatus status;
  final File? selectedImage;
  final CropDiagnosis? diagnosis;
  final String? errorMessage;
  final bool romanUrdu;

  const CropDoctorState({
    this.status = CropDoctorStatus.idle,
    this.selectedImage,
    this.diagnosis,
    this.errorMessage,
    this.romanUrdu = false,
  });

  bool get isProcessing => status == CropDoctorStatus.processing;
  bool get hasResult =>
      status == CropDoctorStatus.result || status == CropDoctorStatus.failed;

  CropDoctorState copyWith({
    CropDoctorStatus? status,
    File? selectedImage,
    CropDiagnosis? diagnosis,
    String? errorMessage,
    bool? romanUrdu,
  }) {
    return CropDoctorState(
      status: status ?? this.status,
      selectedImage: selectedImage ?? this.selectedImage,
      diagnosis: diagnosis ?? this.diagnosis,
      errorMessage: errorMessage ?? this.errorMessage,
      romanUrdu: romanUrdu ?? this.romanUrdu,
    );
  }
}

class CropDoctorNotifier extends StateNotifier<CropDoctorState> {
  final CropDoctorService _service;

  CropDoctorNotifier(this._service) : super(const CropDoctorState());

  void setImage(File image) {
    state = state.copyWith(
      status: CropDoctorStatus.imageReady,
      selectedImage: image,
      diagnosis: null,
      errorMessage: null,
    );
  }

  void setLanguage({required bool romanUrdu}) {
    state = state.copyWith(romanUrdu: romanUrdu);
  }

  Future<void> diagnose() async {
    final image = state.selectedImage;
    if (image == null || state.isProcessing) return;

    state = state.copyWith(
      status: CropDoctorStatus.processing,
      errorMessage: null,
    );

    final result = await _service.diagnose(image, romanUrdu: state.romanUrdu);
    switch (result) {
      case CropDoctorSuccess(:final diagnosis):
        state = state.copyWith(
          status: CropDoctorStatus.result,
          diagnosis: diagnosis,
          errorMessage: null,
        );
      case CropDoctorFailure(:final message, :final fallbackDiagnosis):
        state = state.copyWith(
          status: CropDoctorStatus.failed,
          diagnosis: fallbackDiagnosis,
          errorMessage: message,
        );
    }
  }

  void cancel() {
    if (state.selectedImage != null) {
      state = state.copyWith(
        status: CropDoctorStatus.imageReady,
        errorMessage: null,
      );
    } else {
      state = const CropDoctorState();
    }
  }

  void retake() {
    state = state.copyWith(
      status: CropDoctorStatus.idle,
      selectedImage: null,
      diagnosis: null,
      errorMessage: null,
    );
  }

  void reset() {
    state = const CropDoctorState();
  }
}

final cropDoctorServiceProvider = Provider<CropDoctorService>((ref) {
  return CropDoctorService();
});

final cropDoctorProvider =
    StateNotifierProvider.autoDispose<CropDoctorNotifier, CropDoctorState>(
        (ref) {
  return CropDoctorNotifier(ref.watch(cropDoctorServiceProvider));
});
