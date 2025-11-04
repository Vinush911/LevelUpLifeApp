import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/user.dart';
import 'dart:math';
import 'dart:collection';
// --- NEW IMPORTS ---
import 'package:fl_chart/fl_chart.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/unlock_overlay.dart';

// --- UPDATED ENUM for filters ---
enum ExpenseFilter { sevenDays, thirtyDays, threeMonth, sixMonth, year }

class WalletScreen extends StatefulWidget {
  final String uid;
  const WalletScreen({super.key, required this.uid});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  // --- UPDATED State variables ---
  ExpenseFilter _selectedFilter = ExpenseFilter.sevenDays; // <<< MODIFIED
  late TabController _tabController;
  int _currentTabIndex = 0;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- (Add/Edit Dialog is unchanged) ---
  void _showExpenseDialog({Expense? expense}) {
    final bool isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final amountController =
    TextEditingController(text: isEditing ? expense.amount.toString() : '');
    final descriptionController =
    TextEditingController(text: isEditing ? expense.description : '');
    final paymentMethodController =
    TextEditingController(text: isEditing ? expense.paymentMethod : 'Cash');
    ExpenseCategory selectedCategory =
    isEditing ? expense.category : ExpenseCategory.food;
    DateTime selectedDate =
    isEditing ? expense.timestamp.toDate() : DateTime.now();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              title: Text(isEditing ? "Edit Expense" : "Add New Expense",
                  style: const TextStyle(color: Colors.white)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Amount", prefixText: "₹"),
                        keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null ||
                            v.isEmpty ||
                            double.tryParse(v) == null)
                            ? "Invalid amount"
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ExpenseCategory>(
                        value: selectedCategory,
                        dropdownColor: const Color(0xFF1A1A2E),
                        items: ExpenseCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(ExpenseCategoryInfo.map[category]!.icon,
                                    size: 20, color: Colors.white70),
                                const SizedBox(width: 8),
                                Text(ExpenseCategoryInfo.map[category]!.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null)
                            setDialogState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            "Date: ${DateFormat.yMMMd().format(selectedDate)}",
                            style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.calendar_today,
                            color: Colors.purpleAccent),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != selectedDate) {
                            setDialogState(() {
                              selectedDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  selectedDate.hour,
                                  selectedDate.minute);
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Time: ${DateFormat.jm().format(selectedDate)}",
                            style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.access_time,
                            color: Colors.purpleAccent),
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  picked.hour,
                                  picked.minute);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: paymentMethodController,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                        const InputDecoration(labelText: "Payment Method"),
                        validator: (v) =>
                        (v == null || v.isEmpty) ? "Required" : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionController,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                        const InputDecoration(labelText: "Note / Description"),
                        validator: (v) =>
                        (v == null || v.isEmpty) ? "Required" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() => isLoading = true);
                      final firestore = FirebaseFirestore.instance;
                      final userRef =
                      firestore.collection('users').doc(widget.uid);

                      final expenseData = {
                        'amount': double.parse(amountController.text),
                        'description': descriptionController.text,
                        'timestamp': Timestamp.fromDate(selectedDate),
                        'category':
                        selectedCategory.toString().split('.').last,
                        'paymentMethod': paymentMethodController.text,
                      };

                      if (isEditing) {
                        await userRef
                            .collection('expenses')
                            .doc(expense!.id)
                            .update(expenseData);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Expense updated!"),
                                backgroundColor: Colors.blue),
                          );
                        }
                      } else {
                        final random = Random();
                        final goldReward = 5 + random.nextInt(21);
                        final expReward = 10 + random.nextInt(41);
                        expenseData['goldReward'] = goldReward;
                        expenseData['expReward'] = expReward;

                        try {
                          final userDoc = await userRef.get();
                          if (!userDoc.exists)
                            throw Exception("User not found");

                          final user = User.fromFirestore(userDoc);
                          final initialLevel = user.level;
                          user.gold += goldReward;
                          user.exp += expReward;

                          bool leveledUp = false;
                          while (user.exp >= user.nextLevelExp()) {
                            user.exp -= user.nextLevelExp();
                            user.level++;
                            user.unassignedStatPoints += 3;
                            user.updateTitle();
                            leveledUp = true;
                          }

                          final newExpenseRef =
                          userRef.collection('expenses').doc();
                          final batch = firestore.batch();
                          batch.set(newExpenseRef, expenseData);
                          batch.update(userRef, user.toMap());
                          await batch.commit();

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "Expense added! +$goldReward Gold, +$expReward EXP"),
                                backgroundColor: Colors.green,
                              ),
                            );
                            if (leveledUp) {
                              await showLevelUpOverlay(context, user.level);
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                  Text("Failed to add expense: $e"),
                                  backgroundColor: Colors.red),
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

  // --- (Delete function is unchanged) ---
  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete Expense?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will also remove the Gold and EXP you earned. This action cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
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
        final initialLevel = user.level;

        user.gold -= expense.goldReward;
        user.exp -= expense.expReward;

        if (user.gold < 0) user.gold = 0;
        if (user.exp < 0) user.exp = 0;

        // --- De-leveling logic ---
        while (user.exp < 0 && user.level > 1) {
          final prevLevelExp = (100 * pow(user.level - 1, 1.5)).toDouble();
          user.level--;
          user.exp += prevLevelExp;
          user.unassignedStatPoints = max(0, user.unassignedStatPoints - 3);
          user.updateTitle();
        }
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
          if (user.level < initialLevel) {
            await showUnlockOverlay(
              context,
              unlockTitle: "LEVEL DOWN",
              itemName: "You are now Level ${user.level}",
              iconData: Icons.arrow_downward,
              color: Colors.red,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Failed to delete expense: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search by note...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white70)),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        )
            : Text(
          _currentTabIndex == 0 ? "Records" : "Statistics",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: "TRANSACTIONS"),
            Tab(text: "STATS"),
          ],
        ),
      ),
      body: _buildMainContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseDialog,
        tooltip: "Add Expense",
        backgroundColor: Colors.purpleAccent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      color: const Color(0xFF16213E),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: SegmentedButton<ExpenseFilter>(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.grey.shade800.withOpacity(0.5),
            foregroundColor: Colors.grey.shade400,
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Colors.purpleAccent.withOpacity(0.5),
          ),
          segments: const [
            ButtonSegment<ExpenseFilter>(
                value: ExpenseFilter.sevenDays, label: Text('7D')), // <<< MODIFIED
            ButtonSegment<ExpenseFilter>(
                value: ExpenseFilter.thirtyDays, label: Text('30D')), // <<< MODIFIED
            ButtonSegment<ExpenseFilter>(
                value: ExpenseFilter.threeMonth, label: Text('12W')),
            ButtonSegment<ExpenseFilter>(
                value: ExpenseFilter.sixMonth, label: Text('6M')),
            ButtonSegment<ExpenseFilter>(
                value: ExpenseFilter.year, label: Text('Year')),
          ],
          selected: {_selectedFilter},
          onSelectionChanged: (Set<ExpenseFilter> newSelection) {
            setState(() {
              _selectedFilter = newSelection.first;
            });
          },
        ),
      ),
    );
  }

  // --- UPDATED: Gets the correct date range based on the filter ---
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case ExpenseFilter.sevenDays: // <<< MODIFIED
      // Last 7 days (rolling)
        final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        return (startDate, now);
      case ExpenseFilter.thirtyDays: // <<< MODIFIED
      // Last 30 days (rolling)
        final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        return (startDate, now);
      case ExpenseFilter.threeMonth:
        return (now.subtract(const Duration(days: 84)), now);
      case ExpenseFilter.sixMonth:
        return (now.subtract(const Duration(days: 180)), now);
      case ExpenseFilter.year:
      // Current calendar year
        final startOfYear = DateTime(now.year, 1, 1);
        final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);
        return (startOfYear, endOfYear);
    }
  }

  // --- UPDATED: Gets the correct title for the header ---
  String _getHeaderTitle() {
    switch (_selectedFilter) {
      case ExpenseFilter.sevenDays:
        return 'LAST 7 DAYS'; // <<< MODIFIED
      case ExpenseFilter.thirtyDays:
        return 'LAST 30 DAYS'; // <<< MODIFIED
      case ExpenseFilter.threeMonth:
        return 'LAST 12 WEEKS';
      case ExpenseFilter.sixMonth:
        return 'LAST 6 MONTHS';
      case ExpenseFilter.year:
        return DateTime.now().year.toString();
    }
  }

  Widget _buildMainContent() {
    final (startDate, endDate) = _getDateRange();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('expenses')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var expenses =
        snapshot.data!.docs.map((doc) => Expense.fromFirestore(doc)).toList();

        if (_searchQuery.isNotEmpty) {
          expenses = expenses.where((expense) {
            return expense.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
          }).toList();
        }

        final totalExpense = expenses.fold(0.0, (sum, item) => sum + item.amount);

        return TabBarView(
          controller: _tabController,
          children: [
            _buildTransactionList(expenses, totalExpense),
            _buildStatsView(expenses, totalExpense),
          ],
        );
      },
    );
  }

  Widget _buildTransactionList(List<Expense> expenses, double totalExpense) {
    if (expenses.isEmpty) {
      return Center(
          child: Text(
              _searchQuery.isNotEmpty
                  ? "No results found."
                  : "No expenses recorded in this period.",
              style: const TextStyle(color: Colors.grey)));
    }

    final groupedExpenses = _groupExpenses(expenses);

    return Column(
      children: [
        // --- Header ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          color: const Color(0xFF16213E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_getHeaderTitle(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1)),
              Text("Σ -₹${totalExpense.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.redAccent)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Space for FAB
            itemCount: groupedExpenses.keys.length,
            itemBuilder: (context, index) {
              final dateHeader = groupedExpenses.keys.elementAt(index);
              final dailyExpenses = groupedExpenses[dateHeader]!;
              final dailyTotal =
              dailyExpenses.fold(0.0, (sum, item) => sum + item.amount);

              return Column(
                children: [
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateHeader.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                        Text("Σ -₹${dailyTotal.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  ...dailyExpenses
                      .map((expense) => _buildExpenseTile(expense))
                      .toList(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Stats View with Pie Chart ---
  Widget _buildStatsView(List<Expense> expenses, double totalExpense) {
    if (expenses.isEmpty) {
      return const Center(
          child: Text("No data for statistics.",
              style: TextStyle(color: Colors.grey)));
    }

    final Map<ExpenseCategory, double> categoryTotals = {};
    for (var expense in expenses) {
      categoryTotals.update(
        expense.category,
            (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    // Sort categories from highest spending to lowest
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Color> pieColors = [
      Colors.purpleAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
      Colors.cyanAccent,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- Total Card ---
          Card(
            color: const Color(0xFF16213E),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  children: [
                    Text("TOTAL SPENT",
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                    const SizedBox(height: 8),
                    Text(
                      "-₹${totalExpense.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Pie Chart ---
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: List.generate(sortedCategories.length, (index) {
                  final category = sortedCategories[index];
                  final categoryInfo = ExpenseCategoryInfo.map[category.key]!;
                  final percentage = (category.value / totalExpense) * 100;

                  return PieChartSectionData(
                    color: pieColors[index % pieColors.length],
                    value: category.value,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: 80,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        shadows: [Shadow(color: Colors.white, blurRadius: 2)]),
                    badgeWidget: Icon(categoryInfo.icon,
                        size: 16,
                        color: pieColors[index % pieColors.length]),
                    badgePositionPercentageOffset: 1.4,
                  );
                }),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Legend ---
          ...List.generate(sortedCategories.length, (index) {
            final category = sortedCategories[index];
            final categoryInfo = ExpenseCategoryInfo.map[category.key]!;
            final percentage = (category.value / totalExpense) * 100;

            return _buildStatRow(
              icon: categoryInfo.icon,
              color: pieColors[index % pieColors.length],
              title: categoryInfo.name,
              amount: category.value,
              percentage: percentage,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      {required IconData icon,
        required Color color,
        required String title,
        required double amount,
        required double percentage}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ),
          Text("${percentage.toStringAsFixed(1)}%",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text("-₹${amount.toStringAsFixed(2)}",
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: Grouping logic now smarter based on filter ---
  LinkedHashMap<String, List<Expense>> _groupExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Helper to get ISO week number
    int weekNumber(DateTime date) {
      int dayOfYear = int.parse(DateFormat("D").format(date));
      return ((dayOfYear - date.weekday + 10) / 7).floor();
    }

    // Determine the grouping format based on the filter
    String getHeader(DateTime date) {
      final dayKey = DateTime(date.year, date.month, date.day);
      if (dayKey == today) return 'Today';
      if (dayKey == yesterday) return 'Yesterday';

      switch (_selectedFilter) {
        case ExpenseFilter.sevenDays: // <<< MODIFIED
          return DateFormat.yMMMd().format(date); // e.g., "Oct 31, 2025"

        case ExpenseFilter.thirtyDays: // <<< MODIFIED
        case ExpenseFilter.threeMonth:
          return 'WEEK ${weekNumber(date)}'; // e.g., "WEEK 45"

        case ExpenseFilter.sixMonth:
        case ExpenseFilter.year:
          return DateFormat('MMMM yyyy').format(date).toUpperCase(); // e.g., "NOVEMBER 2025"
      }
    }

    final map = LinkedHashMap<String, List<Expense>>();
    for (var expense in expenses) {
      final header = getHeader(expense.timestamp.toDate());
      (map[header] ??= []).add(expense);
    }
    return map;
  }

  // --- UPDATED: Expense tile matches screenshots ---
  Widget _buildExpenseTile(Expense expense) {
    final categoryInfo = ExpenseCategoryInfo.map[expense.category]!;

    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => _showExpenseDialog(expense: expense),
        onLongPress: () => _deleteExpense(expense),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade800,
          child: Icon(categoryInfo.icon, color: Colors.white, size: 20),
        ),
        title: Text(categoryInfo.name,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.paymentMethod, style: TextStyle(color: Colors.grey.shade400)),
            if (expense.description.isNotEmpty)
              Text("\"${expense.description}\"",
                  style: TextStyle(
                      color: Colors.grey.shade300,
                      fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "-₹${expense.amount.toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              DateFormat.jm().format(expense.timestamp.toDate()),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

