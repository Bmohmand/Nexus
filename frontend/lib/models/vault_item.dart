/// List item from GET /api/v1/items (manifest_items).
class VaultItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String? category;
  final String domain;

  const VaultItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.category,
    this.domain = 'general',
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      domain: json['domain'] as String? ?? 'general',
    );
  }
}
