import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/user.dart';
import 'dart:math';
import 'dart:collection';

class WalletScreen extends StatefulWidget {
  final String uid;
  const WalletScreen({super.key, required this.uid});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedDurationInDays = 7;
  final List<int> _durationOptions = [7, 30, 84, 180, 365];
  final List<String> _durationLabels = ['7D', '30D', '12W', '6M', '1Y'];

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- MODIFIED: Unified dialog for adding and editing expenses ---
  void _showExpenseDialog({Expense? expense}) {
    final bool isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: isEditing ? expense.amount.toString() : '');
    final descriptionController = TextEditingController(text: isEditing ? expense.description : '');
    final paymentMethodController = TextEditingController(text: isEditing ? expense.paymentMethod : 'Cash');
    ExpenseCategory selectedCategory = isEditing ? expense.category : ExpenseCategory.food;
    DateTime selectedDate = isEditing ? expense.timestamp.toDate() : DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? "Edit Expense" : "Add New Expense"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: "Amount", prefixText: "\$"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? "Invalid amount" : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ExpenseCategory>(
                        value: selectedCategory,
                        items: ExpenseCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(ExpenseCategoryInfo.map[category]!.icon, size: 20),
                                const SizedBox(width: 8),
                                Text(ExpenseCategoryInfo.map[category]!.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setDialogState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      // --- NEW: Date and Time Pickers ---
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Date: ${DateFormat.yMMMd().format(selectedDate)}"),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != selectedDate) {
                            setDialogState(() {
                              selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute);
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Time: ${DateFormat.jm().format(selectedDate)}"),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: paymentMethodController,
                        decoration: const InputDecoration(labelText: "Payment Method"),
                        validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: "Note / Description"),
                        validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final firestore = FirebaseFirestore.instance;
                      final userRef = firestore.collection('users').doc(widget.uid);

                      final expenseData = {
                        'amount': double.parse(amountController.text),
                        'description': descriptionController.text,
                        'timestamp': Timestamp.fromDate(selectedDate),
                        'category': selectedCategory.toString().split('.').last,
                        'paymentMethod': paymentMethodController.text,
                      };

                      if (isEditing) {
                        // Just update the expense details, keep rewards the same
                        await userRef.collection('expenses').doc(expense.id).update(expenseData);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Expense updated!"), backgroundColor: Colors.blue),
                          );
                        }
                      } else {
                        // Add new expense and grant rewards
                        final random = Random();
                        final goldReward = 5 + random.nextInt(21);
                        final expReward = 10 + random.nextInt(41);
                        expenseData['goldReward'] = goldReward;
                        expenseData['expReward'] = expReward;

                        try {
                          final userDoc = await userRef.get();
                          if (!userDoc.exists) throw Exception("User not found");

                          final user = User.fromFirestore(userDoc);
                          user.gold += goldReward;
                          user.exp += expReward;

                          while(user.exp >= user.nextLevelExp()){
                            user.exp -= user.nextLevelExp();
                            user.level++;
                            user.unassignedStatPoints += 3;
                            user.updateTitle();
                          }

                          final newExpenseRef = userRef.collection('expenses').doc();
                          final batch = firestore.batch();
                          batch.set(newExpenseRef, expenseData);
                          batch.update(userRef, user.toMap());
                          await batch.commit();

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Expense added! +$goldReward Gold, +$expReward EXP"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if(mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to add expense: $e"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    }
                  },
                  child: Text(isEditing ? "Save" : "Add"),
                )
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('This will also remove the Gold and EXP you earned. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(widget.uid);
      final expenseRef = userRef.collection('expenses').doc(expense.id);

      try {
        final userDoc = await userRef.get();
        if (!userDoc.exists) throw Exception("User not found");

        final user = User.fromFirestore(userDoc);

        user.gold -= expense.goldReward;
        user.exp -= expense.expReward;

        if (user.gold < 0) user.gold = 0;
        if (user.exp < 0) user.exp = 0;

        final batch = firestore.batch();
        batch.delete(expenseRef);
        batch.update(userRef, user.toMap());
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Expense deleted and rewards reversed."),
              backgroundColor: Colors.orange,
            ),
          );
        }

      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete expense: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search by note...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white70)
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        )
            : const Text("Records"),
        actions: _isSearching
            ? [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            },
          ),
        ]
            : [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDurationFilters(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseDialog,
        tooltip: "Add Expense",
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(icon: const Icon(Icons.show_chart), onPressed: () {}),
            const SizedBox(width: 48), // The space for the FAB
            IconButton(icon: const Icon(Icons.pie_chart), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SegmentedButton<int>(
        segments: List.generate(_durationOptions.length, (index) {
          return ButtonSegment<int>(
            value: _durationOptions[index],
            label: Text(_durationLabels[index]),
          );
        }),
        selected: {_selectedDurationInDays},
        onSelectionChanged: (Set<int> newSelection) {
          setState(() {
            _selectedDurationInDays = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildTransactionList() {
    final queryDate = DateTime.now().subtract(Duration(days: _selectedDurationInDays));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('expenses')
          .where('timestamp', isGreaterThanOrEqualTo: queryDate)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var expenses = snapshot.data!.docs.map((doc) => Expense.fromFirestore(doc)).toList();

        if (_searchQuery.isNotEmpty) {
          expenses = expenses.where((expense) {
            return expense.description.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (expenses.isEmpty) {
          return Center(child: Text(_searchQuery.isNotEmpty ? "No results found." : "No expenses recorded in this period."));
        }

        final totalExpense = expenses.fold(0.0, (sum, item) => sum + item.amount);
        final groupedExpenses = _groupExpensesByDay(expenses);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("TOTAL SPENT", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text("-\$${totalExpense.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.redAccent)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: groupedExpenses.keys.length,
                itemBuilder: (context, index) {
                  final dateHeader = groupedExpenses.keys.elementAt(index);
                  final dailyExpenses = groupedExpenses[dateHeader]!;
                  final dailyTotal = dailyExpenses.fold(0.0, (sum, item) => sum + item.amount);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateHeader.toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text("-\$${dailyTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      ...dailyExpenses.map((expense) => _buildExpenseTile(expense)).toList(),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  LinkedHashMap<String, List<Expense>> _groupExpensesByDay(List<Expense> expenses) {
    final formatter = DateFormat.yMMMd();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = LinkedHashMap<String, List<Expense>>();

    for (var expense in expenses) {
      final date = expense.timestamp.toDate();
      final dayKey = DateTime(date.year, date.month, date.day);

      String header;
      if (dayKey == today) {
        header = 'Today';
      } else if (dayKey == yesterday) {
        header = 'Yesterday';
      } else {
        header = formatter.format(date);
      }

      (map[header] ??= []).add(expense);
    }
    return map;
  }

  Widget _buildExpenseTile(Expense expense) {
    final categoryInfo = ExpenseCategoryInfo.map[expense.category]!;

    return ListTile(
      onTap: () => _showExpenseDialog(expense: expense), // --- MODIFIED: Tap to edit ---
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade800,
        child: Icon(categoryInfo.icon, color: Colors.white, size: 20),
      ),
      title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(categoryInfo.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "-\$${expense.amount.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () => _deleteExpense(expense),
            tooltip: 'Delete Expense',
          ),
        ],
      ),
    );
  }
}

