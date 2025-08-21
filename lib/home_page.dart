// lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'profile_page.dart';
import 'transactions_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _user = FirebaseAuth.instance.currentUser;

  // Use a separate Future for user data and transactions
  Future<DataSnapshot>? _userDataFuture;
  Future<DataSnapshot>? _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (_user != null) {
      setState(() {
        _userDataFuture =
            FirebaseDatabase.instance.ref('users/${_user.uid}').get();
        _transactionsFuture = FirebaseDatabase.instance
            .ref('users/${_user.uid}/transactions')
            .limitToLast(3)
            .get();
      });
    }
  }

  Future<void> _refreshData() async {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: FutureBuilder<DataSnapshot>(
          future: _userDataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data?.value != null) {
              final userData =
                  Map<String, dynamic>.from(snapshot.data!.value as Map);
              return GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (context) => const ProfilePage()))
                      .then((_) => _refreshData());
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData['name'] ?? 'Student Name',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(userData['rollNumber'] ?? 'Roll Number',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600])),
                  ],
                ),
              );
            }
            return const Text('Loading...');
          },
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (context) => const ProfilePage()))
                  .then((_) => _refreshData());
            },
            // The FutureBuilder is removed, we now show the asset directly
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/default_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NotificationsPage())),
            icon: Icon(Icons.notifications_none_rounded,
                color: theme.colorScheme.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            FutureBuilder<DataSnapshot>(
              future: _userDataFuture,
              builder: (context, snapshot) {
                double balance = 0.0;
                if (snapshot.hasData && snapshot.data?.value != null) {
                  final userData =
                      Map<String, dynamic>.from(snapshot.data!.value as Map);
                  balance = (userData['balance'] ?? 0.0).toDouble();
                }
                return _buildBalanceCard(theme, balance);
              },
            ),
            const SizedBox(height: 24),
            _buildRecentTransactions(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme, double balance) {
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Balance',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('₹ ${balance.toStringAsFixed(2)}',
                style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {}, // TODO: Implement Top-up logic
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Top-up'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {}, // TODO: Implement Withdraw logic
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    label: const Text('Withdraw'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const AllTransactionsPage())),
              child: const Text('More'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<DataSnapshot>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data?.value == null) {
              return const Center(child: Text('No recent transactions.'));
            }
            final transactionsData =
                Map<String, dynamic>.from(snapshot.data!.value as Map);
            final transactions = transactionsData.entries
                .map((e) => Map<String, dynamic>.from(e.value as Map))
                .toList();
            // Sort by timestamp descending to show the newest first
            transactions
                .sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

            return Column(
              children: transactions.map((tx) {
                final isCredit = tx['type'] == 'credit';
                final amount = (tx['amount'] ?? 0.0).toDouble();
                return _buildTransactionItem(
                  icon: isCredit
                      ? Icons.add_card_rounded
                      : Icons.fastfood_rounded,
                  color: isCredit ? Colors.green : Colors.orange,
                  title: tx['merchantName'] ?? 'N/A',
                  subtitle: tx['timestamp']?.substring(0, 10) ?? 'No date',
                  amount:
                      '${isCredit ? '+' : '-'} ₹${amount.abs().toStringAsFixed(2)}',
                  amountColor: isCredit
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                );
              }).toList(),
            );
          },
        )
      ],
    );
  }

  Widget _buildTransactionItem(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required String amount,
      required Color amountColor}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(amount,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)),
      ),
    );
  }
}
