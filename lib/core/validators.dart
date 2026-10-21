import 'phone_numbers.dart';

class Validators {
  static final RegExp emailPattern = RegExp(
      r'^[a-z0-9]+([._-][a-z0-9]+)*@[a-z0-9]+([.-][a-z0-9]+)*\.[a-z]{2,}$');
  static final RegExp namePattern = RegExp(r"^[a-zA-Z\s'-]{2,60}$");
  static final RegExp phonePattern = RegExp(r'^\+[1-9][0-9]{7,14}$');
  static final RegExp _localPhoneChars = RegExp(r'^[0-9 ()-]+$');
  static final RegExp _uppercasePattern = RegExp(r'[A-Z]');
  static final RegExp _digitPattern = RegExp(r'[0-9]');
  static final RegExp _specialPattern = RegExp(r'[^A-Za-z0-9\s]');
  static final RegExp addressPattern = RegExp(r"^[A-Za-z0-9 ,./#()'-]+$");
  static final RegExp _letterPattern = RegExp(r'[A-Za-z]');
  static final RegExp _addressGap = RegExp(r'[ ,]+');

  static const int addressMinLength = 10;
  static const int addressMaxLength = 200;

  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;

  static bool isValidEmail(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.length > 254) return false;
    final localPart = trimmed.split('@').first;
    if (localPart.length > 64) return false;
    return emailPattern.hasMatch(trimmed);
  }

  static String? passwordError(String value) {
    if (value.length < passwordMinLength) {
      return 'Password must be at least 8 characters';
    }
    if (value.length > passwordMaxLength) {
      return 'Password must be 128 characters or fewer';
    }
    if (!_uppercasePattern.hasMatch(value)) {
      return 'Password must include at least one uppercase letter';
    }
    if (!_digitPattern.hasMatch(value)) {
      return 'Password must include at least one number';
    }
    if (!_specialPattern.hasMatch(value)) {
      return 'Password must include at least one special character (!@#\$%^&*)';
    }
    return null;
  }

  static bool isValidPassword(String value) {
    return passwordError(value) == null;
  }

  static bool isPasswordProvided(String value) {
    return value.isNotEmpty && value.length <= passwordMaxLength;
  }

  static bool isValidName(String value) {
    return namePattern.hasMatch(value.trim());
  }

  static bool isValidPhone(String value) {
    return phonePattern.hasMatch(value.trim());
  }

  static String? localPhoneError(DialCountry country, String local) {
    final trimmed = local.trim();
    if (trimmed.isEmpty) return 'Phone number is required';
    if (!_localPhoneChars.hasMatch(trimmed)) {
      return 'Use digits only, without the country code';
    }
    if (localDigits(trimmed).length < 6) return 'This number is too short';
    if (!isValidPhone(toE164(country, trimmed))) {
      return 'Enter a valid ${country.name} number';
    }
    return null;
  }

  static bool isValidLocalPhone(DialCountry country, String local) {
    return localPhoneError(country, local) == null;
  }

  static String? addressError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Address is required';
    if (trimmed.length < addressMinLength) {
      return 'Address is too short. Add house number, street and area.';
    }
    if (trimmed.length > addressMaxLength) {
      return 'Address must be 200 characters or fewer';
    }
    if (!addressPattern.hasMatch(trimmed)) {
      return "Address can only use letters, numbers, spaces and , . - / # ' ( )";
    }
    if (!_letterPattern.hasMatch(trimmed)) {
      return 'Address must include a street or area name';
    }

    var parts = 0;
    for (final part in trimmed.split(_addressGap)) {
      if (part.isNotEmpty) parts++;
    }
    if (parts < 2) {
      return 'Add house number, street and area, e.g. House 12, Block C, Latifabad';
    }
    return null;
  }

  static bool isValidAddress(String value) {
    return addressError(value) == null;
  }
}
