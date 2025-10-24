import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/item.dart';

class InventoryScreen extends StatelessWidget {
  final String uid;
  const InventoryScreen({super.key, required this.uid});

  // --- FIX: Changed 'final' to 'static const' ---
  static const Map<String, Color> _rarityColors = {
    'COMMON': Colors.grey,
    'RARE': Colors.blueAccent,
    'LEGENDARY': Colors.amber,
  };

  // --- FIX: Changed 'final' to 'static const' ---
  static const Map<ItemType, IconData> _typeIcons = {
    ItemType.equipment: Icons.shield,
    ItemType.cosmetic: Icons.color_lens,
    ItemType.consumable: Icons.local_drink,
  };

  Future<void> _equipItem(BuildContext context, String itemId, EquipmentSlot slot) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.update({'equippedItems.${slot.name}': itemId});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item Equipped!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _unequipItem(BuildContext context, EquipmentSlot slot) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.update({'equippedItems.${slot.name}': FieldValue.delete()});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item Unequipped!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      backgroundColor: const Color(0xFF1A1A2E), // Match the theme
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = User.fromFirestore(userSnapshot.data);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('shop_items').snapshots(),
            builder: (context, itemSnapshot) {
              if (!itemSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final allItems = itemSnapshot.data!.docs.map((doc) {
                // Also fetch rarity for styling
                final data = doc.data() as Map<String, dynamic>;
                final item = Item.fromFirestore(doc);
                final rarity = data['rarity'] as String? ?? 'COMMON';
                return {'item': item, 'rarity': rarity};
              }).toList();

              final userItems = allItems.where((data) => user.purchasedItems.contains((data['item'] as Item).id)).toList();

              if (userItems.isEmpty) {
                return const Center(
                  child: Text("Your inventory is empty.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: userItems.length,
                itemBuilder: (context, index) {
                  final itemData = userItems[index];
                  final item = itemData['item'] as Item;
                  final rarity = itemData['rarity'] as String;
                  final bool isEquipped = user.equippedItems.containsValue(item.id);
                  final rarityColor = _rarityColors[rarity] ?? Colors.grey;

                  return Card(
                    color: const Color(0xFF16213E).withOpacity(0.8),
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: rarityColor.withOpacity(0.5), width: 1),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rarityColor.withOpacity(0.2),
                        child: Icon(_typeIcons[item.type] ?? Icons.help, color: rarityColor),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text(item.description, style: TextStyle(color: Colors.grey.shade400)),
                      trailing: _buildTrailingWidget(context, item, isEquipped),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- NEW: Helper widget to build the trailing button/chip ---
  Widget? _buildTrailingWidget(BuildContext context, Item item, bool isEquipped) {
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
          backgroundColor: isEquipped ? Colors.grey.shade700 : Colors.purpleAccent,
          foregroundColor: isEquipped ? Colors.white : Colors.black,
        ),
        child: Text(isEquipped ? "Unequip" : "Equip"),
      );
    } else if (item.type == ItemType.cosmetic) {
      // Future-proofing for when you add cosmetic equipping logic
      return const Chip(label: Text("COSMETIC"), backgroundColor: Colors.blueGrey);
    }
    return null; // For consumables or other types
  }
}

