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

  /// All items (selected + raw) for display.
  List<SearchResultItem> get allItems =>
      selectedItems.isNotEmpty ? selectedItems : rawResults;
}

/// Pack response from the optimizer.
class PackResponse {
  final String status;
  final List<PackedItem> packedItems;
  final double totalWeightGrams;
  final double totalSimilarityScore;
  final double weightUtilization;
  final double solverTimeMs;
  final List<String> relaxedConstraints;
  final String? missionSummary;
  final List<String> warnings;

  const PackResponse({
    required this.status,
    this.packedItems = const [],
    this.totalWeightGrams = 0,
    this.totalSimilarityScore = 0,
    this.weightUtilization = 0,
    this.solverTimeMs = 0,
    this.relaxedConstraints = const [],
    this.missionSummary,
    this.warnings = const [],
  });

  factory PackResponse.fromJson(Map<String, dynamic> json) {
    return PackResponse(
      status: json['status'] as String? ?? 'unknown',
      packedItems: (json['packed_items'] as List<dynamic>?)
              ?.map((e) => PackedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalWeightGrams:
          (json['total_weight_grams'] as num?)?.toDouble() ?? 0,
      totalSimilarityScore:
          (json['total_similarity_score'] as num?)?.toDouble() ?? 0,
      weightUtilization:
          (json['weight_utilization'] as num?)?.toDouble() ?? 0,
      solverTimeMs: (json['solver_time_ms'] as num?)?.toDouble() ?? 0,
      relaxedConstraints: (json['relaxed_constraints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      missionSummary: json['mission_summary'] as String?,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class PackedItem {
  final String itemId;
  final String name;
  final String category;
  final int quantity;
  final double weightGrams;
  final double similarityScore;
  final List<String> semanticTags;

  const PackedItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.weightGrams,
    required this.similarityScore,
    this.semanticTags = const [],
  });

  factory PackedItem.fromJson(Map<String, dynamic> json) {
    return PackedItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'misc',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      weightGrams: (json['weight_grams'] as num?)?.toDouble() ?? 0,
      similarityScore:
          (json['similarity_score'] as num?)?.toDouble() ?? 0,
      semanticTags: (json['semantic_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
