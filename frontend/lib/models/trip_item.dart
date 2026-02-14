class TripItem {
  final String id;
  final String tripId;
  final String itemId;
  final String status; // 'suggested', 'packed', 'rejected'
  final double? scoreContribution;

  TripItem({
    required this.id,
    required this.tripId,
    required this.itemId,
    required this.status,
    this.scoreContribution,
  });

  factory TripItem.fromJson(Map<String, dynamic> json) {
    return TripItem(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      itemId: json['item_id'] as String,
      status: json['status'] as String,
      scoreContribution: (json['score_contribution'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'item_id': itemId,
      'status': status,
      'score_contribution': scoreContribution,
    };
  }

  Map<String, dynamic> toInsert() {
    return {
      'trip_id': tripId,
      'item_id': itemId,
      'status': status,
      'score_contribution': scoreContribution,
    };
  }

  TripItem copyWith({
    String? id,
    String? tripId,
    String? itemId,
    String? status,
    double? scoreContribution,
  }) {
    return TripItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      itemId: itemId ?? this.itemId,
      status: status ?? this.status,
      scoreContribution: scoreContribution ?? this.scoreContribution,
    );
  }
}
