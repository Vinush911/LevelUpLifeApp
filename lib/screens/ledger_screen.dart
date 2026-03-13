import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to format timestamps beautifully using intl
  String _formatDate(Timestamp timestamp) {
    return DateFormat('EEE, MMM d, h:mm a').format(timestamp.toDate());
  }

  // --- CREATE NEW TRANSACTION ---
  Future<void> _processTransaction({
    required String personName,
    required double amount,
    required bool isLent,
    required String description,
    required DateTime selectedDate,
    String? existingDocId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ledgerRef = _firestore.collection('users').doc(user.uid).collection('ledger');
    final balanceChange = isLent ? amount : -amount;

    final newTransaction = {
      // 🛡️ THE FIX: Inject a unique ID based on the exact millisecond it was created
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': amount,
      'isLent': isLent,
      'description': description,
      'timestamp': Timestamp.fromDate(selectedDate),
    };

    try {
      if (existingDocId != null) {
        await ledgerRef.doc(existingDocId).update({
          'totalBalance': FieldValue.increment(balanceChange),
          'transactions': FieldValue.arrayUnion([newTransaction]),
        });
      } else {
        await ledgerRef.add({
          'personName': personName,
          'totalBalance': balanceChange,
          'createdAt': FieldValue.serverTimestamp(),
          'transactions': [newTransaction],
        });
      }

      // Log activity to Adventurer's Log
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _firestore.collection('users').doc(user.uid).collection('activity_log').doc(todayStr).set({
        'ledgerUpdates': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ledger Updated Successfully."), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("System Error: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // --- EDIT EXISTING TRANSACTION SAFELY ---
  Future<void> _editTransaction(String docId, Map<String, dynamic> oldTx, Map<String, dynamic> newTx) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ledgerRef = _firestore.collection('users').doc(user.uid).collection('ledger').doc(docId);

    final oldAmount = oldTx['isLent'] ? oldTx['amount'] : -oldTx['amount'];
    final newAmount = newTx['isLent'] ? newTx['amount'] : -newTx['amount'];
    final balanceChange = newAmount - oldAmount;

    // Ensure the new transaction keeps the same ID as the old one!
    if (oldTx.containsKey('id')) {
      newTx['id'] = oldTx['id'];
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ledgerRef);
        if (!snapshot.exists) return;

        List<dynamic> transactions = snapshot.get('transactions');

        final index = transactions.indexWhere((tx) {
          if (tx.containsKey('id') && oldTx.containsKey('id')) {
            return tx['id'] == oldTx['id'];
          }
          return tx['description'] == oldTx['description'] &&
              tx['amount'] == oldTx['amount'] &&
              tx['timestamp'] == oldTx['timestamp'];
        });

        if (index != -1) {
          transactions[index] = newTx;
          transaction.update(ledgerRef, {
            'transactions': transactions,
            'totalBalance': FieldValue.increment(balanceChange),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction updated."), backgroundColor: Colors.cyanAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // --- DELETE SAFE LOGIC (Answers previous active learning question) ---
  Future<void> _deleteTransaction(String docId, Map<String, dynamic> transactionToRemove) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ledgerRef = _firestore.collection('users').doc(user.uid).collection('ledger').doc(docId);

    final isLent = transactionToRemove['isLent'] ?? true;
    final amount = (transactionToRemove['amount'] as num?)?.toDouble() ?? 0.0;
    final balanceChange = isLent ? -amount : amount;

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ledgerRef);
        if (!snapshot.exists) return;

        List<dynamic> transactions = List.from(snapshot.get('transactions'));

        final index = transactions.indexWhere((tx) {
          if (tx.containsKey('id') && transactionToRemove.containsKey('id')) {
            return tx['id'] == transactionToRemove['id'];
          }
          return tx['description'] == transactionToRemove['description'] &&
              tx['amount'] == transactionToRemove['amount'] &&
              tx['timestamp'] == transactionToRemove['timestamp'];
        });

        if (index != -1) {
          transactions.removeAt(index);
          transaction.update(ledgerRef, {
            'transactions': transactions,
            'totalBalance': FieldValue.increment(balanceChange),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction deleted."), backgroundColor: Colors.amber));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // --- Method to delete an entire ledger ---
  Future<void> _deleteLedger(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).collection('ledger').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ledger permanently deleted."), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting ledger: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // --- Dialog to confirm transaction deletion ---
  void _confirmDeleteTransaction(String docId, Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: const Text("Delete Transaction?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to remove this record? This will adjust the total balance accordingly.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTransaction(docId, transaction);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // --- Dialog to confirm entire ledger deletion ---
  void _confirmDeleteLedger(String docId, String personName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: Text("Delete $personName's Ledger?", style: const TextStyle(color: Colors.white)),
        content: const Text(
          "This will permanently delete this person and all associated transaction history. This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteLedger(docId);
            },
            child: const Text("Delete Ledger"),
          ),
        ],
      ),
    );
  }

  // --- UNIFIED DIALOG (Create/Edit + Date Picker) ---
  void _showTransactionDialog({String? existingDocId, String? existingName, Map<String, dynamic>? transactionToEdit}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingName);

    // Pre-fill fields if we are editing an existing transaction
    final amountController = TextEditingController(text: transactionToEdit?['amount']?.toString() ?? '');
    final descController = TextEditingController(text: transactionToEdit?['description'] ?? '');
    bool isLent = transactionToEdit?['isLent'] ?? true;
    DateTime selectedDate = transactionToEdit?['timestamp']?.toDate() ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5))),
            title: Text(
              transactionToEdit != null ? "Edit Transaction" : (existingDocId == null ? "Add New Entity" : "Update Ledger: $existingName"),
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existingDocId == null)
                      _buildTextField(
                        controller: nameController,
                        label: "Person's Name",
                        icon: Icons.person_outline,
                        validator: (val) => val == null || val.isEmpty ? "Name is required" : null,
                      ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: amountController,
                      label: "Amount (Gold/Currency)",
                      icon: Icons.monetization_on_outlined,
                      isNumber: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Amount is required";
                        if (double.tryParse(val) == null) return "Enter a valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: descController,
                      label: "Short Description (e.g., Lunch)",
                      icon: Icons.description_outlined,
                      validator: (val) => val == null || val.isEmpty ? "Description is required" : null,
                    ),
                    const SizedBox(height: 12),

                    // --- DATE & TIME PICKER ---
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.purpleAccent, onPrimary: Colors.black, surface: Color(0xFF16213E), onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          ),
                        );

                        if (pickedDate != null && context.mounted) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );

                          if (pickedTime != null) {
                            setState(() {
                              selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
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
                        child: Text(DateFormat('MMM d, yyyy - h:mm a').format(selectedDate), style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12.0,
                      children: [
                        ChoiceChip(
                          label: const Padding(padding: EdgeInsets.all(4.0), child: Text("I Gave Them", style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: isLent,
                          selectedColor: Colors.amber.withOpacity(0.9),
                          backgroundColor: Colors.black26,
                          labelStyle: TextStyle(color: isLent ? Colors.black : Colors.white),
                          onSelected: (val) => setState(() => isLent = true),
                        ),
                        ChoiceChip(
                          label: const Padding(padding: EdgeInsets.all(4.0), child: Text("They Gave Me", style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: !isLent,
                          selectedColor: Colors.redAccent.withOpacity(0.9),
                          backgroundColor: Colors.black26,
                          labelStyle: TextStyle(color: !isLent ? Colors.white : Colors.white),
                          onSelected: (val) => setState(() => isLent = false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    final desc = descController.text.trim();

                    if (transactionToEdit != null && existingDocId != null) {
                      final newTx = {
                        'amount': amount,
                        'isLent': isLent,
                        'description': desc,
                        'timestamp': Timestamp.fromDate(selectedDate),
                      };
                      _editTransaction(existingDocId, transactionToEdit, newTx);
                    } else {
                      _processTransaction(
                        personName: name,
                        amount: amount,
                        isLent: isLent,
                        description: desc,
                        selectedDate: selectedDate,
                        existingDocId: existingDocId,
                      );
                    }
                    Navigator.pop(context);
                  }
                },
                child: const Text("Save Record", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.purpleAccent),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        errorStyle: const TextStyle(color: Colors.redAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.purpleAccent)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  // --- Top Dashboard to show total net worth ---
  Widget _buildSummaryDashboard(double totalOwedToMe, double totalIOwe) {
    final netWorth = totalOwedToMe - totalIOwe;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF16213E), const Color(0xFF16213E).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                "NET BALANCE",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${netWorth >= 0 ? '+' : '-'}₹${netWorth.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: netWorth >= 0 ? Colors.amber : Colors.redAccent,
              shadows: [
                Shadow(color: (netWorth >= 0 ? Colors.amber : Colors.redAccent).withOpacity(0.3), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryColumn("Owed to You", totalOwedToMe, Colors.amber),
              Container(height: 40, width: 1, color: Colors.white24),
              _buildSummaryColumn("You Owe", totalIOwe, Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        const SizedBox(height: 6),
        Text("₹${amount.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: Text("System Offline. Please log in.", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Merchant's Ledger", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionDialog(),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        elevation: 8,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text("New Ledger Entry", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .doc(user.uid)
              .collection('ledger')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }

            // Calculate Dashboard Totals
            double totalOwedToMe = 0.0;
            double totalIOwe = 0.0;
            final ledgers = snapshot.data?.docs ?? [];

            for (var doc in ledgers) {
              final data = doc.data() as Map<String, dynamic>;
              final bal = (data['totalBalance'] as num?)?.toDouble() ?? 0.0;
              if (bal > 0) totalOwedToMe += bal;
              if (bal < 0) totalIOwe += bal.abs();
            }

            return Column(
              children: [
                _buildSummaryDashboard(totalOwedToMe, totalIOwe),
                Expanded(
                  child: ledgers.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
                          child: Icon(Icons.menu_book_rounded, size: 80, color: Colors.purpleAccent.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 24),
                        const Text("Your ledger is empty.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text("Add an entry to track debts and loans.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 80),
                    itemCount: ledgers.length,
                    itemBuilder: (context, index) {
                      final doc = ledgers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final personName = data['personName'] ?? 'Unknown';
                      final totalBalance = (data['totalBalance'] as num?)?.toDouble() ?? 0.0;

                      // --- 1️⃣ CHRONOLOGICAL CALCULATION LOGIC ---
                      final rawTransactions = data['transactions'] as List<dynamic>? ?? [];
                      List<Map<String, dynamic>> sortedTx = rawTransactions.map((t) => Map<String, dynamic>.from(t as Map)).toList();

                      // Sort old to new to calculate running balance
                      sortedTx.sort((a, b) {
                        final tA = a['timestamp'] as Timestamp?;
                        final tB = b['timestamp'] as Timestamp?;
                        if (tA == null || tB == null) return 0;
                        return tA.compareTo(tB);
                      });

                      double runningBal = 0.0;
                      int lastSettlementIdx = -1;

                      for (int i = 0; i < sortedTx.length; i++) {
                        final tx = sortedTx[i];
                        final isLent = tx['isLent'] ?? true;
                        final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                        runningBal += isLent ? amt : -amt;

                        // Use an epsilon for precise double matching to 0
                        if (runningBal.abs() < 0.001) {
                          lastSettlementIdx = i;
                        }
                      }

                      // Tag transactions as History or Settlement Point
                      for (int i = 0; i < sortedTx.length; i++) {
                        sortedTx[i]['_isHistory'] = i <= lastSettlementIdx;
                        sortedTx[i]['_isSettlementPoint'] = i == lastSettlementIdx;
                      }

                      // Reverse them back for the UI display (newest first)
                      final transactions = sortedTx.reversed.toList();

                      // --- CARD HEADER UI LOGIC ---
                      String balanceText;
                      Color balanceColor;

                      if (totalBalance > 0.001) {
                        balanceText = "They owe you: ₹${totalBalance.toStringAsFixed(2)}";
                        balanceColor = Colors.amber;
                      } else if (totalBalance < -0.001) {
                        balanceText = "You owe them: ₹${totalBalance.abs().toStringAsFixed(2)}";
                        balanceColor = Colors.redAccent;
                      } else {
                        balanceText = "Accounts Settled";
                        balanceColor = Colors.tealAccent; // A bright, active positive color
                      }

                      return Card(
                        color: const Color(0xFF16213E), // ⬅️ Outer card is NO LONGER dimmed
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 6, // ⬅️ Elevation is restored
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: balanceColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            childrenPadding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                            iconColor: balanceColor,
                            collapsedIconColor: Colors.white70,
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: balanceColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.person, color: balanceColor, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        personName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), // ⬅️ Text is always white
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        balanceText,
                                        style: TextStyle(color: balanceColor, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: Colors.purpleAccent.shade100,
                                  splashRadius: 24,
                                  tooltip: "Update Balance",
                                  onPressed: () => _showTransactionDialog(
                                    existingDocId: doc.id,
                                    existingName: personName,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.redAccent.withOpacity(0.8),
                                  splashRadius: 24,
                                  tooltip: "Delete Ledger",
                                  onPressed: () => _confirmDeleteLedger(doc.id, personName),
                                ),
                              ],
                            ),
                            children: [
                              Container(height: 1, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                              if (transactions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text("No transaction history.", style: TextStyle(color: Colors.grey)),
                                ),

                              // --- 2️⃣ DATE GROUPING & GRAY-OUT LOGIC ---
                              ...() {
                                Map<String, List<Map<String, dynamic>>> groupedTx = {};

                                for (var tx in transactions) {
                                  final timestamp = tx['timestamp'] as Timestamp?;
                                  String dateKey = 'Unknown Date';

                                  if (timestamp != null) {
                                    final date = timestamp.toDate();
                                    final now = DateTime.now();
                                    final today = DateTime(now.year, now.month, now.day);
                                    final txDate = DateTime(date.year, date.month, date.day);
                                    final diff = today.difference(txDate).inDays;

                                    if (diff == 0) {
                                      dateKey = "Today";
                                    } else if (diff == 1) {
                                      dateKey = "Yesterday";
                                    } else {
                                      dateKey = DateFormat('EEE, MMM d').format(date);
                                    }
                                  }

                                  groupedTx.putIfAbsent(dateKey, () => []);
                                  groupedTx[dateKey]!.add(tx);
                                }

                                List<Widget> uiElements = [];

                                groupedTx.forEach((dateString, dayTransactions) {
                                  uiElements.add(
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                                      child: Text(
                                        dateString.toUpperCase(),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                      ),
                                    ),
                                  );

                                  for (var tx in dayTransactions) {
                                    final isLent = tx['isLent'] ?? true;
                                    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                                    final desc = tx['description'] ?? '';
                                    final timestamp = tx['timestamp'] as Timestamp?;

                                    // Apply UI styles based on history status
                                    final isHistory = tx['_isHistory'] == true;
                                    final isSettlementPoint = tx['_isSettlementPoint'] == true;

                                    // ⬅️ THIS IS WHERE THE GRAY-OUT HAPPENS
                                    final txColor = isHistory ? Colors.grey.shade600 : (isLent ? Colors.amber : Colors.redAccent);
                                    final textColor = isHistory ? Colors.grey.shade500 : Colors.white;

                                    Widget txTile = ListTile(
                                      onTap: () => _showTransactionDialog(
                                        existingDocId: doc.id,
                                        existingName: personName,
                                        transactionToEdit: tx,
                                      ),
                                      onLongPress: () => _confirmDeleteTransaction(doc.id, tx),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isHistory ? Colors.grey.withOpacity(0.1) : txColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                          color: txColor,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(desc, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          timestamp != null ? DateFormat('h:mm a').format(timestamp.toDate()) : '',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ),
                                      trailing: Text(
                                        "${isLent ? '+' : '-'}₹${amount.toStringAsFixed(2)}",
                                        style: TextStyle(color: txColor, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    );

                                    // 3️⃣ INJECT THE SETTLED BANNER
                                    if (isSettlementPoint) {
                                      uiElements.add(
                                          Column(
                                            children: [
                                              Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.tealAccent.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(Icons.handshake, color: Colors.tealAccent, size: 18),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                          "ACCOUNT SETTLED",
                                                          style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)
                                                      ),
                                                    ],
                                                  )
                                              ),
                                              txTile,
                                            ],
                                          )
                                      );
                                    } else {
                                      uiElements.add(txTile);
                                    }
                                  }
                                });

                                return uiElements;
                              }(),

                              if (transactions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text("Long-press a transaction to delete it.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
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
}