class Profile {
  final String id;
  final String userId;
  final String name;
  final bool isChild;
  final Map<String, dynamic> clothingSizePreferences;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.userId,
    required this.name,
    this.isChild = false,
    this.clothingSizePreferences = const {},
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      isChild: json['is_child'] as bool? ?? false,
      clothingSizePreferences: json['clothing_size_preferences'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'is_child': isChild,
      'clothing_size_preferences': clothingSizePreferences,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'name': name,
      'is_child': isChild,
      'clothing_size_preferences': clothingSizePreferences,
    };
  }
}
