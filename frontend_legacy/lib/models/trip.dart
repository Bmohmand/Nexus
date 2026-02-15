class Trip {
  final String id;
  final String userId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final bool isLaundryAvailable;
  final double maxLuggageVolume;
  final int? minTemperature;
  final int? maxTemperature;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.userId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.isLaundryAvailable = false,
    this.maxLuggageVolume = 100.0,
    this.minTemperature,
    this.maxTemperature,
    required this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      destination: json['destination'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isLaundryAvailable: json['is_laundry_available'] as bool? ?? false,
      maxLuggageVolume: (json['max_luggage_volume'] as num?)?.toDouble() ?? 100.0,
      minTemperature: json['min_temperature'] as int?,
      maxTemperature: json['max_temperature'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'destination': destination,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_laundry_available': isLaundryAvailable,
      'max_luggage_volume': maxLuggageVolume,
      'min_temperature': minTemperature,
      'max_temperature': maxTemperature,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'destination': destination,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_laundry_available': isLaundryAvailable,
      'max_luggage_volume': maxLuggageVolume,
      'min_temperature': minTemperature,
      'max_temperature': maxTemperature,
    };
  }

  int get durationDays {
    return endDate.difference(startDate).inDays + 1;
  }
}
