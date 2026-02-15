class StorageContainer {
  final String id;
  final String name;
  final String? description;
  final String containerType;
  final double maxWeightGrams;
  final double? maxVolumeLiters;
  final double tareWeightGrams;
  final int quantity;
  final bool isDefault;
  final String? icon;
  final String? color;
  bool isSelected; // Local UI state for query-time selection

  StorageContainer({
    required this.id,
    required this.name,
    this.description,
    this.containerType = 'bag',
    required this.maxWeightGrams,
    this.maxVolumeLiters,
    this.tareWeightGrams = 0,
    this.quantity = 1,
    this.isDefault = false,
    this.icon,
    this.color,
    this.isSelected = false,
  });

  factory StorageContainer.fromJson(Map<String, dynamic> json) {
    return StorageContainer(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      containerType: json['container_type'] as String? ?? 'bag',
      maxWeightGrams: (json['max_weight_grams'] as num).toDouble(),
      maxVolumeLiters: (json['max_volume_liters'] as num?)?.toDouble(),
      tareWeightGrams: (json['tare_weight_grams'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      isDefault: json['is_default'] as bool? ?? false,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'container_type': containerType,
        'max_weight_grams': maxWeightGrams,
        'max_volume_liters': maxVolumeLiters,
        'tare_weight_grams': tareWeightGrams,
        'quantity': quantity,
        'is_default': isDefault,
        'icon': icon,
        'color': color,
      };

  double get effectiveCapacityGrams => maxWeightGrams - tareWeightGrams;

  String get weightDisplayLbs =>
      '${(maxWeightGrams / 453.592).toStringAsFixed(1)} lbs';

  String get weightDisplayKg =>
      '${(maxWeightGrams / 1000).toStringAsFixed(1)} kg';
}
