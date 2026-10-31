import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/core/phone_numbers.dart';
import 'package:harvesthub/core/validators.dart';

const attackInputs = [
  "' OR 1=1 --",
  '"; DROP TABLE users;',
  '<script>alert(1)</script>',
  '../../',
  r'${}',
];

void main() {
  group('email', () {
    test('accepts normal addresses', () {
      expect(Validators.isValidEmail('ayesha.khan@gmail.com'), isTrue);
      expect(Validators.isValidEmail('  Ayesha_Khan@Gmail.COM '), isTrue);
    });

    test('rejects broken or unsafe addresses', () {
      for (final value in [
        '',
        '   ',
        'name@',
        '@gmail.com',
        'na me@gmail.com',
        'name+tag@gmail.com',
        'name..dot@gmail.com',
        r'name@#$%.com',
        'name@gmail',
        '.name@gmail.com',
        ...attackInputs,
      ]) {
        expect(Validators.isValidEmail(value), isFalse, reason: value);
      }
    });

    test('rejects a local part longer than 64 characters', () {
      expect(Validators.isValidEmail('${'a' * 65}@gmail.com'), isFalse);
    });
  });

  group('name', () {
    test('accepts real names', () {
      for (final value in ['Ayesha Khan', "D'Souza", 'Anne-Marie']) {
        expect(Validators.isValidName(value), isTrue, reason: value);
      }
    });

    test('rejects symbols, digits, emoji and injection text', () {
      for (final value in [
        'A',
        '   ',
        'Ayesha1',
        'Ayesha 🌱',
        ...attackInputs
      ]) {
        expect(Validators.isValidName(value), isFalse, reason: value);
      }
    });
  });

  group('password', () {
    test('needs length, uppercase, number and symbol', () {
      expect(Validators.passwordError('short'), isNotNull);
      expect(Validators.passwordError('alllowercase1!'), isNotNull);
      expect(Validators.passwordError('NoNumbers!!'), isNotNull);
      expect(Validators.passwordError('NoSymbol123'), isNotNull);
      expect(Validators.passwordError('Hania2468@'), isNull);
    });

    test('rejects passwords over 128 characters', () {
      expect(Validators.isValidPassword('Aa1!${'x' * 130}'), isFalse);
    });
  });

  group('address', () {
    test('accepts a full address', () {
      expect(Validators.isValidAddress('House 12, Block C, Latifabad'), isTrue);
    });

    test('rejects short, symbol-only or unsafe addresses', () {
      for (final value in [
        '',
        'Home',
        '1234567890',
        'House12Latifabad',
        ...attackInputs
      ]) {
        expect(Validators.isValidAddress(value), isFalse, reason: value);
      }
    });
  });

  group('phone', () {
    test('accepts a Pakistani mobile number', () {
      expect(
          Validators.localPhoneError(defaultDialCountry, '3001234567'), isNull);
    });

    test('rejects letters and very short numbers', () {
      expect(
          Validators.localPhoneError(defaultDialCountry, '300abc'), isNotNull);
      expect(Validators.localPhoneError(defaultDialCountry, '123'), isNotNull);
      expect(Validators.localPhoneError(defaultDialCountry, ''), isNotNull);
    });
  });
}
