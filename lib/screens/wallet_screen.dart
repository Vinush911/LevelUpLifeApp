import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/user.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/unlock_overlay.dart';

// --- UPDATED ENUM for precise grouping filters ---
enum ExpenseFilter { thisWeek, thisMonth, sixMonths, year }

class WalletScreen extends StatefulWidget {
  final String uid;
  const WalletScreen({super.key, required this.uid});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {

  ExpenseFilter _selectedFilter = ExpenseFilter.thisWeek;
  late TabController _tabController;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- FILTER LOGIC ---
  bool _matchesFilter(Expense expense) {
    final date = expense.timestamp.toDate();
    final now = DateTime.now();

    switch (_selectedFilter) {
      case ExpenseFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return date.isAfter(startOfWeekDate.subtract(const Duration(seconds: 1)));
      case ExpenseFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case ExpenseFilter.sixMonths:
        final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
        return date.isAfter(sixMonthsAgo);
      case ExpenseFilter.year:
        return date.year == now.year;
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text("Delete Expense?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this expense record?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('expenses')
          .doc(expense.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense deleted"), backgroundColor: Colors.amber),
        );
      }
    }
  }

  void _showExpenseDialog({Expense? expense}) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: expense?.amount.toString() ?? '');
    final descController = TextEditingController(text: expense?.description ?? '');
    ExpenseCategory selectedCategory = expense?.category ?? ExpenseCategory.food;
    String selectedPaymentMethod = expense?.paymentMethod ?? 'UPI';

    // 1️⃣ INITIALIZE STATE: Default to the existing expense time, or 'now' if it's new.
    // Placing it OUTSIDE the StatefulBuilder ensures it doesn't reset when the UI redraws.
    DateTime selectedDate = expense?.timestamp.toDate() ?? DateTime.now();

