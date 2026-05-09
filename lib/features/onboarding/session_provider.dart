import 'package:flutter_riverpod/flutter_riverpod.dart';

// Cleared on every app restart — avatar picker runs on each launch.
final currentAvatarIdProvider = StateProvider<String>((ref) => 'default');

// Populated by AvatarPickerScreen from SharedPreferences on each launch.
final currentAgeRangeProvider = StateProvider<String?>((ref) => null);
