import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Enum for expense categories
enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  entertainment,
  other,
}

// Helper class to get display names and icons for categories
class ExpenseCategoryInfo {
  final String name;
  final IconData icon;

  ExpenseCategoryInfo(this.name, this.icon);

  static Map<ExpenseCategory, ExpenseCategoryInfo> get map => {
    ExpenseCategory.food: ExpenseCategoryInfo('Restaurant, fast-food', Icons.fastfood),
    ExpenseCategory.transport: ExpenseCategoryInfo('Transport', Icons.directions_car),
    ExpenseCategory.shopping: ExpenseCategoryInfo('Shopping', Icons.shopping_bag),
    ExpenseCategory.bills: ExpenseCategoryInfo('Bills & Utilities', Icons.receipt),
    ExpenseCategory.entertainment: ExpenseCategoryInfo('Entertainment', Icons.movie),
    ExpenseCategory.other: ExpenseCategoryInfo('Other', Icons.category),
  };
}

class Expense {
  final String id;
  final double amount;
  final String description;
  final Timestamp timestamp;
  final ExpenseCategory category;
  final String paymentMethod;
  // --- NEW: Fields to store rewards ---
  final int goldReward;
  final int expReward;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.category,
    required this.paymentMethod,
    required this.goldReward,
    required this.expReward,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num? ?? 0).toDouble(),
      description: data['description'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      category: ExpenseCategory.values.firstWhere(
            (e) => e.toString().split('.').last == data['category'],
        orElse: () => ExpenseCategory.other,
      ),
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      // --- NEW: Read rewards from Firestore ---
      goldReward: (data['goldReward'] as num? ?? 0).toInt(),
      expReward: (data['expReward'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'description': description,
      'timestamp': timestamp,
      'category': category.toString().split('.').last,
      'paymentMethod': paymentMethod,
      'goldReward': goldReward,
      'expReward': expReward,
    };
  }
}

