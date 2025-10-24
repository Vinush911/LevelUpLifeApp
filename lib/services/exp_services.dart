import 'dart:math'; // Corrected: Changed '.' to ':'

class Stat {
  int level;
  double exp;

  Stat({required this.level, required this.exp});

  double nextLevelExp() {
    // The result of pow() is a 'num', so we cast it to 'double'.
    return (50 * pow(level.toDouble(), 1.5)).toDouble();
  }
}

