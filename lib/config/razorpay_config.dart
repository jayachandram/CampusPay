// lib/config/razorpay_config.dart

class RazorpayConfig {
  // Razorpay Test API Keys
  static const String keyId = 'rzp_test_R8HKS5LsToivgB';
  static const String keySecret = 'sIR5ms4LcyZI8IAH6l8o4jdO';
  
  // Razorpay Configuration
  static const String currency = 'INR';
  static const String companyName = 'Campus Pay';
  static const String description = 'Top-up Campus Pay Account';
  static const String logoUrl = 'https://example.com/logo.png'; // Replace with your logo URL
  
  // Payment options
  static const Map<String, dynamic> paymentMethods = {
    'card': true,
    'netbanking': true,
    'wallet': true,
    'upi': true,
  };
}