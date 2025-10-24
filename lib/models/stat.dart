import 'dart:math';

// This is the single, consolidated Stat class.
// The duplicate class in exp_services.dart has been removed.
class Stat {
  int level;
  double exp;

  Stat({required this.level, required this.exp});

  // Factory constructor to safely create a Stat from a map.
  factory Stat.fromMap(dynamic data) {
    if (data is! Map) {
      return Stat(level: 1, exp: 0); // Return a default stat if data is invalid.
    }
    return Stat(
      level: (data['level'] ?? 1).toInt(),
      exp: (data['exp'] ?? 0.0).toDouble(),
    );
  }

  // Calculates the experience required for the next level for a specific stat.
  double nextLevelExp() {
    return (50 * pow(level.toDouble(), 1.5)).toDouble();
  }
}
