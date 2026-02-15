import '../core/constants.dart';

/// A physical asset in the Manifest vault.
/// Mirrors the `manifest_items` database table.
class ManifestItem {
  final String id;
  final String name;
  final String? imageUrl;
  final AssetDomain domain;
  final String? category;
  final ItemStatus status;
  final int quantity;

  // AI-extracted context
  final String? primaryMaterial;
  final String? weightEstimate;
  final String? thermalRating;
  final String? waterResistance;
  final String? medicalApplication;
  final String? utilitySummary;
  final List<String> semanticTags;
  final String? durability;
  final String? compressibility;

  // Physical properties
  final int? environmentalRating;
  final double? volumeScore;
  final double? weightGrams;

  final DateTime? lastUsed;
  final DateTime? createdAt;

  const ManifestItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.domain = AssetDomain.general,
    this.category,
    this.status = ItemStatus.available,
    this.quantity = 1,
    this.primaryMaterial,
    this.weightEstimate,
    this.thermalRating,
    this.waterResistance,
    this.medicalApplication,
    this.utilitySummary,
    this.semanticTags = const [],
    this.durability,
    this.compressibility,
    this.environmentalRating,
    this.volumeScore,
    this.weightGrams,
    this.lastUsed,
    this.createdAt,
  });

  factory ManifestItem.fromJson(Map<String, dynamic> json) {
    return ManifestItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown Item',
      imageUrl: json['image_url'] as String?,
      domain: AssetDomain.fromString(json['domain'] as String?),
      category: json['category'] as String?,
      status: ItemStatus.fromString(json['status'] as String?),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      primaryMaterial: json['primary_material'] as String?,
      weightEstimate: json['weight_estimate'] as String?,
      thermalRating: json['thermal_rating'] as String?,
      waterResistance: json['water_resistance'] as String?,
      medicalApplication: json['medical_application'] as String?,
      utilitySummary: json['utility_summary'] as String?,
      semanticTags: (json['semantic_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      durability: json['durability'] as String?,
      compressibility: json['compressibility'] as String?,
      environmentalRating: (json['environmental_rating'] as num?)?.toInt(),
      volumeScore: (json['volume_score'] as num?)?.toDouble(),
      weightGrams: (json['weight_grams'] as num?)?.toDouble(),
      lastUsed: json['last_used'] != null
          ? DateTime.tryParse(json['last_used'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'domain': domain.value,
        'category': category,
        'status': status.value,
        'quantity': quantity,
        'primary_material': primaryMaterial,
        'weight_estimate': weightEstimate,
        'thermal_rating': thermalRating,
        'water_resistance': waterResistance,
        'medical_application': medicalApplication,
        'utility_summary': utilitySummary,
        'semantic_tags': semanticTags,
        'durability': durability,
        'compressibility': compressibility,
        'environmental_rating': environmentalRating,
        'volume_score': volumeScore,
        'weight_grams': weightGrams,
      };
}
