/// User profile for multi-user / family mode.
/// Mirrors the `profiles` database table.
class Profile {
  final String id;
  final String userId;
  final String name;
  final bool isChild;
  final Map<String, dynamic> preferences;
  final DateTime? createdAt;

  const Profile({
    required this.id,
    required this.userId,
    required this.name,
    this.isChild = false,
    this.preferences = const {},
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      isChild: json['is_child'] as bool? ?? false,
      preferences:
          (json['preferences'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
