/// List item from GET /api/v1/items (manifest_items).
class VaultItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String? category;
  final String domain;
  final String? utilitySummary;
  final List<String> semanticTags;
  final String? primaryMaterial;
  final String? weightEstimate;
  final String? thermalRating;
  final String? waterResistance;
  final String? durability;
  final String? compressibility;
  final String? environmentalSuitability;
  final String? limitationsAndFailureModes;
  final List<String> activityContexts;
  final List<String> unsuitableContexts;

  const VaultItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.category,
    this.domain = 'general',
    this.utilitySummary,
    this.semanticTags = const [],
    this.primaryMaterial,
    this.weightEstimate,
    this.thermalRating,
    this.waterResistance,
    this.durability,
    this.compressibility,
    this.environmentalSuitability,
    this.limitationsAndFailureModes,
    this.activityContexts = const [],
    this.unsuitableContexts = const [],
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      domain: json['domain'] as String? ?? 'general',
      utilitySummary: json['utility_summary'] as String?,
      semanticTags: List<String>.from(json['semantic_tags'] ?? []),
      primaryMaterial: json['primary_material'] as String?,
      weightEstimate: json['weight_estimate'] as String?,
      thermalRating: json['thermal_rating'] as String?,
      waterResistance: json['water_resistance'] as String?,
      durability: json['durability'] as String?,
      compressibility: json['compressibility'] as String?,
      environmentalSuitability: json['environmental_suitability'] as String?,
      limitationsAndFailureModes: json['limitations_and_failure_modes'] as String?,
      activityContexts: List<String>.from(json['activity_contexts'] ?? []),
      unsuitableContexts: List<String>.from(json['unsuitable_contexts'] ?? []),
    );
  }
}
