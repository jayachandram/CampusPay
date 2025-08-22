// lib/services/payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/razorpay_config.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  late Razorpay _razorpay;
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentFailure;
  Function(ExternalWalletResponse)? _onExternalWallet;

  void initialize({
    required Function(PaymentSuccessResponse) onPaymentSuccess,
    required Function(PaymentFailureResponse) onPaymentFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _onPaymentSuccess = onPaymentSuccess;
    _onPaymentFailure = onPaymentFailure;
    _onExternalWallet = onExternalWallet;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _onPaymentSuccess?.call(response);
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    _onPaymentFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onExternalWallet?.call(response);
  }

  Future<void> startPayment({
    required double amount,
    required String userEmail,
    required String userPhone,
    required String userName,
  }) async {
    var options = {
      'key': RazorpayConfig.keyId,
      'amount': (amount * 100).toInt(),
      'currency': RazorpayConfig.currency,
      'name': RazorpayConfig.companyName,
      'description': RazorpayConfig.description,
      'image': RazorpayConfig.logoUrl,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'method': RazorpayConfig.paymentMethods,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Failed to open Razorpay: $e');
      throw Exception('Failed to open Razorpay: $e');
    }
  }

  // --- UPDATED AND IMPROVED METHOD ---
  Future<void> updateBalanceAfterPayment({
    required String
        paymentId, // <-- CHANGED: Added the missing paymentId parameter
    required String userId,
    required double amount,
  }) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final userBalanceRef = dbRef.child('users/$userId/balance');

    // IMPROVED: Also create a reference to log this transaction for the user's history
    final userTransactionRef = dbRef.child('users/$userId/transactions').push();

    try {
      // IMPROVED: Use a transaction for safe, atomic balance updates.
      // This prevents race conditions where two operations could corrupt the balance.
      final result =
          await userBalanceRef.runTransaction((Object? currentBalance) {
        double newBalance = amount;
        if (currentBalance != null) {
          // Firebase can return int or double, so (currentBalance as num) is safer.
          newBalance += (currentBalance as num).toDouble();
        }
        return Transaction.success(newBalance);
      });

      if (result.committed) {
        // If the balance update was successful, log the transaction.
        await userTransactionRef.set({
          'amount': amount,
          'type': 'credit', // 'credit' for adding money
          'paymentId': paymentId,
          'timestamp':
              ServerValue.timestamp, // Use server-side timestamp for accuracy
          'status': 'success',
          'description': 'Wallet Top-up',
        });
        debugPrint("Balance updated and transaction logged successfully.");
      } else {
        debugPrint("Balance update transaction was aborted.");
        throw Exception('Failed to update balance. Please contact support.');
      }
    } catch (e) {
      debugPrint("Error updating balance: $e");
      // This is a critical failure. You might want to log it to a service
      // like Crashlytics or Sentry for manual review and reconciliation.
      throw Exception('A critical error occurred while updating your balance.');
    }
  }

  Future<void> addTransaction({
    required String userId,
    required String merchantId,
    required double amount,
    required String merchantName,
    required String studentName,
  }) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final transactionId = dbRef.push().key;

    // This is a complex operation. Using a transaction or Cloud Function
    // would be safer here as well, but for now, we'll keep your original logic.
    // The key is to ensure both user and merchant balances are updated together.

    // User transaction (debit)
    await dbRef.child('users/$userId/transactions/$transactionId').set({
      'amount': -amount,
      'merchantName': merchantName,
      'timestamp': ServerValue.timestamp,
      'type': 'debit',
    });

    // Update user balance
    await dbRef
        .child('users/$userId/balance')
        .set(ServerValue.increment(-amount));

    // Merchant transaction (credit)
    await dbRef.child('merchants/$merchantId/transactions/$transactionId').set({
      'amount': amount,
      'studentName': studentName,
      'timestamp': ServerValue.timestamp,
      'type': 'credit',
    });

    // Update merchant balance
    await dbRef
        .child('merchants/$merchantId/balance')
        .set(ServerValue.increment(amount));
  }

  void dispose() {
    _razorpay.clear();
  }
}
