import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/models/crop_diagnosis.dart';
import 'package:harvesthub/services/crop_doctor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CropDiagnosis safety rules and parsing', () {
    test('Valid plant diagnosis parses correctly with safe steps', () {
      final json = {
        'isPlant': true,
        'cropName': 'Tomato',
        'likelyIssue': 'Early Blight',
        'confidence': 'high',
        'steps': [
          'Prune lower infected leaves showing concentric dark rings',
          'Increase spacing between plants to improve airflow',
          'Water only at the base of the plant in the morning',
        ],
        'whenToSeeExpert':
            'Visit your local agriculture extension officer if lesions spread to upper stems.',
      };

      final diagnosis = CropDiagnosis.fromJsonMap(json);
      expect(diagnosis, isNotNull);
      expect(diagnosis!.isPlant, isTrue);
      expect(diagnosis.cropName, 'Tomato');
      expect(diagnosis.likelyIssue, 'Early Blight');
      expect(diagnosis.confidence, 'high');
      expect(diagnosis.steps.length, 3);
      expect(diagnosis.whenToSeeExpert, contains('extension officer'));
    });

    test('Non-plant photo returns isPlant == false with friendly message', () {
      final json = {
        'isPlant': false,
        'cropName': '',
        'likelyIssue': 'Not a plant',
        'confidence': 'low',
        'steps': <String>[],
        'whenToSeeExpert': '',
      };

      final diagnosis = CropDiagnosis.fromJsonMap(json);
      expect(diagnosis, isNotNull);
      expect(diagnosis!.isPlant, isFalse);
      expect(diagnosis.steps, isEmpty);
      expect(diagnosis.likelyIssue, contains('not look like a plant'));
    });

    test('Drops any step containing chemical names or dosage quantities', () {
      final json = {
        'isPlant': true,
        'cropName': 'Wheat',
        'likelyIssue': 'Rust fungus',
        'confidence': 'medium',
        'steps': [
          'Remove infected yellow leaves from the crop',
          'Spray 5 ml of Mancozeb per litre of water', // must be dropped
          'Apply 10 g fungicide per acre', // must be dropped
          'Mix 2 tbsp chemical pesticide', // must be dropped
          'Ensure dry foliage by watering soil directly',
        ],
        'whenToSeeExpert': 'Contact agri extension officer.',
      };

      final diagnosis = CropDiagnosis.fromJsonMap(json);
      expect(diagnosis, isNotNull);
      // Chemical/dose steps dropped, leaving 2 safe steps
      expect(diagnosis!.steps.length, 2);
      expect(diagnosis.steps[0], contains('Remove infected yellow leaves'));
      expect(diagnosis.steps[1], contains('Ensure dry foliage'));
      for (final step in diagnosis.steps) {
        expect(step, isNot(contains('ml')));
        expect(step, isNot(contains('Mancozeb')));
        expect(step, isNot(contains('fungicide')));
        expect(step, isNot(contains('tbsp')));
        expect(step, isNot(contains('per acre')));
      }
    });

    test('If all steps contain chemicals/doses, generic fallback steps are used', () {
      final json = {
        'isPlant': true,
        'cropName': 'Cotton',
        'likelyIssue': 'Bollworm',
        'confidence': 'low',
        'steps': [
          'Apply 250 ml chlorpyrifos per acre',
          'Spray 2 g/l pesticide solution',
        ],
        'whenToSeeExpert': 'See officer.',
      };

      final diagnosis = CropDiagnosis.fromJsonMap(json);
      expect(diagnosis, isNotNull);
      expect(diagnosis!.steps.isNotEmpty, isTrue);
      // All forced steps were dropped, fallback steps substituted
      expect(diagnosis.steps[0], contains('Remove'));
      for (final step in diagnosis.steps) {
        expect(step, isNot(contains('chlorpyrifos')));
        expect(step, isNot(contains('pesticide')));
        expect(step, isNot(contains('ml')));
      }
    });

    test('Confidence strings normalize to lowercase or fallback to low', () {
      final json = {
        'isPlant': true,
        'likelyIssue': 'Leaf spot',
        'confidence': 'HIGH',
        'steps': ['Remove leaves'],
        'whenToSeeExpert': 'Check with officer',
      };
      final d1 = CropDiagnosis.fromJsonMap(json);
      expect(d1!.confidence, 'high');

      final jsonBadConf = {
        'isPlant': true,
        'likelyIssue': 'Leaf spot',
        'confidence': 'very-uncertain',
        'steps': ['Remove leaves'],
        'whenToSeeExpert': 'Check with officer',
      };
      final d2 = CropDiagnosis.fromJsonMap(jsonBadConf);
      expect(d2!.confidence, 'low');
    });

    test('Roman Urdu language mode applies proper fallback text', () {
      final fallback = CropDiagnosis.fallback(romanUrdu: true);
      expect(fallback.likelyIssue, contains('tajziya'));
      expect(fallback.steps.first, contains('patton'));
      expect(fallback.whenToSeeExpert, contains('zirat officer'));
    });

    test('Invalid or garbage AI json returns null without crash', () {
      expect(CropDiagnosis.fromJsonMap({}), isNull);
      expect(CropDiagnosis.fromJsonMap({'random': 123}), isNull);
    });
  });

  group('CropDoctorService state and concurrency', () {
    test('isRequestInProgress is false initially', () {
      final service = CropDoctorService();
      expect(service.isRequestInProgress, isFalse);
    });
  });
}
