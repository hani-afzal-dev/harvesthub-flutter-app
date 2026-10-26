import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import 'service_providers.dart';

class ProfileEditState {
  final bool editing;
  final bool saving;
  final String? error;

  const ProfileEditState(
      {this.editing = false, this.saving = false, this.error});
}

class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  final AuthService _authService;

  ProfileEditNotifier(this._authService) : super(const ProfileEditState());

  void toggleEditing() {
    state = ProfileEditState(editing: !state.editing);
  }

  Future<bool> save({
    required String uid,
    required String name,
    required String phone,
    required String address,
  }) async {
    if (!Validators.isValidName(name) ||
        !Validators.isValidPhone(phone) ||
        !Validators.isValidAddress(address)) {
      state = const ProfileEditState(
          editing: true, error: 'Please check the fields highlighted above.');
      return false;
    }

    state = const ProfileEditState(editing: true, saving: true);
    try {
      await _authService.updateProfile(uid,
          name: name, phone: phone, address: address);
      if (mounted) state = const ProfileEditState();
      return true;
    } catch (_) {
      if (mounted) {
        state = const ProfileEditState(
            editing: true, error: 'Could not save changes. Please try again.');
      }
      return false;
    }
  }
}

final profileEditProvider =
    StateNotifierProvider.autoDispose<ProfileEditNotifier, ProfileEditState>(
        (ref) {
  return ProfileEditNotifier(ref.watch(authServiceProvider));
});
