class AiFallbackEntry {
  final List<String> keywords;
  final String answer;

  const AiFallbackEntry(this.keywords, this.answer);
}

const List<AiFallbackEntry> aiFallbackKnowledgeBase = [
  AiFallbackEntry(
    ['vitamin c', 'citrus'],
    'Fruits rich in Vitamin C include oranges, strawberries, guava, kiwi, and lemons. '
    'A serving of any of these covers most of a person\'s daily Vitamin C needs.',
  ),
  AiFallbackEntry(
    ['tomato', 'store tomato'],
    'Store ripe tomatoes at room temperature, away from direct sunlight, and use them within a few days. '
    'Refrigeration dulls their flavor and texture, so only chill tomatoes that are already very ripe.',
  ),
  AiFallbackEntry(
    ['seasonal vegetable', 'in season'],
    'Seasonal vegetables change by region and time of year. As a general rule, leafy greens and root vegetables '
    'do well in cooler months, while tomatoes, peppers, and squash are summer crops.',
  ),
  AiFallbackEntry(
    ['spinach'],
    'Spinach is rich in iron, Vitamin K, and folate. It supports bone health and is a good addition to salads, '
    'soups, and smoothies.',
  ),
  AiFallbackEntry(
    ['salad', 'healthy salad'],
    'A well-balanced salad usually combines leafy greens like spinach or lettuce with a crunchy vegetable such as '
    'carrots or cucumber, plus a protein source like chickpeas or paneer.',
  ),
  AiFallbackEntry(
    ['store', 'storage'],
    'Most fresh produce lasts longest in a cool, dry place away from direct sunlight. Leafy greens and berries keep '
    'best refrigerated, while onions, garlic, and potatoes prefer a dark, ventilated spot outside the fridge.',
  ),
  AiFallbackEntry(
    ['organic'],
    'Organic produce is grown without synthetic pesticides or fertilizers. Many customers choose organic products '
    'for this reason, though both organic and conventional produce can be part of a healthy diet.',
  ),
  AiFallbackEntry(
    ['pickup', 'slot'],
    'Pickup slots and timings are set by each farmer and shown on their profile. You can choose a slot during '
    'checkout once you have added items to your cart.',
  ),
];

const String aiFallbackDefaultAnswer =
    'I can help with basic questions about fruits, vegetables, storage tips, and nutrition. '
    'Could you rephrase your question, or ask about a specific product?';

String matchAiFallbackAnswer(String query) {
  final normalized = query.toLowerCase();
  for (final entry in aiFallbackKnowledgeBase) {
    for (final keyword in entry.keywords) {
      if (normalized.contains(keyword)) {
        return entry.answer;
      }
    }
  }
  return aiFallbackDefaultAnswer;
}
