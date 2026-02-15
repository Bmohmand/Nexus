import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Constraint presets available from the backend.
const Map<String, String> constraintPresets = {
  'carry_on_luggage': 'Carry-On (7 kg)',
  'checked_bag': 'Checked Bag (23 kg)',
  'drone_delivery': 'Drone Delivery (5 kg)',
  'medical_relief': 'Medical Relief (30 kg)',
  'hiking_day_trip': 'Day Hike (10 kg)',
  'bug_out_bag': 'Bug-Out Bag (15 kg)',
};

/// Currently selected constraint preset key.
final selectedPresetProvider = StateProvider<String>((ref) => 'carry_on_luggage');

/// Mission description text.
final missionQueryProvider = StateProvider<String>((ref) => '');
