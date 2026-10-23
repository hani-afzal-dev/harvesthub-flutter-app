class CropDiagnosis {
  final bool isPlant;
  final String cropName;
  final String likelyIssue;
  final String confidence; // 'low' | 'medium' | 'high'
  final List<String> steps;
  final String whenToSeeExpert;

  const CropDiagnosis({
    required this.isPlant,
    this.cropName = '',
    required this.likelyIssue,
    required this.confidence,
    required this.steps,
    required this.whenToSeeExpert,
  });

  static final _doseRegex = RegExp(
    r'\d+\s*(?:ml|m\.l\.|g\b|gm|gram|grams|kg|kgs|kilo|kilogram|litre|litres|liter|liters|ltr|l\b|tbsp|tsp|per\s+acre|per\s+hectare|per\s+litre|per\s+liter|fl\s*oz)',
    caseSensitive: false,
  );

  static final _chemicalRegex = RegExp(
    r'\b(?:pesticide|fungicide|insecticide|herbicide|chlorpyrifos|mancozeb|carbendazim|imidacloprid|glyphosate|cypermethrin|paraquat|monocrotophos|malathion|dimethoate|deltamethrin)\b',
    caseSensitive: false,
  );

  static List<String> fallbackSteps({bool romanUrdu = false}) {
    if (romanUrdu) {
      return [
        'Kharab ya beemar patton ko tor kar alag kar dein.',
        'Podhon ke darmiyan hawa aur dhoop ka rasta behtar banayein.',
        'Pani sirf jaron ko dein, patton par pani mat dalein.',
        'Mutasira podhe ko baqi fasal se alag rakhein.',
        'Kheti ke auzaar saaf aur pak rakhein.',
      ];
    }
    return [
      'Remove and safely dispose of badly damaged or infected leaves.',
      'Improve spacing between plants to enhance ventilation and sunlight.',
      'Water directly at the root zone, keeping leaves dry.',
      'Isolate affected plants to prevent spread to healthy crops.',
      'Clean and disinfect pruning tools after touching infected plants.',
    ];
  }

  static String defaultWhenToSeeExpert({bool romanUrdu = false}) {
    if (romanUrdu) {
      return 'Agar beemari barhe to apne ilaqai zirat officer ya qareebi agri mahir se ruju karein.';
    }
    return 'Visit your local agriculture extension officer or a nearby trusted agri expert if symptoms persist.';
  }

  static CropDiagnosis fallback({bool romanUrdu = false, String? reason}) {
    return CropDiagnosis(
      isPlant: true,
      cropName: '',
      likelyIssue: reason ??
          (romanUrdu
              ? 'Tasveer ka mukammal tajziya nahi ho saka.'
              : 'Could not analyse this photo.'),
      confidence: 'low',
      steps: fallbackSteps(romanUrdu: romanUrdu),
      whenToSeeExpert: defaultWhenToSeeExpert(romanUrdu: romanUrdu),
    );
  }

  static CropDiagnosis? fromJsonMap(
    Map<String, dynamic> map, {
    bool romanUrdu = false,
  }) {
    final rawIsPlant = map['isPlant'];
    if (rawIsPlant is! bool) return null;

    if (!rawIsPlant) {
      return CropDiagnosis(
        isPlant: false,
        cropName: '',
        likelyIssue: romanUrdu
            ? 'Ye tasveer kisi podhe ya patte ki nahi lagti.'
            : 'This does not look like a plant photo. Please retake.',
        confidence: 'low',
        steps: const [],
        whenToSeeExpert: '',
      );
    }

    String cropName = '';
    final rawCrop = map['cropName'];
    if (rawCrop is String) {
      cropName = rawCrop.trim();
      if (cropName.length > 100) cropName = cropName.substring(0, 100);
    }

    final rawIssue = map['likelyIssue'];
    if (rawIssue is! String) return null;
    var likelyIssue = rawIssue.trim();
    if (likelyIssue.isEmpty) return null;
    if (likelyIssue.length > 120) likelyIssue = likelyIssue.substring(0, 120);

    var confidence = 'low';
    final rawConf = map['confidence'];
    if (rawConf is String) {
      final confLower = rawConf.trim().toLowerCase();
      if (confLower == 'high' || confLower == 'medium' || confLower == 'low') {
        confidence = confLower;
      }
    }

    final rawSteps = map['steps'];
    final safeSteps = <String>[];
    if (rawSteps is List) {
      for (final step in rawSteps) {
        if (step is String) {
          final trimmed = step.trim();
          if (trimmed.isEmpty) continue;
          if (_doseRegex.hasMatch(trimmed) || _chemicalRegex.hasMatch(trimmed)) {
            continue;
          }
          final capped = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
          safeSteps.add(capped);
          if (safeSteps.length == 5) break;
        }
      }
    }

    final finalSteps = safeSteps.isNotEmpty
        ? safeSteps
        : fallbackSteps(romanUrdu: romanUrdu);

    var whenToSeeExpert = defaultWhenToSeeExpert(romanUrdu: romanUrdu);
    final rawExpert = map['whenToSeeExpert'];
    if (rawExpert is String && rawExpert.trim().isNotEmpty) {
      final trimmed = rawExpert.trim();
      whenToSeeExpert = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
    }

    return CropDiagnosis(
      isPlant: true,
      cropName: cropName,
      likelyIssue: likelyIssue,
      confidence: confidence,
      steps: finalSteps,
      whenToSeeExpert: whenToSeeExpert,
    );
  }
}
