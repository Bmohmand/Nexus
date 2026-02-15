/// A single item returned from semantic search.
class SearchResultItem {
  final String itemId;
  final String name;
  final double score;
  final String? imageUrl;
  final String? category;
  final String? domain;
  final String? utilitySummary;
  final List<String> semanticTags;
  final String? reason;

  const SearchResultItem({
    required this.itemId,
    required this.name,
    required this.score,
    this.imageUrl,
    this.category,
    this.domain,
    this.utilitySummary,
    this.semanticTags = const [],
    this.reason,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      domain: json['domain'] as String?,
      utilitySummary: json['utility_summary'] as String?,
      semanticTags: (json['semantic_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reason: json['reason'] as String?,
    );
  }
}

/// Full search response from the Nexus API.
class SearchResponse {
  final String? missionSummary;
  final List<SearchResultItem> selectedItems;
  final List<SearchResultItem> rejectedItems;
  final List<String> warnings;
  final List<SearchResultItem> rawResults;

  const SearchResponse({
    this.missionSummary,
    this.selectedItems = const [],
    this.rejectedItems = const [],
    this.warnings = const [],
    this.rawResults = const [],
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      missionSummary: json['mission_summary'] as String?,
      selectedItems: (json['selected_items'] as List<dynamic>?)
              ?.map((e) => SearchResultItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rejectedItems: (json['rejected_items'] as List<dynamic>?)
              ?.map((e) => SearchResultItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rawResults: (json['raw_results'] as List<dynamic>?)
              ?.map((e) => SearchResultItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  List<SearchResultItem> get allItems =>
      selectedItems.isNotEmpty ? selectedItems : rawResults;
}
