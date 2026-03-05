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
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  Future<void> _processTransaction({
    required String personName,
    required double amount,
    required bool isLent,
    required String description,
    String? existingDocId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ledgerRef =
    _firestore.collection('users').doc(user.uid).collection('ledger');

    final balanceChange = isLent ? amount : -amount;

    // Note: FieldValue.serverTimestamp() cannot be used inside arrays.
    // We use Timestamp.now() instead.
    final newTransaction = {
      'amount': amount,
      'isLent': isLent,
      'description': description,
      'timestamp': Timestamp.now(),
    };

    try {
      if (existingDocId != null) {
        // Update existing ledger entry atomically
        await ledgerRef.doc(existingDocId).update({
          'totalBalance': FieldValue.increment(balanceChange),
          'transactions': FieldValue.arrayUnion([newTransaction]),
        });
      } else {
        // Create a new ledger entry
        await ledgerRef.add({
          'personName': personName,
          'totalBalance': balanceChange,
          'createdAt': FieldValue.serverTimestamp(),
          'transactions': [newTransaction],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ledger Updated Successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("System Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- Method to delete a single transaction ---
  Future<void> _deleteTransaction(String docId, Map<String, dynamic> transaction) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isLent = transaction['isLent'] ?? true;
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;

    // Reverse the balance impact
    final balanceChange = isLent ? -amount : amount;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ledger')
          .doc(docId)
          .update({
        'totalBalance': FieldValue.increment(balanceChange),
        'transactions': FieldValue.arrayRemove([transaction]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transaction deleted."), backgroundColor: Colors.amber),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Method to delete an entire ledger ---
  Future<void> _deleteLedger(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ledger')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ledger permanently deleted."), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting ledger: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Dialog to confirm transaction deletion ---
  void _confirmDeleteTransaction(String docId, Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text("Delete Transaction?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to remove this record? This will adjust the total balance accordingly.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTransaction(docId, transaction);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
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
        title: Text("Delete $personName's Ledger?", style: const TextStyle(color: Colors.white)),
        content: const Text(
          "This will permanently delete this person and all associated transaction history. This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteLedger(docId);
            },
            child: const Text("Delete Ledger", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog({String? existingDocId, String? existingName}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingName);
    final amountController = TextEditingController();
    final descController = TextEditingController();
    bool isLent = true; // Default to giving money

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16213E), // Matches RPG theme
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
            ),
            title: Text(
              existingDocId == null
                  ? "Add New Entity"
                  : "Update Ledger: $existingName",
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
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: const Text("I Gave Them", style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: isLent,
                          selectedColor: Colors.amber.withOpacity(0.8),
                          backgroundColor: Colors.black26,
                          onSelected: (val) => setState(() => isLent = true),
                        ),
                        ChoiceChip(
                          label: const Text("They Gave Me", style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: !isLent,
                          selectedColor: Colors.redAccent.withOpacity(0.8),
                          backgroundColor: Colors.black26,
                          onSelected: (val) => setState(() => isLent = false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    final desc = descController.text.trim();

                    _processTransaction(
                      personName: name,
                      amount: amount,
                      isLent: isLent,
                      description: desc,
                      existingDocId: existingDocId,
                    );
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
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.purpleAccent),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        errorStyle: const TextStyle(color: Colors.redAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.purpleAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  // --- NEW: Top Dashboard to show total net worth ---
  Widget _buildSummaryDashboard(double totalOwedToMe, double totalIOwe) {
    final netWorth = totalOwedToMe - totalIOwe;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "NET BALANCE",
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            "${netWorth >= 0 ? '+' : '-'}₹${netWorth.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: netWorth >= 0 ? Colors.amber : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 20),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          "₹${amount.toStringAsFixed(2)}",
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
            child: Text("System Offline. Please log in.",
                style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Merchant's Ledger"),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionDialog(),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
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
              return const Center(child: CircularProgressIndicator());
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
                // 1. The new Summary Dashboard
                _buildSummaryDashboard(totalOwedToMe, totalIOwe),

                // 2. The Ledger List (or Empty state)
                Expanded(
                  child: ledgers.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          "Your ledger is empty.\nAdd an entry to track debts and loans.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: ledgers.length,
                    itemBuilder: (context, index) {
                      final doc = ledgers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final personName = data['personName'] ?? 'Unknown';
                      final totalBalance = (data['totalBalance'] as num?)?.toDouble() ?? 0.0;

                      final rawTransactions = data['transactions'] as List<dynamic>? ?? [];
                      final transactions = rawTransactions
                          .map((t) => Map<String, dynamic>.from(t as Map))
                          .toList()
                          .reversed
                          .toList();

                      String balanceText;
                      Color balanceColor;

                      if (totalBalance > 0) {
                        balanceText = "They owe you: ₹${totalBalance.toStringAsFixed(2)}";
                        balanceColor = Colors.amber;
                      } else if (totalBalance < 0) {
                        balanceText = "You owe them: ₹${totalBalance.abs().toStringAsFixed(2)}";
                        balanceColor = Colors.redAccent;
                      } else {
                        balanceText = "Accounts Settled";
                        balanceColor = Colors.tealAccent;
                      }

                      return Card(
                        color: const Color(0xFF16213E),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: balanceColor.withOpacity(0.3), width: 1),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          iconColor: Colors.white,
                          collapsedIconColor: Colors.white70,
                          title: Text(
                            personName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          ),
                          subtitle: Text(
                            balanceText,
                            style: TextStyle(color: balanceColor, fontWeight: FontWeight.w600),
                          ),
                          children: [
                            const Divider(color: Colors.white24),
                            if (transactions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text("No transaction history.", style: TextStyle(color: Colors.grey)),
                              ),
                            ...transactions.map((tx) {
                              final isLent = tx['isLent'] ?? true;
                              final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                              final desc = tx['description'] ?? '';
                              final timestamp = tx['timestamp'] as Timestamp?;

                              return ListTile(
                                onLongPress: () => _confirmDeleteTransaction(doc.id, tx),
                                leading: CircleAvatar(
                                  backgroundColor: isLent ? Colors.amber.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                                  child: Icon(
                                    isLent ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: isLent ? Colors.amber : Colors.redAccent,
                                  ),
                                ),
                                title: Text(desc, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(
                                  timestamp != null ? _formatDate(timestamp) : 'Unknown Date',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                ),
                                trailing: Text(
                                  "${isLent ? '+' : '-'}₹${amount.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: isLent ? Colors.amber : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }),
                            if (transactions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text("Long-press a transaction to delete it.", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic)),
                              ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.purpleAccent,
                                          side: const BorderSide(color: Colors.purpleAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                      ),
                                      onPressed: () => _showTransactionDialog(
                                        existingDocId: doc.id,
                                        existingName: personName,
                                      ),
                                      icon: const Icon(Icons.add_circle_outline),
                                      label: const Text("Update Balance"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                    ),
                                    onPressed: () => _confirmDeleteLedger(doc.id, personName),
                                    child: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
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