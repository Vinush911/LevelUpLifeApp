import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/item.dart';

class InventoryScreen extends StatelessWidget {
  final String uid;
  const InventoryScreen({super.key, required this.uid});

  static const Map<String, Color> _rarityColors = {
    'COMMON': Colors.grey,
    'RARE': Colors.cyanAccent,
    'LEGENDARY': Colors.amber,
  };

  static const Map<ItemType, IconData> _typeIcons = {
    ItemType.equipment: Icons.shield,
    ItemType.cosmetic: Icons.color_lens,
    ItemType.consumable: Icons.local_drink,
  };

  Future<void> _equipItem(BuildContext context, String itemId, EquipmentSlot slot) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.update({'equippedItems.${slot.name}': itemId});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Item Equipped! ⚔️", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green
          )
      );
    }
  }

  Future<void> _unequipItem(BuildContext context, EquipmentSlot slot) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.update({'equippedItems.${slot.name}': FieldValue.delete()});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Item Unequipped.", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.orangeAccent,
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Inventory", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }
            final user = User.fromFirestore(userSnapshot.data);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('shop_items').snapshots(),
              builder: (context, itemSnapshot) {
                if (!itemSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                }

                final allItems = itemSnapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final item = Item.fromFirestore(doc);
                  final rarity = data['rarity'] as String? ?? 'COMMON';
                  return {'item': item, 'rarity': rarity};
                }).toList();

                final userItems = allItems.where((data) => user.purchasedItems.contains((data['item'] as Item).id)).toList();

                if (userItems.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0).copyWith(bottom: 40),
                  itemCount: userItems.length,
                  itemBuilder: (context, index) {
                    final itemData = userItems[index];
                    final item = itemData['item'] as Item;
                    final rarity = itemData['rarity'] as String;
                    final bool isEquipped = user.equippedItems.containsValue(item.id);
                    final rarityColor = _rarityColors[rarity] ?? Colors.grey.shade400;

                    return _buildItemCard(context, item, rarityColor, isEquipped);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          const Text(
            "Your pack is empty.",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Visit the Merchant's Shop to gear up!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Item item, Color rarityColor, bool isEquipped) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: rarityColor.withOpacity(isEquipped ? 0.8 : 0.3),
            width: isEquipped ? 2 : 1.5
        ),
        boxShadow: [
          if (isEquipped)
            BoxShadow(color: rarityColor.withOpacity(0.15), blurRadius: 15, spreadRadius: 1)
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: rarityColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_typeIcons[item.type] ?? Icons.help_outline, color: rarityColor, size: 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, letterSpacing: 0.5)
              ),
            ),
            if (isEquipped)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: rarityColor.withOpacity(0.5))
                ),
                child: Text("EQUIPPED", style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              )
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(item.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.3)),
        ),
        trailing: _buildTrailingWidget(context, item, isEquipped, rarityColor),
      ),
    );
  }

  Widget? _buildTrailingWidget(BuildContext context, Item item, bool isEquipped, Color rarityColor) {
    if (item.type == ItemType.equipment) {
      return ElevatedButton(
        onPressed: () {
          if (isEquipped) {
            _unequipItem(context, item.slot!);
          } else {
            _equipItem(context, item.id, item.slot!);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isEquipped ? Colors.grey.shade800 : rarityColor.withOpacity(0.2),
          foregroundColor: isEquipped ? Colors.white : rarityColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: isEquipped ? Colors.transparent : rarityColor.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
            isEquipped ? "Unequip" : "Equip",
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
      );
    } else if (item.type == ItemType.cosmetic) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.purpleAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
        ),
        child: const Text("COSMETIC", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
      );
    }
    return null;
  }
}