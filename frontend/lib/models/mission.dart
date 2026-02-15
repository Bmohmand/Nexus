/// A mission / packing scenario. Mirrors the `missions` database table.
class Mission {
  final String id;
  final String title;
  final String? missionType;
  final String? description;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minTemperature;
  final int? maxTemperature;
  final double maxWeightGrams;
  final double maxVolume;
  final bool isResupplyAvailable;
  final String? constraintPreset;
  final String? planSummary;
  final List<String> planWarnings;
  final DateTime? createdAt;

  const Mission({
    required this.id,
    required this.title,
    this.missionType,
    this.description,
    this.destination,
    this.startDate,
    this.endDate,
    this.minTemperature,
    this.maxTemperature,
    this.maxWeightGrams = 20000,
    this.maxVolume = 100.0,
    this.isResupplyAvailable = false,
    this.constraintPreset,
    this.planSummary,
    this.planWarnings = const [],
    this.createdAt,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      missionType: json['mission_type'] as String?,
      description: json['description'] as String?,
      destination: json['destination'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      minTemperature: (json['min_temperature'] as num?)?.toInt(),
      maxTemperature: (json['max_temperature'] as num?)?.toInt(),
      maxWeightGrams: (json['max_weight_grams'] as num?)?.toDouble() ?? 20000,
      maxVolume: (json['max_volume'] as num?)?.toDouble() ?? 100.0,
      isResupplyAvailable: json['is_resupply_available'] as bool? ?? false,
      constraintPreset: json['constraint_preset'] as String?,
      planSummary: json['plan_summary'] as String?,
      planWarnings: (json['plan_warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
