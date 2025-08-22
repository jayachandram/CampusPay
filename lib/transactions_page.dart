// lib/transactions_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  final _user = FirebaseAuth.instance.currentUser;
  Future<DataSnapshot>? _transactionsFuture;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _transactionsFuture = FirebaseDatabase.instance
          .ref('users/${_user.uid}/transactions')
          .get();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: FutureBuilder<DataSnapshot>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (_user == null) {
            return const Center(child: Text('You are not logged in.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data?.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No transactions found.',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          final transactionsData =
              Map<String, dynamic>.from(snapshot.data!.value as Map);
          final transactions = transactionsData.entries
              .map((e) => Map<String, dynamic>.from(e.value as Map))
              .toList();
          // Sort by timestamp descending to show the newest first
          transactions.sort((a, b) =>
              (b['timestamp'] as String).compareTo(a['timestamp'] as String));

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isCredit = tx['type'] == 'credit';
              final amount = (tx['amount'] ?? 0.0).toDouble();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isCredit ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.1),
                    foregroundColor: isCredit ? Colors.green : Colors.orange,
                    child: Icon(isCredit
                        ? Icons.add_card_rounded
                        : Icons.shopping_cart_outlined),
                  ),
                  title: Text(tx['merchantName'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(tx['timestamp']?.substring(0, 10) ??
                      'No date'), // Shows YYYY-MM-DD
                  trailing: Text(
                    '${isCredit ? '+' : '-'} ₹${amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCredit
                          ? Colors.green.shade700
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
