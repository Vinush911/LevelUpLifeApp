import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/item.dart';
import 'dart:math';
import 'dart:async';

class GachaScreen extends StatefulWidget {
  final String uid;
  const GachaScreen({super.key, required this.uid});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> with TickerProviderStateMixin {
  bool _isOpening = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _particleController;

  Map<String, dynamic>? _winningReward;
  List<Map<String, dynamic>>? _winningMultiRewards;

  final Map<String, Color> _rarityColors = {
    'COMMON': Colors.grey.shade400,
    'RARE': Colors.blueAccent,
    'LEGENDARY': Colors.amber,
  };

  final Map<String, int> _rarityWeights = {
    'COMMON': 100,
    'RARE': 25,
    'LEGENDARY': 5,
  };

  static const int _legendaryPityThreshold = 50;

  Map<String, String> get _dropRates {
    final totalWeight = _rarityWeights.values.reduce((a, b) => a + b);
    return _rarityWeights.map((key, value) {
      final percentage = (value / totalWeight * 100).toStringAsFixed(1);
      return MapEntry(key, '$percentage%');
    });
  }

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_winningReward != null) {
          _showRewardDialog(_winningReward!);
        }
        if (_winningMultiRewards != null) {
          _showMultiRewardDialog(_winningMultiRewards!);
        }
        setState(() {
          _isOpening = false;
          _winningReward = null;
          _winningMultiRewards = null;
        });
        _shakeController.reset();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _showRewardDialog(Map<String, dynamic> reward) {
    final rewardName = reward['name'] as String? ?? 'A Prize';
    final rewardMessage = reward['rewardMessage'] as String? ?? '';
    final rarity = reward['rarity'] as String? ?? 'COMMON';
    final glowColor = _rarityColors[rarity] ?? Colors.grey;
    final canAffordAnother = (reward['userGold'] as int? ?? 0) >= 500;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: glowColor.withOpacity(0.8), width: 2),
            boxShadow: [BoxShadow(color: glowColor.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: glowColor, size: 48),
              const SizedBox(height: 16),
              Text(
                  "You won:\n$rewardName",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: glowColor, letterSpacing: 1.2, height: 1.3)
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(rewardMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.white70)),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: canAffordAnother ? () {
                      Navigator.pop(context);
                      _openTreasureChest();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: glowColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text("Pull Again", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMultiRewardDialog(List<Map<String, dynamic>> rewards) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
        ),
        title: const Center(
          child: Text("10-Pull Results", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: rewards.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final rewardName = reward['name'] as String? ?? 'A Prize';
              final rarity = reward['rarity'] as String? ?? 'COMMON';
              final color = _rarityColors[rarity] ?? Colors.grey;
              final message = reward['rewardMessage'] as String? ?? '';

              return Card(
                color: const Color(0xFF0F3460).withOpacity(0.5),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withOpacity(0.4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Icon(Icons.star, color: color, size: 20),
                  title: Text(rewardName, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ),
              );
            },
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text("Awesome!", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showDropRatesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
        ),
        title: const Text("Drop Rates", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._dropRates.entries.map((entry) {
              final color = _rarityColors[entry.key] ?? Colors.grey;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle, color: color, size: 16),
                title: Text(entry.key, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                trailing: Text(entry.value, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              );
            }),
            const Divider(height: 32, color: Colors.white24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        "A LEGENDARY item is guaranteed within 50 pulls.",
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70, fontSize: 13)
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.grey))
          )
        ],
      ),
    );
  }

  Future<void> _openTreasureChest() async {
    setState(() => _isOpening = true);
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);
    const chestPrice = 500;

    try {
      final gachaItemsSnapshot = await firestore.collection('gacha_items').get();
      final gachaItems = gachaItemsSnapshot.docs;
      if (gachaItems.isEmpty) throw Exception("No gacha items configured.");

      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final user = User.fromFirestore(userDoc);
        if (user.gold < chestPrice) throw Exception("Not enough gold!");

        user.gold -= chestPrice;
        user.gachaPityCounter++;

        DocumentSnapshot winningDoc;
        if (user.gachaPityCounter >= _legendaryPityThreshold) {
          final legendaryItems = gachaItems.where((doc) => doc.get('rarity') == 'LEGENDARY').toList();
          if (legendaryItems.isNotEmpty) {
            winningDoc = legendaryItems[Random().nextInt(legendaryItems.length)];
          } else {
            winningDoc = gachaItems[Random().nextInt(gachaItems.length)];
          }
        } else {
          List<DocumentSnapshot> weightedList = [];
          for (var doc in gachaItems) {
            final rarity = doc.get('rarity') as String? ?? 'COMMON';
            final weight = _rarityWeights[rarity] ?? 100;
            for (int i = 0; i < weight; i++) {
              weightedList.add(doc);
            }
          }
          winningDoc = weightedList[Random().nextInt(weightedList.length)];
        }

        final reward = winningDoc.data() as Map<String, dynamic>;
        String rewardMessage = _applyReward(user, reward);

        if (reward['rarity'] == 'LEGENDARY') {
          user.gachaPityCounter = 0;
        }

        transaction.update(userRef, user.toMap());
        _winningReward = {...reward, 'rewardMessage': rewardMessage, 'userGold': user.gold};
      });
      _startAnimation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent)
        );
      }
      setState(() => _isOpening = false);
    }
  }

  Future<void> _openTenTreasureChests() async {
    setState(() => _isOpening = true);
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);
    const chestPrice = 5000;

    try {
      final gachaItemsSnapshot = await firestore.collection('gacha_items').get();
      final gachaItems = gachaItemsSnapshot.docs;
      if (gachaItems.isEmpty) throw Exception("No gacha items configured.");

      List<Map<String, dynamic>> results = [];
      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final user = User.fromFirestore(userDoc);
        if (user.gold < chestPrice) throw Exception("Not enough gold for a 10-pull!");

        user.gold -= chestPrice;

        List<DocumentSnapshot> weightedList = [];
        for (var doc in gachaItems) {
          final rarity = doc.get('rarity') as String? ?? 'COMMON';
          final weight = _rarityWeights[rarity] ?? 100;
          for (int i = 0; i < weight; i++) {
            weightedList.add(doc);
          }
        }

        bool hasGuaranteedRare = false;
        final random = Random();

        for (int i = 0; i < 10; i++) {
          user.gachaPityCounter++;
          DocumentSnapshot winningDoc;

          if (user.gachaPityCounter >= _legendaryPityThreshold) {
            final legendaryItems = gachaItems.where((doc) => doc.get('rarity') == 'LEGENDARY').toList();
            winningDoc = legendaryItems.isNotEmpty ? legendaryItems[random.nextInt(legendaryItems.length)] : weightedList[random.nextInt(weightedList.length)];
          } else {
            winningDoc = weightedList[random.nextInt(weightedList.length)];
          }

          final reward = winningDoc.data() as Map<String, dynamic>;
          String message = _applyReward(user, reward);
          results.add({...reward, 'rewardMessage': message});

          if (reward['rarity'] == 'RARE' || reward['rarity'] == 'LEGENDARY') hasGuaranteedRare = true;
          if (reward['rarity'] == 'LEGENDARY') user.gachaPityCounter = 0;
        }

        if (!hasGuaranteedRare) {
          final rareItems = gachaItems.where((doc) => doc.get('rarity') == 'RARE').toList();
          if (rareItems.isNotEmpty) {
            final guaranteedRareDoc = rareItems[random.nextInt(rareItems.length)];
            final guaranteedRareReward = guaranteedRareDoc.data();
            _applyReward(user, results.last, reverse: true);
            String message = _applyReward(user, guaranteedRareReward);
            results[9] = {...guaranteedRareReward, 'rewardMessage': message};
          }
        }
        transaction.update(userRef, user.toMap());
        _winningMultiRewards = results;
      });
      _startAnimation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent)
        );
      }
      setState(() => _isOpening = false);
    }
  }

  String _applyReward(User user, Map<String, dynamic> reward, {bool reverse = false}) {
    final int multiplier = reverse ? -1 : 1;
    final rewardType = reward['type'] as String? ?? '';
    final rarity = reward['rarity'] as String? ?? 'COMMON';
    String message = '';

    switch (rewardType) {
      case 'ITEM':
        final itemId = reward['itemId'] as String?;
        if (itemId != null) {
          if (user.purchasedItems.contains(itemId) && !reverse) {
            final shardAmount = {'COMMON': 1, 'RARE': 5, 'LEGENDARY': 25}[rarity] ?? 1;
            user.gachaShards += shardAmount;
            message = "Duplicate! +$shardAmount Shards";
          } else {
            if (reverse) {
              user.purchasedItems.remove(itemId);
            } else {
              user.purchasedItems.add(itemId);
            }
            message = "Added to your inventory!";
          }
        }
        break;
      case 'GOLD':
        final goldAmount = (reward['value'] as num? ?? 0).toInt();
        user.gold += goldAmount * multiplier;
        message = "Your new balance is ${user.gold} Gold!";
        break;
      case 'EXP':
        final expAmount = (reward['value'] as num? ?? 0).toDouble();
        user.exp += expAmount * multiplier;
        message = "You've made progress!";
        break;
    }
    return message;
  }

  void _startAnimation() async {
    _shakeController.repeat();
    await Future.delayed(const Duration(seconds: 2));
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Summoning Altar", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final user = User.fromFirestore(snapshot.data);
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(user.gold.toString(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Animated particle background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: ParticlePainter(progress: _particleController.value),
              );
            },
          ),
          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeaturedItemsCarousel(),
                  const SizedBox(height: 50),

                  // Treasure Chest
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) => Transform.rotate(
                        angle: _isOpening ? _shakeAnimation.value : 0,
                        child: child
                    ),
                    child: _buildTreasureChest(),
                  ),

                  const SizedBox(height: 30),
                  const Text(
                      "Call Upon The Fates",
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [Shadow(blurRadius: 15, color: Colors.purpleAccent)]
                      )
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Discover legendary artifacts and untold riches.",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  if (_isOpening)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  else
                    Column(
                      children: [
                        ElevatedButton.icon(
                            icon: const Icon(Icons.key),
                            onPressed: _openTreasureChest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                              shadowColor: Colors.amber.withOpacity(0.5),
                            ),
                            label: const Text("Open Chest (500G)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1))
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                            icon: const Icon(Icons.vpn_key),
                            onPressed: _openTenTreasureChests,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                              shadowColor: Colors.purpleAccent.withOpacity(0.5),
                            ),
                            label: const Text("Open 10 Chests (5000G)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1))
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                            icon: const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                            onPressed: _showDropRatesDialog,
                            label: const Text("View Drop Rates", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1))
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedItemsCarousel() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber.shade200, size: 18),
            const SizedBox(width: 8),
            const Text(
                "FEATURED RELICS",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)
            ),
            const SizedBox(width: 8),
            Icon(Icons.auto_awesome, color: Colors.amber.shade200, size: 18),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gacha_items')
                .where('rarity', whereIn: ['RARE', 'LEGENDARY'])
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
              final items = snapshot.data!.docs;
              if(items.isEmpty) return const Center(child: Text("No featured items available.", style: TextStyle(color: Colors.grey)));

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = items[index].data() as Map<String, dynamic>;
                  final name = item['name'] as String? ?? 'Item';
                  final rarity = item['rarity'] as String? ?? 'RARE';
                  final color = _rarityColors[rarity] ?? Colors.grey;

                  return AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF16213E).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withOpacity(0.6), width: 2),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)
                          ]
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, color: color, size: 28),
                            const SizedBox(height: 8),
                            Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)
                            ),
                          ]
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTreasureChest() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glowing aura behind chest
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 50, spreadRadius: 20),
                BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 80, spreadRadius: 40),
              ]
          ),
        ),
        const Icon(
          Icons.shield_moon,
          size: 130,
          color: Colors.amber,
          shadows: [
            Shadow(color: Colors.yellowAccent, blurRadius: 20),
            Shadow(color: Colors.black, blurRadius: 30, offset: Offset(0, 10))
          ],
        ),
      ],
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double progress;
  final List<Particle> particles = [];
  final Random random = Random();

  ParticlePainter({required this.progress}) {
    for (int i = 0; i < 30; i++) {
      particles.add(Particle(random));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(0.5);

      final offset = Offset(
        (particle.x * size.width) + sin(progress * 2 * pi / particle.speed) * 20,
        (particle.y * size.height * (1 - progress)) - (size.height * (1 - progress)),
      );

      canvas.drawCircle(offset, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final Color color;

  Particle(Random random)
      : x = random.nextDouble(),
        y = random.nextDouble(),
        radius = random.nextDouble() * 2 + 1,
        speed = random.nextDouble() * 4 + 2,
        color = [Colors.purpleAccent, Colors.cyanAccent, Colors.amber].elementAt(random.nextInt(3));
}