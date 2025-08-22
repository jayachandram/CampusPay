// lib/topup_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

// Import the new PaymentService
import 'services/payment_service.dart';
import 'firebase_options.dart';

// --- Main Application Entry Point ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Pay',
      theme: ThemeData(
        // Using the modern ColorScheme.fromSeed instead of the deprecated primarySwatch
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Use AuthWrapper to ensure user is logged in before showing TopUpPage
      home: const AuthWrapper(),
    );
  }
}

// --- Authentication Wrapper ---
// This widget checks the user's login state and directs them accordingly.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // If user is logged in, show the TopUpPage
          return const TopUpPage();
        }
        // If user is not logged in, show a placeholder login page
        return const LoginPagePlaceholder();
      },
    );
  }
}

// --- Placeholder Login Page ---
// In a real app, this would be your full login/signup screen.
class LoginPagePlaceholder extends StatelessWidget {
  const LoginPagePlaceholder({super.key});

  // A simple method to sign in anonymously for demonstration purposes.
  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      // The StreamBuilder in AuthWrapper will automatically handle navigation.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please log in to top-up your account.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signInAnonymously(context),
              child: const Text('Sign In Anonymously (for Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TopUp Page ---
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final TextEditingController _amountController = TextEditingController();
  // It's safer to get the current user instance inside methods rather than storing it.
  final _user = FirebaseAuth.instance.currentUser;
  final _dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  final PaymentService _paymentService = PaymentService();

  final List<double> _quickAmounts = [100.0, 200.0, 500.0, 1000.0, 2000.0];

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  void _initializePayment() {
    _paymentService.initialize(
      onPaymentSuccess: _onPaymentSuccess,
      onPaymentFailure: _onPaymentFailure,
      onExternalWallet: _onExternalWallet,
    );
  }

  void _selectAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      // Use the service to update balance
      await _paymentService.updateBalanceAfterPayment(
        paymentId: response.paymentId ?? 'N/A',
        amount: amount,
        userId: _user!.uid,
      );

      if (mounted) {
        _showFeedback(
          "Payment successful! ₹${amount.toStringAsFixed(2)} has been added to your account.",
          isError: false,
        );
        Navigator.of(context).pop(true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
        _showFeedback("Payment succeeded but failed to update balance: $e",
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onPaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      _showFeedback(
        "Payment failed: ${response.message ?? 'An unknown error occurred'}",
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      _showFeedback(
        "Redirecting to: ${response.walletName}",
        isError: false,
      );
    }
  }

  Future<void> _processTopUp() async {
    // Re-check user status here to ensure they haven't logged out.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showFeedback("Authentication error. Please log in again.",
          isError: true);
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showFeedback("Please enter an amount.", isError: true);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showFeedback("Please enter a valid positive amount.", isError: true);
      return;
    }

    if (amount < 100) {
      _showFeedback("Minimum top-up amount is ₹100.", isError: true);
      return;
    }

    if (amount > 10000) {
      _showFeedback("Maximum top-up amount is ₹10,000.", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userSnapshot = await _dbRef.child('users/${currentUser.uid}').get();
      Map<String, dynamic> userData = {};

      if (userSnapshot.exists && userSnapshot.value != null) {
        userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      }

      final userEmail = currentUser.email ?? 'user@example.com';
      final userName = userData['name'] ?? 'Campus User';
      final userPhone =
          userData['phone'] ?? ''; // Phone is important for Razorpay

      // Use the service to start payment
      await _paymentService.startPayment(
        amount: amount,
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
      );
    } catch (e) {
      if (mounted) {
        _showFeedback("Failed to initiate payment: $e", isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFeedback(String message, {bool isError = true}) {
    if (!mounted) return;
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top-up Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Icon(
                Icons.add_circle_outline_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Add Money to Your Account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the amount you want to add to your campus pay balance.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 32),

              // Quick amount selection
              Text(
                'Quick Select',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickAmounts.map((amount) {
                  final isSelected =
                      _amountController.text == amount.toStringAsFixed(0);
                  return ChoiceChip(
                    label: Text('₹${amount.toStringAsFixed(0)}'),
                    selected: isSelected,
                    onSelected: (_) => _selectAmount(amount),
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.primary)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Custom amount input
              Text(
                'Or Enter a Custom Amount',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'e.g., 150',
                  helperText: 'Minimum: ₹100, Maximum: ₹10,000',
                ),
                onChanged: (_) =>
                    setState(() {}), // To rebuild the choice chips
              ),
              const SizedBox(height: 24),

              // Info card
              Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Top-up Information',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Minimum amount: ₹100\n• Maximum amount: ₹10,000\n• Amount will be added instantly to your balance.\n• All transactions are secure and recorded.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black87, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _processTopUp,
                    child: const Text('Add Money',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// You can keep this page or remove it if not needed.
class MerchantProfilePage extends StatelessWidget {
  const MerchantProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Profile')),
      body: const Center(child: Text('Merchant Profile Page')),
    );
  }
}
