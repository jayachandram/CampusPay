import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MerchantWithdrawPage extends StatefulWidget {
  const MerchantWithdrawPage({super.key});

  @override
  State<MerchantWithdrawPage> createState() => _MerchantWithdrawPageState();
}

class _MerchantWithdrawPageState extends State<MerchantWithdrawPage> {
  final TextEditingController _amountController = TextEditingController();
  final _user = FirebaseAuth.instance.currentUser;
  final _dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  double _currentEarnings = 0.0;

  final List<double> _quickAmounts = [100.0, 200.0, 500.0, 1000.0, 2000.0];

  @override
  void initState() {
    super.initState();
    _loadCurrentEarnings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentEarnings() async {
    if (_user == null) return;
    try {
      final merchantSnapshot =
          await _dbRef.child('merchants/${_user.uid}').get();
      if (merchantSnapshot.exists && merchantSnapshot.value != null) {
        final merchantData =
            Map<String, dynamic>.from(merchantSnapshot.value as Map);
        setState(() {
          _currentEarnings =
              double.tryParse(merchantData['balance'].toString()) ?? 0.0;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _selectAmount(double amount) {
    if (amount <= _currentEarnings) {
      setState(() {
        _amountController.text = amount.toString();
      });
    }
  }

  Future<void> _processWithdraw() async {
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

    if (amount > _currentEarnings) {
      _showFeedback(
          "Insufficient earnings. You have ₹${_currentEarnings.toStringAsFixed(2)} available.",
          isError: true);
      return;
    }

    if (amount < 100) {
      _showFeedback("Minimum withdrawal amount is ₹100.", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newEarnings = _currentEarnings - amount;

      await _dbRef.child('merchants/${_user.uid}').update({
        'balance': newEarnings,
      });

      final transactionRef =
          _dbRef.child('merchants/${_user.uid}/transactions').push();
      await transactionRef.set({
        'type': 'debit',
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'description': 'Earnings Withdrawal',
        'studentName': 'Merchant Withdrawal',
        'balanceAfter': newEarnings,
      });

      if (mounted) {
        _showFeedback(
            "Successfully withdrawn ₹${amount.toStringAsFixed(2)} from your earnings!",
            isError: false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showFeedback("Failed to process withdrawal: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFeedback(String message, {bool isError = true}) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Earnings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // ✅ Fix overflow
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Withdraw Your Earnings',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Transfer your earnings to your bank account',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: theme.colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Available Earnings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${_currentEarnings.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Quick Select',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickAmounts.map((amount) {
                  final isAvailable = amount <= _currentEarnings;
                  return InkWell(
                    onTap: isAvailable ? () => _selectAmount(amount) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isAvailable
                              ? theme.colorScheme.primary
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
                              ? theme.colorScheme.primary
                              : Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text(
                'Custom Amount',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Enter amount',
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Withdrawal Information',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Minimum amount: ₹100\n• Maximum amount: Your available earnings\n• Amount will be deducted from your earnings\n• Transaction will be recorded in your history\n• Withdrawal will be processed within 2-3 business days',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _processWithdraw,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('WITHDRAW EARNINGS'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
