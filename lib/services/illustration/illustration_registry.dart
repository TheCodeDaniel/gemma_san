class IllustrationRegistry {
  IllustrationRegistry._();

  static const _base = 'assets/illustrations';

  // Sorted alphabetically — const so it can be embedded in const tool definitions.
  static const List<String> allTopicIds = [
    'animal_cell',
    'day_and_night',
    'digestive_system',
    'dry_season',
    'earth_layers',
    'electricity_circuit',
    'flower_parts',
    'food_chain',
    'germs_microbes',
    'healthy_food',
    'human_heart',
    'life_cycle_butterfly',
    'lungs',
    'photosynthesis',
    'plant_cell',
    'rainy_season',
    'simple_machines',
    'skeleton',
    'solar_system',
    'states_of_matter',
    'water_cycle',
    'weather',
  ];

  /// Returns true if [topicId] is a known illustration topic.
  /// Does NOT guarantee the SVG file is present on disk.
  static bool hasIllustration(String topicId) => allTopicIds.contains(topicId);

  /// Returns the asset path for [topicId], or null if unrecognised.
  static String? getAssetPath(String topicId) =>
      hasIllustration(topicId) ? '$_base/$topicId.svg' : null;
}
