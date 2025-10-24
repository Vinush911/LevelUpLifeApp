// A new model to represent all items in the game
import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemType { cosmetic, equipment, consumable }
enum EquipmentSlot { amulet, boots }

class Item {
  final String id;
  final String name;
  final String description;
  final int price;
  final ItemType type;
  final EquipmentSlot? slot; // Only for equipment
  final Map<String, dynamic> effects; // e.g., {'stat': 'WIS', 'value': 5}

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.type,
    this.slot,
    required this.effects,
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toInt(),
      type: ItemType.values.firstWhere(
            (e) => e.toString() == 'ItemType.${data['type']}',
        orElse: () => ItemType.cosmetic,
      ),
      slot: data['slot'] != null
          ? EquipmentSlot.values.firstWhere(
              (e) => e.toString() == 'EquipmentSlot.${data['slot']}',
          orElse: () => EquipmentSlot.amulet)
          : null,
      effects: Map<String, dynamic>.from(data['effects'] ?? {}),
    );
  }
}
