import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  String name;
  int level;
  double exp;
  String title;
  Map<String, int> stats;
  // --- NEW: Field for unassigned stat points ---
  int unassignedStatPoints;
  Map<String, Timestamp> unlockedAchievements;
  Map<String, int> unlockedSkills;
  int gold;
  int gachaShards;
  List<String> purchasedItems;
  String? equippedBorderId;
  Map<String, String> equippedItems;
  String? avatarUrl;
  List<String> friends;
  List<String> friendRequestsSent;
  List<String> friendRequestsReceived;
  String? userClass;
  int gachaPityCounter;
  Timestamp lastLogin;
  int loginStreak;
  String? guildId;
  bool? isAdmin;

  // --- UPGRADES ---
  int currentEnergy;
  int maxEnergy;
  Timestamp lastEnergyRecharge;
  String? statusMessage;
  int pvpWins;
  int pvpLosses;
  Timestamp lastOnline;

  User({
    required this.uid,
    required this.name,
    required this.level,
    required this.exp,
    required this.title,
    required this.stats,
    // --- NEW: Added to constructor ---
    required this.unassignedStatPoints,
    required this.unlockedAchievements,
    required this.unlockedSkills,
    required this.gold,
    required this.gachaShards,
    required this.purchasedItems,
    this.equippedBorderId,
    required this.equippedItems,
    this.avatarUrl,
    required this.friends,
    required this.friendRequestsSent,
    required this.friendRequestsReceived,
    this.userClass,
    required this.gachaPityCounter,
    required this.lastLogin,
    required this.loginStreak,
    this.guildId,
    this.isAdmin,
    // --- UPGRADES ---
    required this.currentEnergy,
    required this.maxEnergy,
    required this.lastEnergyRecharge,
    this.statusMessage,
    required this.pvpWins,
    required this.pvpLosses,
    required this.lastOnline,
  });

  factory User.fromFirestore(DocumentSnapshot<Object?>? doc) {
    final data = doc?.data() as Map<String, dynamic>? ?? {};
    final statsFromDb = data['stats'] is Map ? Map<String, dynamic>.from(data['stats']) : {};
    final standardizedStats = {
      'STR': 10, 'END': 10, 'DEX': 10,
      'INT': 10, 'WIS': 10, 'CHA': 10,
    };
    standardizedStats.forEach((key, value) {
      final dbKey = statsFromDb.keys.firstWhere((k) => k.toUpperCase() == key, orElse: () => key);
      standardizedStats[key] = (statsFromDb[dbKey] ?? value).toInt();
    });
    final unlockedAchievements = data['unlockedAchievements'] is Map ? Map<String, Timestamp>.from((data['unlockedAchievements'] as Map<String, dynamic>).map((key, value) => MapEntry(key, value as Timestamp))) : <String, Timestamp>{};
    final unlockedSkills = data['unlockedSkills'] is Map ? Map<String, int>.from((data['unlockedSkills'] as Map<String, dynamic>).map((key, value) => MapEntry(key, (value as num).toInt()))) : <String, int>{};

    return User(
      uid: doc?.id ?? '',
      name: data['name'] ?? 'Adventurer',
      level: (data['level'] ?? 1).toInt(),
      exp: (data['exp'] ?? 0.0).toDouble(),
      title: data['title'] ?? 'Novice Adventurer',
      stats: standardizedStats,
      // --- NEW: Read from Firestore, default to 0 ---
      unassignedStatPoints: (data['unassignedStatPoints'] as num? ?? 0).toInt(),
      unlockedAchievements: unlockedAchievements,
      unlockedSkills: unlockedSkills,
      gold: (data['gold'] ?? 0).toInt(),
      gachaShards: (data['gachaShards'] ?? 0).toInt(),
      purchasedItems: List<String>.from(data['purchasedItems'] ?? []),
      equippedBorderId: data['equippedBorderId'] as String?,
      equippedItems: Map<String, String>.from(data['equippedItems'] ?? {}),
      avatarUrl: data['avatarUrl'] as String?,
      friends: List<String>.from(data['friends'] ?? []),
      friendRequestsSent: List<String>.from(data['friendRequestsSent'] ?? []),
      friendRequestsReceived: List<String>.from(data['friendRequestsReceived'] ?? []),
      userClass: data['userClass'] as String?,
      gachaPityCounter: (data['gachaPityCounter'] as num? ?? 0).toInt(),
      lastLogin: data['lastLogin'] ?? Timestamp.fromMillisecondsSinceEpoch(0),
      loginStreak: (data['loginStreak'] as num? ?? 0).toInt(),
      guildId: data['guildId'] as String?,
      isAdmin: data['isAdmin'] as bool?,
      // --- UPGRADES (with default values) ---
      currentEnergy: (data['currentEnergy'] as num? ?? 100).toInt(),
      maxEnergy: (data['maxEnergy'] as num? ?? 100).toInt(),
      lastEnergyRecharge: data['lastEnergyRecharge'] ?? Timestamp.now(),
      statusMessage: data['statusMessage'] as String?,
      pvpWins: (data['pvpWins'] as num? ?? 0).toInt(),
      pvpLosses: (data['pvpLosses'] as num? ?? 0).toInt(),
      lastOnline: data['lastOnline'] ?? Timestamp.now(),
    );
  }

  void regenerateEnergy() {
    final now = DateTime.now();
    final lastRecharge = lastEnergyRecharge.toDate();
    final difference = now.difference(lastRecharge);

    final energyToRegen = (difference.inMinutes / 5).floor();

    if (energyToRegen > 0) {
      currentEnergy = min(maxEnergy, currentEnergy + energyToRegen);
      lastEnergyRecharge = Timestamp.fromMillisecondsSinceEpoch(
          lastRecharge.millisecondsSinceEpoch + (energyToRegen * 5 * 60 * 1000));
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'level': level,
      'exp': exp,
      'title': title,
      'stats': stats,
      'unassignedStatPoints': unassignedStatPoints, // --- NEW: Add to map ---
      'unlockedAchievements': unlockedAchievements,
      'unlockedSkills': unlockedSkills,
      'gold': gold,
      'gachaShards': gachaShards,
      'purchasedItems': purchasedItems,
      'equippedBorderId': equippedBorderId,
      'equippedItems': equippedItems,
      'avatarUrl': avatarUrl,
      'friends': friends,
      'friendRequestsSent': friendRequestsSent,
      'friendRequestsReceived': friendRequestsReceived,
      'userClass': userClass,
      'gachaPityCounter': gachaPityCounter,
      'lastLogin': lastLogin,
      'loginStreak': loginStreak,
      'guildId': guildId,
      'isAdmin': isAdmin,
      'currentEnergy': currentEnergy,
      'maxEnergy': maxEnergy,
      'lastEnergyRecharge': lastEnergyRecharge,
      'statusMessage': statusMessage,
      'pvpWins': pvpWins,
      'pvpLosses': pvpLosses,
      'lastOnline': lastOnline,
    };
  }

  double nextLevelExp() {
    return (100 * pow(level.toDouble(), 1.5)).toDouble();
  }

  void updateTitle() {
    if (level <= 5) {
      title = "Novice Adventurer";
    } else if (level <= 10) title = "Grit-Forger";
    else if (level <= 15) title = "Mindful Master";
    else if (level <= 20) title = "Skill Sage";
    else title = "Legendary Hero";
  }
}
