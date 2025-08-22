// lib/withdraw_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final TextEditingController _amountController = TextEditingController();
  final _user = FirebaseAuth.instance.currentUser;
  final _dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  double _currentBalance = 0.0;

  // Quick-select amounts (min ₹100)
  final List<double> _quickAmounts = [100.0, 200.0, 500.0, 1000.0, 2000.0];

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    if (_user == null) return;
    try {
      final snap = await _dbRef.child('users/${_user!.uid}').get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          final raw = data['balance'];
          _currentBalance = raw is num ? raw.toDouble() : 0.0;
        });
      }
    } catch (_) {
      // ignore; keep 0.0
    }
  }

  void _selectAmount(double amount) {
    if (amount <= _currentBalance) {
      setState(() => _amountController.text = amount.toStringAsFixed(0));
    }
  }

  Future<void> _processWithdraw() async {
    FocusScope.of(context).unfocus();

    if (_user == null) {
      _showFeedback("You are not logged in.", isError: true);
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showFeedback("Please enter an amount.", isError: true);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showFeedback("Please enter a valid amount.", isError: true);
      return;
    }

    if (amount > _currentBalance) {
      _showFeedback(
        "Insufficient balance. You have ₹${_currentBalance.toStringAsFixed(2)} available.",
        isError: true,
      );
      return;
    }

    if (amount < 100) {
      _showFeedback("Minimum withdrawal amount is ₹100.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newBalance = _currentBalance - amount;

      await _dbRef.child('users/${_user!.uid}').update({'balance': newBalance});

      final txRef = _dbRef.child('users/${_user!.uid}/transactions').push();
      await txRef.set({
        'type': 'debit',
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'description': 'Withdrawal',
        'merchantName': 'Account Withdrawal',
        'balanceAfter': newBalance,
      });

      if (!mounted) return;
      _showFeedback(
        "Successfully withdrawn ₹${amount.toStringAsFixed(2)} from your account!",
        isError: false,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showFeedback("Failed to process withdrawal: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFeedback(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Money'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      // Let content scroll so it never overflows, even with small screens/keyboard up.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.remove_circle_outline_rounded,
                  size: 80, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Withdraw from Your Account',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the amount you want to withdraw from your campus pay balance',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Balance card
              Card(
                color: theme.colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text('Available Balance',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text('₹${_currentBalance.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Quick select
              Text('Quick Select',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickAmounts.map((amount) {
                  final isAvailable = amount <= _currentBalance;
                  return InkWell(
                    onTap: isAvailable ? () => _selectAmount(amount) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isAvailable
                              ? theme.colorScheme.error
                              : Colors.grey[300]!,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isAvailable ? null : Colors.grey[100],
                      ),
                      child: Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isAvailable
                              ? theme.colorScheme.error
                              : Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Custom amount
              Text('Custom Amount',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  hintText: 'Enter amount',
                ),
              ),
              const SizedBox(height: 24),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange[600], size: 20),
                          const SizedBox(width: 8),
                          Text('Withdrawal Information',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[600],
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Minimum amount: ₹100\n'
                        '• Maximum amount: Your available balance\n'
                        '• Amount will be deducted instantly from your balance\n'
                        '• Transaction will be recorded in your history\n'
                        '• Withdrawal is irreversible',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Withdraw button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _processWithdraw,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      label: const Text('WITHDRAW MONEY'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(
                  height: 8), // little bottom spacing for safe scroll
            ],
          ),
        ),
      ),
    );
  }
}
