import 'package:flutter/material.dart';
import '../models/stat.dart';

class StatTile extends StatelessWidget {
  final String name;
  final Stat stat;

  const StatTile({super.key, required this.name, required this.stat});

  @override
  Widget build(BuildContext context) {
    final double progress = stat.nextLevelExp() > 0 ? stat.exp / stat.nextLevelExp() : 0.0;
    final Color progressColor = _getColorForStat(name);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade800)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$name - Lvl ${stat.level}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.isNaN ? 0.0 : progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade700,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stat.exp.toStringAsFixed(0)} / ${stat.nextLevelExp().toStringAsFixed(0)}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Color _getColorForStat(String statName) {
    switch (statName.toUpperCase()) {
      case 'STR':
        return Colors.redAccent;
      case 'END':
        return Colors.greenAccent;
      case 'DEX':
        return Colors.blueAccent;
      case 'INT':
        return Colors.purpleAccent;
      case 'WIS':
        return Colors.tealAccent;
      case 'CHA':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }
}
