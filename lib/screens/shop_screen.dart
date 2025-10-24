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
          : "Not enough gold.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.orange),
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
              content: Text("${item.name} purchased!"),
              backgroundColor: Colors.green),
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
              content: Text("Cosmetic equipped!"), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      debugPrint("Error equipping cosmetic: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Item Shop"),
        backgroundColor: const Color(0xFF0F3460),
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = User.fromFirestore(userSnapshot.data);

          return Column(
            children: [
              _buildTreasuryHeader(user.gold),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // *** THE FIX IS HERE: Changed 'items' to 'shop_items' ***
                  stream: FirebaseFirestore.instance
                      .collection('shop_items')
                      .where('price', isGreaterThan: 0)
                      .snapshots(),
                  builder: (context, itemSnapshot) {
                    if (!itemSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = itemSnapshot.data!.docs.map((doc) => Item.fromFirestore(doc)).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
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
    );
  }

  Widget _buildTreasuryHeader(int gold) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF16213E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Text(
            gold.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemCard(BuildContext context, User user,
      Item item, bool isPurchased, bool canAfford, bool isCosmeticEquipped) {

    Widget trailingWidget;

    if (isPurchased) {
      if(item.type == ItemType.cosmetic) {
        trailingWidget = isCosmeticEquipped
            ? const Chip(label: Text("EQUIPPED"), backgroundColor: Colors.blueAccent)
            : ElevatedButton(
          onPressed: () => _equipCosmetic(context, item.id),
          child: const Text("Equip"),
        );
      } else {
        trailingWidget = const Chip(label: Text("OWNED"), backgroundColor: Colors.green);
      }
    } else {
      trailingWidget = ElevatedButton.icon(
        icon: const Icon(Icons.monetization_on_outlined, size: 20),
        label: Text(item.price.toString()),
        onPressed: canAfford ? () => _buyItem(context, user, item) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade700,
        ),
      );
    }

    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(
          item.type == ItemType.equipment ? Icons.shield_outlined : Icons.color_lens_outlined,
          color: Colors.purpleAccent,
        ),
        title: Text(item.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(item.description,
            style: TextStyle(color: Colors.grey.shade400)),
        trailing: trailingWidget,
      ),
    );
  }
}

