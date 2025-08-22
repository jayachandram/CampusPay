// lib/profile_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'role_selection_page.dart'; // <-- CORRECTED IMPORT

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _phoneController = TextEditingController();
  final _secondaryEmailController = TextEditingController();
  final _user = FirebaseAuth.instance.currentUser;
  final _dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final snapshot = await _dbRef.child('users/${_user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          _phoneController.text = _userData?['phoneNumber'] ?? '';
          _secondaryEmailController.text = _userData?['secondaryEmail'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showFeedback('Could not fetch user data: $e');
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
      await _dbRef.child('users/${_user.uid}').update({
        'phoneNumber': _phoneController.text.trim(),
        'secondaryEmail': _secondaryEmailController.text.trim(),
      });
      if (mounted) {
        _showFeedback('Profile updated successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) _showFeedback('Failed to update profile: $e');
    }
  }

  Future<void> _updatePassword() async {
    final newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Password'),
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
                  _showFeedback(
                      'Failed to update password. Please log out and log in again.');
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePin() async {
    final newPinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update PIN'),
        content: TextField(
            controller: newPinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'New 4-Digit PIN')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newPin = newPinController.text.trim();
              if (newPin.length != 4) {
                _showFeedback('PIN must be exactly 4 digits.');
                return;
              }
              await _dbRef.child('users/${_user!.uid}').update({'pin': newPin});
              if (mounted) {
                Navigator.of(context).pop();
                _showFeedback('PIN updated successfully!', isError: false);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRfidBlock() async {
    if (_userData == null) return;
    bool currentStatus = _userData!['isCardBlocked'] ?? false;
    await _dbRef
        .child('users/${_user!.uid}')
        .update({'isCardBlocked': !currentStatus});
    _fetchUserData(); // Refresh the UI to show the new status
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          // NAVIGATE TO THE ROLE SELECTION PAGE
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
        title: const Text('My Profile'),
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
          : _userData == null
              ? const Center(child: Text('Could not load user data.'))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildProfileHeader(theme, _userData!),
                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, 'User Details'),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          _buildInfoTile(
                              icon: Icons.email_outlined,
                              title: 'Primary Email (Cannot change)',
                              value: _userData!['email'] ?? ''),
                          _buildEditableTile(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined),
                          _buildEditableTile(
                              controller: _secondaryEmailController,
                              label: 'Secondary Email',
                              icon: Icons.alternate_email),
                          _buildInfoTile(
                              icon: Icons.nfc_outlined,
                              title: 'RFID Number (Cannot change)',
                              value: _userData!['rfidNumber'] ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, 'Security'),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          _buildActionTile(
                              icon: Icons.password_rounded,
                              title: 'Update PIN',
                              onTap: _updatePin),
                          _buildActionTile(
                              icon: Icons.lock_reset_rounded,
                              title: 'Update Password',
                              onTap: _updatePassword),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildBlockCardButton(
                        context, _userData!['isCardBlocked'] ?? false),
                    const SizedBox(height: 16),
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
    // This widget is now much simpler. It is no longer tappable.
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade300,
          // Always show the local asset image
          child: ClipOval(
            child: Image.asset(
                              'assets/images/default_avatar.jpg',
              fit: BoxFit.cover,
              width: 100,
              height: 100,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(userData['name'] ?? 'Student Name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(userData['email'] ?? 'student.email@campus.edu',
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
        decoration: InputDecoration(
          labelText: label,
          icon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildBlockCardButton(BuildContext context, bool isBlocked) {
    return OutlinedButton.icon(
      icon: Icon(isBlocked ? Icons.check_circle_outline : Icons.block_rounded),
      label: Text(isBlocked ? 'Unblock RFID Card' : 'Block RFID Card'),
      onPressed: _toggleRfidBlock,
      style: OutlinedButton.styleFrom(
        foregroundColor: isBlocked ? Colors.green : Colors.red,
        side: BorderSide(color: isBlocked ? Colors.green : Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
