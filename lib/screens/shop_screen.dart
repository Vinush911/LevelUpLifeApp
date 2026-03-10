import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/item.dart';

class ShopScreen extends StatefulWidget {
  final String uid;
  const ShopScreen({super.key, required this.uid});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Future<void> _buyItem(BuildContext context, User user, Item item) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);

    if (user.gold < item.price || user.purchasedItems.contains(item.id)) {
      String message = user.purchasedItems.contains(item.id)
          ? "You already own this item."
          : "Not enough gold, Adventurer.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.orangeAccent
        ),
      );
      return;
    }

    try {
      await firestore.runTransaction((transaction) async {
        final freshUserDoc = await transaction.get(userRef);
        final freshUser = User.fromFirestore(freshUserDoc);

        if (freshUser.gold >= item.price) {
          transaction.update(userRef, {
            'gold': FieldValue.increment(-item.price),
            'purchasedItems': FieldValue.arrayUnion([item.id]),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Successfully purchased ${item.name}!", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error purchasing item: $e");
    }
  }

  Future<void> _equipCosmetic(BuildContext context, String itemId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'equippedBorderId': itemId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Cosmetic equipped successfully!", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.cyan
          ),
        );
      }
    } catch (e) {
      debugPrint("Error equipping cosmetic: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Merchant's Shop", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }
            final user = User.fromFirestore(userSnapshot.data);

            return Column(
              children: [
                _buildTreasuryHeader(user.gold),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('shop_items')
                        .where('price', isGreaterThan: 0)
                        .snapshots(),
                    builder: (context, itemSnapshot) {
                      if (!itemSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                      }

                      final items = itemSnapshot.data!.docs.map((doc) => Item.fromFirestore(doc)).toList();

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text("The shop is currently empty.", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 40),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isPurchased = user.purchasedItems.contains(item.id);
                          final canAfford = user.gold >= item.price;
                          final isCosmeticEquipped = user.equippedBorderId == item.id;

                          return _buildShopItemCard(context, user, item,
                              isPurchased, canAfford, isCosmeticEquipped);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTreasuryHeader(int gold) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.15), blurRadius: 15, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("AVAILABLE WEALTH", style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text(
                "$gold Gold",
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 24,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemCard(BuildContext context, User user,
      Item item, bool isPurchased, bool canAfford, bool isCosmeticEquipped) {

    Widget trailingWidget;
    Color borderColor = Colors.purpleAccent.withOpacity(0.3);

    if (isPurchased) {
      if(item.type == ItemType.cosmetic) {
        if (isCosmeticEquipped) {
          borderColor = Colors.cyanAccent.withOpacity(0.5);
          trailingWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyanAccent),
            ),
            child: const Text("EQUIPPED", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          );
        } else {
          borderColor = Colors.green.withOpacity(0.5);
          trailingWidget = ElevatedButton(
            onPressed: () => _equipCosmetic(context, item.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.cyanAccent,
              elevation: 0,
              side: const BorderSide(color: Colors.cyanAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Equip", style: TextStyle(fontWeight: FontWeight.bold)),
          );
        }
      } else {
        borderColor = Colors.green.withOpacity(0.5);
        trailingWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: const Text("OWNED", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        );
      }
    } else {
      trailingWidget = ElevatedButton.icon(
        icon: Icon(Icons.monetization_on, size: 18, color: canAfford ? Colors.black : Colors.grey.shade400),
        label: Text(
            item.price.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: canAfford ? Colors.black : Colors.grey.shade400)
        ),
        onPressed: canAfford ? () => _buyItem(context, user, item) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          disabledBackgroundColor: Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: canAfford ? 4 : 0,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF16213E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            if (isCosmeticEquipped)
              BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
          ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.type == ItemType.equipment ? Icons.shield_outlined : Icons.color_lens_outlined,
            color: Colors.purpleAccent.shade100,
            size: 28,
          ),
        ),
        title: Text(
            item.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
              item.description,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.3)
          ),
        ),
        trailing: trailingWidget,
      ),
    );
  }
}