    final paymentMethods = ['Cash', 'Card', 'UPI', 'Net Banking', 'Other'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.purpleAccent)),
            title: Text(expense == null ? "Add Expense" : "Edit Expense", style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Amount (₹)",
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.currency_rupee, color: Colors.purpleAccent),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter an amount";
                        if (double.tryParse(val) == null) return "Enter a valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Description",
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.description, color: Colors.purpleAccent),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ExpenseCategory>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF16213E),
                      style: const TextStyle(color: Colors.white),
                      items: ExpenseCategory.values.map((cat) {
                        final info = ExpenseCategoryInfo.map[cat]!;
                        return DropdownMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(info.icon, color: Colors.amber, size: 20),
                              const SizedBox(width: 10),
                              Text(info.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val!),
                      decoration: InputDecoration(
                        labelText: "Category",
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      dropdownColor: const Color(0xFF16213E),
                      style: const TextStyle(color: Colors.white),
                      items: paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
                      onChanged: (val) => setState(() => selectedPaymentMethod = val!),
                      decoration: InputDecoration(
                        labelText: "Payment Method",
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2️⃣ THE CUSTOM DATE/TIME PICKER
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(), // Prevent logging future expenses
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.purpleAccent,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF16213E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null && context.mounted) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );

                          if (pickedTime != null) {
                            // Update the local dialog state using the StatefulBuilder's setState
                            setState(() {
                              selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Date & Time",
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.purpleAccent),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy - h:mm a').format(selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final amount = double.parse(amountController.text);
                    final desc = descController.text.trim();

                    final expenseRef = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('expenses');

                    int goldReward = expense == null ? (amount * 0.05).toInt().clamp(1, 20) : 0;
                    int expReward = expense == null ? 10 : 0;

                    // 3️⃣ SAVE THE EXPLICIT DATE to Firestore
                    final data = {
                      'amount': amount,
                      'description': desc,
                      'category': selectedCategory.toString().split('.').last,
                      'paymentMethod': selectedPaymentMethod,
                      'timestamp': Timestamp.fromDate(selectedDate), // Replaced serverTimestamp
                      if (expense == null) 'goldReward': goldReward,
                      if (expense == null) 'expReward': expReward,
                    };

                    if (expense == null) {
                      await expenseRef.add(data);
                      // Reward user for logging expenses
                      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                        'gold': FieldValue.increment(goldReward),
                        'exp': FieldValue.increment(expReward),
                      });

                      // Log activity
                      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.uid)
                          .collection('activity_log')
                          .doc(todayStr)
                          .set({
                        'expensesLogged': FieldValue.increment(1),
                      }, SetOptions(merge: true));

                    } else {
                      await expenseRef.doc(expense.id).update(data);
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Save Expense", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search expenses...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        )
            : const Text("Wallet & Expenses"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: "Transactions"),
            Tab(icon: Icon(Icons.pie_chart), text: "Analytics"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text("Add Expense", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('expenses')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading data", style: TextStyle(color: Colors.red)));
          }

          List<Expense> allExpenses = snapshot.data!.docs.map((doc) => Expense.fromFirestore(doc)).toList();

          // 1. Filter Data
          List<Expense> filteredExpenses = allExpenses.where((e) {
            if (_searchQuery.isNotEmpty && !e.description.toLowerCase().contains(_searchQuery.toLowerCase())) {
              return false;
            }
            return _matchesFilter(e);
          }).toList();

          // 2. Nested Group Data
          Map<String, Map<String, List<Expense>>> mainGroups = {};

          for (var e in filteredExpenses) {
            final date = e.timestamp.toDate();
            final now = DateTime.now();

            String level1 = "";
            String level2 = "";

            if (_selectedFilter == ExpenseFilter.thisWeek) {
              level1 = "This Week";

              final today = DateTime(now.year, now.month, now.day);
              final expenseDate = DateTime(date.year, date.month, date.day);
              final diff = today.difference(expenseDate).inDays;

              if (diff == 0) level2 = "Today";
              else if (diff == 1) level2 = "Yesterday";
              else level2 = DateFormat('EEEE, MMM d').format(date);

            } else if (_selectedFilter == ExpenseFilter.thisMonth) {
              final firstDayOfMonth = DateTime(date.year, date.month, 1);
              int weekOfMonth = ((date.day + firstDayOfMonth.weekday - 2) / 7).floor() + 1;
              level1 = "Week $weekOfMonth";

              final today = DateTime(now.year, now.month, now.day);
              final expenseDate = DateTime(date.year, date.month, date.day);
              final diff = today.difference(expenseDate).inDays;

              if (diff == 0) level2 = "Today";
              else if (diff == 1) level2 = "Yesterday";
              else level2 = DateFormat('EEEE, MMM d').format(date);

            } else {
              level1 = DateFormat('MMMM yyyy').format(date);
              final firstDayOfMonth = DateTime(date.year, date.month, 1);
              int weekOfMonth = ((date.day + firstDayOfMonth.weekday - 2) / 7).floor() + 1;
              level2 = "Week $weekOfMonth";
            }

            mainGroups.putIfAbsent(level1, () => <String, List<Expense>>{});
            mainGroups[level1]!.putIfAbsent(level2, () => <Expense>[]);
            mainGroups[level1]![level2]!.add(e);
          }

          return Column(
            children: [
              Container(
                color: const Color(0xFF0F3460).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ExpenseFilter.values.map((filter) {
                      String label = "";
                      switch (filter) {
                        case ExpenseFilter.thisWeek: label = "This Week"; break;
                        case ExpenseFilter.thisMonth: label = "This Month"; break;
                        case ExpenseFilter.sixMonths: label = "6 Months"; break;
                        case ExpenseFilter.year: label = "This Year"; break;
                      }
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: Colors.purpleAccent.withOpacity(0.8),
                          backgroundColor: Colors.black38,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade400),
                          onSelected: (val) => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    filteredExpenses.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: mainGroups.length,
                      itemBuilder: (context, index) {
                        String level1Key = mainGroups.keys.elementAt(index);
                        Map<String, List<Expense>> subGroups = mainGroups[level1Key]!;

                        double level1Total = 0.0;
                        for (var expenses in subGroups.values) {
                          for (var e in expenses) {
                            level1Total += e.amount;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16213E).withOpacity(0.5),
                                border: Border(bottom: BorderSide(color: Colors.purpleAccent.withOpacity(0.3))),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month, color: Colors.amber, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          level1Key.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Total spent: ₹${level1Total.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ...subGroups.keys.map((level2Key) {
                              List<Expense> expensesInGroup = subGroups[level2Key]!;
                              double level2Total = expensesInGroup.fold(0.0, (sum, e) => sum + e.amount);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: EdgeInsets.fromLTRB(16, _selectedFilter == ExpenseFilter.thisWeek ? 16 : 12, 16, 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.today, color: Colors.purpleAccent.shade100, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              level2Key.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.purpleAccent.shade100,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          "-₹${level2Total.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...expensesInGroup.map((e) => _buildExpenseTile(e, _selectedFilter)),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    _buildAnalyticsTab(filteredExpenses),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            "No expenses found for this period.\nYour gold is safe!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, ExpenseFilter currentFilter) {
    final categoryInfo = ExpenseCategoryInfo.map[expense.category] ?? ExpenseCategoryInfo('Other', Icons.category);
    final timeLabel = DateFormat('EEE, MMM d, h:mm a').format(expense.timestamp.toDate());
    final colorIndex = expense.category.index % Colors.primaries.length;
    final catColor = Colors.primaries[colorIndex];

    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: catColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showExpenseDialog(expense: expense),
        onLongPress: () => _deleteExpense(expense),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(categoryInfo.icon, color: catColor, size: 24),
            ),
            title: Text(categoryInfo.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(expense.paymentMethod, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                  if (expense.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "\"${expense.description}\"",
                      style: TextStyle(color: Colors.grey.shade300, fontStyle: FontStyle.italic, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "-₹${expense.amount.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(List<Expense> filteredExpenses) {
    if (filteredExpenses.isEmpty) return _buildEmptyState();

    Map<ExpenseCategory, double> categoryTotals = {};
    double totalSpent = 0;

    for (var e in filteredExpenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
      totalSpent += e.amount;
    }

    List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      final info = ExpenseCategoryInfo.map[entry.key]!;
      final color = Colors.primaries[info.name.length % Colors.primaries.length];
      final percentage = (entry.value / totalSpent) * 100;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- SECTION 1: TOTAL SPENT ---
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                const Text("TOTAL SPENT", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text("₹${totalSpent.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- SECTION 2: BAR CHART ---
          _buildTrendChart(filteredExpenses),
          const SizedBox(height: 24),

          // --- SECTION 3: PIE CHART & CATEGORIES ---
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SPENDING BY CATEGORY", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: sections,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                ...categoryTotals.entries.map((entry) {
                  final info = ExpenseCategoryInfo.map[entry.key]!;
                  final color = Colors.primaries[info.name.length % Colors.primaries.length];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(info.icon, color: color),
                    ),
                    title: Text(info.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: Text("₹${entry.value.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- 2. THE BRAND NEW METHOD AT THE BOTTOM OF THE CLASS ---
  Widget _buildTrendChart(List<Expense> expenses) {
    List<String> labels = [];
    List<double> totals = [];
    final now = DateTime.now();
    String dateRangeLabel = "";

    // 🧠 FIND WHICH BAR IS "CURRENT" TO HIGHLIGHT IT!
    int currentIndex = -1;

    // DYNAMIC BUCKET GENERATION based on your selected filter!
    if (_selectedFilter == ExpenseFilter.thisWeek) {
      dateRangeLabel = "This Week";
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      totals = List.filled(7, 0.0);
      currentIndex = now.weekday - 1; // 0 = Mon, 6 = Sun
      for (var e in expenses) {
        totals[e.timestamp.toDate().weekday - 1] += e.amount;
      }
    } else if (_selectedFilter == ExpenseFilter.thisMonth) {
      dateRangeLabel = "This Month";
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      int totalWeeks = ((daysInMonth + firstDayOfMonth.weekday - 2) / 7).floor() + 1;
      
      labels = List.generate(totalWeeks, (i) => 'W${i + 1}');
      totals = List.filled(totalWeeks, 0.0);
      currentIndex = ((now.day + firstDayOfMonth.weekday - 2) / 7).floor();
      
      for (var e in expenses) {
        int week = ((e.timestamp.toDate().day + firstDayOfMonth.weekday - 2) / 7).floor();
        if (week >= totalWeeks) week = totalWeeks - 1; // Catch-all for end of month
        totals[week] += e.amount;
      }
    } else if (_selectedFilter == ExpenseFilter.sixMonths) {
      dateRangeLabel = "Past 6 Months";
      currentIndex = 5; // In our 6-month loop, the last item added is always the current month
      for(int i=5; i>=0; i--) {
        DateTime d = DateTime(now.year, now.month - i, 1);
        labels.add(DateFormat('MMM').format(d));
        totals.add(0.0);
      }
      for (var e in expenses) {
        String monthStr = DateFormat('MMM').format(e.timestamp.toDate());
        int index = labels.indexOf(monthStr);
        if (index != -1) totals[index] += e.amount;
      }
    } else if (_selectedFilter == ExpenseFilter.year) {
      dateRangeLabel = "This Year";
      labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      totals = List.filled(12, 0.0);
      currentIndex = now.month - 1; // 0 = Jan, 11 = Dec
      for (var e in expenses) {
        totals[e.timestamp.toDate().month - 1] += e.amount;
      }
    }

    // Calculate max amount for the background tracking (adds 20% padding to the top)
    double maxAmount = totals.isEmpty ? 0 : totals.reduce(max);
    double bgMax = maxAmount == 0 ? 100 : maxAmount * 1.2;

    // --- 📊 CALCULATE STATS FOR THE 2X2 GRID ---
    double total = totals.isEmpty ? 0.0 : totals.reduce((a, b) => a + b);

    // 🧠 CONTEXT-AWARE AVERAGE CALCULATION
    double average = 0.0;
    String averageLabel = "Average";

    int activeBuckets = totals.where((t) => t > 0).length;

    if (activeBuckets > 0) {
      average = total / activeBuckets;
    }

    if (_selectedFilter == ExpenseFilter.thisWeek) {
      averageLabel = "Daily Avg";
    } else if (_selectedFilter == ExpenseFilter.thisMonth) {
      averageLabel = "Weekly Avg";
    } else if (_selectedFilter == ExpenseFilter.sixMonths) {
      averageLabel = "Monthly Avg";
    } else if (_selectedFilter == ExpenseFilter.year) {
      averageLabel = "Monthly Avg";
    }

    double highestVal = -1;
    String highestLabel = "-";
    double lowestVal = double.infinity;
    String lowestLabel = "-";

    for (int i = 0; i < totals.length; i++) {
      if (totals[i] > highestVal) {
        highestVal = totals[i];
        highestLabel = labels[i];
      }
      if (totals[i] < lowestVal) {
        lowestVal = totals[i];
        lowestLabel = labels[i];
      }
    }

    if (lowestVal == double.infinity) lowestVal = 0;
    if (highestVal == -1) highestVal = 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateRangeLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  Text("Unit: ₹", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,

                    // --- 📊 PERMANENT TOOLTIP STYLING ---
                    barTouchData: BarTouchData(
                      enabled: true, // Still allows touching other bars
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => group.x == currentIndex
                            ? Colors.purpleAccent.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.15), // Muted background for past bars
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        tooltipMargin: 8, // Distance from the top of the bar
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final isCurrent = group.x == currentIndex;
                          return BarTooltipItem(
                            '₹${rod.toY.toStringAsFixed(0)}',
                            TextStyle(
                              color: isCurrent ? Colors.purpleAccent : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          );
                        },
                      ),
                    ),
                    // -----------------------------------------

                    borderData: FlBorderData(show: false), // Hides outer box
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            // 💡 IF THIS IS THE CURRENT BUCKET, HIGHLIGHT THE TEXT!
                            final bool isCurrent = value.toInt() == currentIndex;

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                labels[value.toInt()],
                                style: TextStyle(
                                    color: isCurrent ? Colors.white : Colors.grey.shade500,
                                    fontSize: 11,
                                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                        dashArray: [4, 4], // Dashed horizontal lines
                      ),
                    ),
                    barGroups: List.generate(totals.length, (index) {
                      // 💡 IF THIS IS THE CURRENT BUCKET, MAKE IT GLOW!
                      final bool isCurrent = index == currentIndex;

                      return BarChartGroupData(
                        x: index,

                        // --- 📊 PIN THE TOOLTIP TO ALL BARS WITH DATA ---
                        showingTooltipIndicators: totals[index] > 0 ? [0] : [],

                        barRods: [
                          BarChartRodData(
                            toY: totals[index],
                            color: isCurrent ? Colors.purpleAccent : Colors.purpleAccent.withOpacity(0.4),
                            width: 18,
                            borderRadius: BorderRadius.circular(6), // Rounded tops!
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: bgMax,
                              color: Colors.white.withOpacity(0.05), // Faint track background
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16), // Space between chart and stats grid

        // --- 📊 THE 2X2 STATS GRID ---
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatItem(averageLabel, "₹${average.toStringAsFixed(0)}", Icons.calendar_today, null, Colors.purpleAccent.shade100)),
                  Expanded(child: _buildStatItem("Total", "₹${total.toStringAsFixed(0)}", Icons.date_range, null, Colors.purpleAccent.shade100)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildStatItem("Least", "₹${lowestVal.toStringAsFixed(0)}", Icons.bar_chart, lowestLabel, Colors.purpleAccent.shade100)),
                  Expanded(child: _buildStatItem("Most", "₹${highestVal.toStringAsFixed(0)}", Icons.leaderboard, highestLabel, Colors.purpleAccent.shade100)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 🛠️ HELPER METHOD FOR THE 2X2 GRID ---
  Widget _buildStatItem(String title, String value, IconData icon, String? subtitle, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.0),
                    overflow: TextOverflow.ellipsis
                )
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]
      ],
    );
  }
}