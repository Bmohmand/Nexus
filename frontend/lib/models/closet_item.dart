enum ItemCategory {
  top,
  bottom,
  outerwear,
  shoes,
  accessory;

  static ItemCategory fromString(String value) {
    return ItemCategory.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ItemCategory.top,
    );
  }
}

enum LaundryStatus {
  clean,
  dirty,
  dryCleanOnly;

  static LaundryStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'clean':
        return LaundryStatus.clean;
      case 'dirty':
        return LaundryStatus.dirty;
      case 'dry_clean_only':
        return LaundryStatus.dryCleanOnly;
      default:
        return LaundryStatus.clean;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case LaundryStatus.clean:
        return 'clean';
      case LaundryStatus.dirty:
        return 'dirty';
      case LaundryStatus.dryCleanOnly:
        return 'dry_clean_only';
    }
  }
}

class ClosetItem {
  final String id;
  final String userId;
  final String profileId;
  final String? name;
  final String? imageUrl;
  final ItemCategory category;
  final List<String> aiTags;
  final int? warmthRating;
  final double volumeScore;
  final LaundryStatus laundryStatus;
  final DateTime? lastWorn;
  final DateTime createdAt;

  ClosetItem({
    required this.id,
    required this.userId,
    required this.profileId,
    this.name,
    this.imageUrl,
    required this.category,
    this.aiTags = const [],
    this.warmthRating,
    this.volumeScore = 1.0,
    this.laundryStatus = LaundryStatus.clean,
    this.lastWorn,
    required this.createdAt,
  });

  factory ClosetItem.fromJson(Map<String, dynamic> json) {
    return ClosetItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String?,
      imageUrl: json['image_url'] as String?,
      category: ItemCategory.fromString(json['category'] as String),
      aiTags: (json['ai_tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      warmthRating: json['warmth_rating'] as int?,
      volumeScore: (json['volume_score'] as num?)?.toDouble() ?? 1.0,
      laundryStatus: LaundryStatus.fromString(json['laundry_status'] as String? ?? 'clean'),
      lastWorn: json['last_worn'] != null ? DateTime.parse(json['last_worn'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'profile_id': profileId,
      'name': name,
      'image_url': imageUrl,
      'category': category.name,
      'ai_tags': aiTags,
      'warmth_rating': warmthRating,
      'volume_score': volumeScore,
      'laundry_status': laundryStatus.toSnakeCase(),
      'last_worn': lastWorn?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'profile_id': profileId,
      'name': name,
      'image_url': imageUrl,
      'category': category.name,
      'ai_tags': aiTags,
      'warmth_rating': warmthRating,
      'volume_score': volumeScore,
      'laundry_status': laundryStatus.toSnakeCase(),
      'last_worn': lastWorn?.toIso8601String(),
    };
  }

  ClosetItem copyWith({
    String? id,
    String? userId,
    String? profileId,
    String? name,
    String? imageUrl,
    ItemCategory? category,
    List<String>? aiTags,
    int? warmthRating,
    double? volumeScore,
    LaundryStatus? laundryStatus,
    DateTime? lastWorn,
    DateTime? createdAt,
  }) {
    return ClosetItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      aiTags: aiTags ?? this.aiTags,
      warmthRating: warmthRating ?? this.warmthRating,
      volumeScore: volumeScore ?? this.volumeScore,
      laundryStatus: laundryStatus ?? this.laundryStatus,
      lastWorn: lastWorn ?? this.lastWorn,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
