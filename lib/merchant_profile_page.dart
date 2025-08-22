// lib/merchant_profile_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'role_selection_page.dart';

class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});
  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _phoneController = TextEditingController();
  final _user = FirebaseAuth.instance.currentUser;
  final _dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  Map<String, dynamic>? _merchantData;

  @override
  void initState() {
    super.initState();
    _fetchMerchantData();
  }

  Future<void> _fetchMerchantData() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final snapshot = await _dbRef.child('merchants/${_user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _merchantData = Map<String, dynamic>.from(snapshot.value as Map);
          _phoneController.text = _merchantData?['phoneNumber'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showFeedback('Could not fetch merchant data: $e');
    }
  }

  void _showFeedback(String message, {bool isError = true}) {
    final snackBar = SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green);
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _updateProfile() async {
    if (_user == null) return;
    try {
      await _dbRef.child('merchants/${_user.uid}').update({
        'phoneNumber': _phoneController.text.trim(),
      });
      if (mounted) {
        _showFeedback('Profile updated successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) _showFeedback('Failed to update profile: $e');
    }
  }

  // NEW: Secure password update with re-authentication
  Future<void> _updatePassword() async {
    if (_user == null || _user.email == null) return;

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    // First, ask for the current password to re-authenticate
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-authenticate to continue'),
        content: TextField(
            controller: currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current Password')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                // Create a credential
                final cred = EmailAuthProvider.credential(
                    email: _user.email!,
                    password: currentPasswordController.text.trim());
                // Re-authenticate
                await _user.reauthenticateWithCredential(cred);

                if (mounted) {
                  Navigator.of(context).pop(); // Close the re-auth dialog
                  _showNewPasswordDialog(
                      newPasswordController); // Show the new password dialog
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  _showFeedback(
                      'Authentication failed. Please check your current password.');
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showNewPasswordDialog(TextEditingController newPasswordController) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter New Password'),
        content: TextField(
            controller: newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'New Password (min. 6 characters)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newPassword = newPasswordController.text.trim();
              if (newPassword.length < 6) {
                _showFeedback('Password must be at least 6 characters long.');
                return;
              }
              try {
                await _user?.updatePassword(newPassword);
                if (mounted) {
                  Navigator.of(context).pop();
                  _showFeedback('Password updated successfully!',
                      isError: false);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  _showFeedback('Failed to update password.');
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) _showFeedback('Failed to log out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _updateProfile,
            tooltip: 'Save Changes',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _merchantData == null
              ? const Center(child: Text('Could not load merchant data.'))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildProfileHeader(theme, _merchantData!),
                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, 'Merchant Details'),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          _buildInfoTile(
                              icon: Icons.email_outlined,
                              title: 'Primary Email (Cannot change)',
                              value: _merchantData!['email'] ?? ''),
                          _buildEditableTile(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, 'Security'),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          // REMOVED: Update PIN button
                          _buildActionTile(
                              icon: Icons.lock_reset_rounded,
                              title: 'Update Password',
                              onTap: _updatePassword),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading:
                          Icon(Icons.logout, color: theme.colorScheme.error),
                      title: Text('Log Out',
                          style: TextStyle(color: theme.colorScheme.error)),
                      onTap: () => _logout(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, Map<String, dynamic> userData) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade300,
          child: ClipOval(
              child: Image.asset('assets/images/default_avatar.jpg',
                  fit: BoxFit.cover, width: 100, height: 100)),
        ),
        const SizedBox(height: 12),
        Text(userData['name'] ?? 'Merchant Name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(userData['email'] ?? 'merchant.email@campus.edu',
            style: const TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEditableTile(
      {required TextEditingController controller,
      required String label,
      required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, icon: Icon(icon))),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(title,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[600]));
  }

  Widget _buildInfoTile(
      {required IconData icon, required String title, required String value}) {
    return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
  }

  Widget _buildActionTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap);
  }
}
