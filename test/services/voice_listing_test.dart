import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/models/category_model.dart';
import 'package:harvesthub/models/voice_listing_draft.dart';
import 'package:harvesthub/services/voice_listing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCategories = [
    CategoryModel(categoryId: 'cat_veg', name: 'Vegetables'),
    CategoryModel(categoryId: 'cat_fruit', name: 'Fruits'),
    CategoryModel(categoryId: 'cat_dairy', name: 'Dairy & Eggs'),
  ];

  group('VoiceListingDraft unit normalization and parsing', () {
    test('Speaking "5 kilo tamatar, 80 rupees per kilo" parses correctly', () {
      final json = {
        'itemName': 'tamatar',
        'category': 'Vegetables',
        'quantity': 5,
        'unit': 'kilo',
        'pricePerUnit': 80,
        'description': 'Taza tamatar',
      };

      final draft = VoiceListingDraft.fromJsonMap(json, sampleCategories);
      expect(draft, isNotNull);
      expect(draft!.itemName, 'tamatar');
      expect(draft.quantity, 5);
      expect(draft.unit, 'kg');
      expect(draft.pricePerUnit, 80.0);
      expect(draft.categoryId, 'cat_veg');
      expect(draft.categoryName, 'Vegetables');
      expect(draft.description, 'Taza tamatar');
    });

    test('Unit normalization maps colloquial terms properly', () {
      expect(VoiceListingDraft.normalizeUnit('kilo'), 'kg');
      expect(VoiceListingDraft.normalizeUnit('kg'), 'kg');
      expect(VoiceListingDraft.normalizeUnit('kilograms'), 'kg');
      expect(VoiceListingDraft.normalizeUnit('liter'), 'litre');
      expect(VoiceListingDraft.normalizeUnit('litre'), 'litre');
      expect(VoiceListingDraft.normalizeUnit('darjan'), 'dozen');
      expect(VoiceListingDraft.normalizeUnit('dozen'), 'dozen');
      expect(VoiceListingDraft.normalizeUnit('dana'), 'piece');
      expect(VoiceListingDraft.normalizeUnit('adad'), 'piece');
      expect(VoiceListingDraft.normalizeUnit('piece'), 'piece');
    });

    test('Unknown category leaves categoryId null and categoryName empty', () {
      final json = {
        'itemName': 'honey',
        'category': 'Organic Sweeteners',
        'quantity': 2,
        'unit': 'kg',
        'pricePerUnit': 1200,
      };

      final draft = VoiceListingDraft.fromJsonMap(json, sampleCategories);
      expect(draft, isNotNull);
      expect(draft!.categoryId, isNull);
      expect(draft.categoryName, '');
      expect(draft.itemName, 'honey');
    });

    test('Category matching is case-insensitive', () {
      final json = {
        'itemName': 'mango',
        'category': 'fruits',
        'quantity': 10,
        'unit': 'kg',
        'pricePerUnit': 250,
      };

      final draft = VoiceListingDraft.fromJsonMap(json, sampleCategories);
      expect(draft, isNotNull);
      expect(draft!.categoryId, 'cat_fruit');
    });

    test('Spoken attack setting price to 0 is rejected by validation', () {
      final json = {
        'itemName': 'free apples',
        'category': 'Fruits',
        'quantity': 5,
        'unit': 'kg',
        'pricePerUnit': 0,
      };

      final draft = VoiceListingDraft.fromJsonMap(json, sampleCategories);
      expect(draft, isNull);
    });

    test('Negative price or negative stock is rejected', () {
      final json1 = {
        'itemName': 'apples',
        'category': 'Fruits',
        'quantity': 5,
        'unit': 'kg',
        'pricePerUnit': -50,
      };
      expect(VoiceListingDraft.fromJsonMap(json1, sampleCategories), isNull);

      final json2 = {
        'itemName': 'apples',
        'category': 'Fruits',
        'quantity': -2,
        'unit': 'kg',
        'pricePerUnit': 50,
      };
      expect(VoiceListingDraft.fromJsonMap(json2, sampleCategories), isNull);
    });

    test('Excessive quantity or invalid item name lengths are rejected', () {
      final jsonTooLong = {
        'itemName': 'a' * 101,
        'category': 'Vegetables',
        'quantity': 5,
        'unit': 'kg',
        'pricePerUnit': 100,
      };
      expect(VoiceListingDraft.fromJsonMap(jsonTooLong, sampleCategories), isNull);

      final jsonTooShort = {
        'itemName': 'a',
        'category': 'Vegetables',
        'quantity': 5,
        'unit': 'kg',
        'pricePerUnit': 100,
      };
      expect(VoiceListingDraft.fromJsonMap(jsonTooShort, sampleCategories), isNull);

      final jsonHugeQty = {
        'itemName': 'potatoes',
        'category': 'Vegetables',
        'quantity': 50000,
        'unit': 'kg',
        'pricePerUnit': 100,
      };
      expect(VoiceListingDraft.fromJsonMap(jsonHugeQty, sampleCategories), isNull);
    });

    test('Invalid/garbage AI json is rejected without crash', () {
      expect(VoiceListingDraft.fromJsonMap({}, sampleCategories), isNull);
      expect(VoiceListingDraft.fromJsonMap({'random': 'garbage'}, sampleCategories), isNull);
    });
  });

  group('VoiceListingService throttling and concurrency', () {
    test('isRequestInProgress reflects concurrency state', () {
      final service = VoiceListingService();
      expect(service.isRequestInProgress, isFalse);
      service.dispose();
    });
  });
}
