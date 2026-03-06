import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'register_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? _farmer; // null = not registered
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkFarmer();
  }

  // Check if this device has a registered farmer
  Future<void> _checkFarmer() async {
    final farmer = await AuthService.getLocalFarmer();
    setState(() {
      _farmer = farmer;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '👤 My Profile',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : _farmer == null
          ? _buildNotRegistered()
          : _buildProfile(),
    );
  }

  // ── NOT REGISTERED ────────────────────────────────────────
  Widget _buildNotRegistered() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.agriculture, size: 80, color: Color(0xFF4A8C5C)),
            const SizedBox(height: 20),
            const Text(
              'Welcome, Farmer!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Register to track your supply reports,\n'
              'save your farm location, and get personalised\n'
              'price alerts for your crops.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A28),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.app_registration),
                label: const Text(
                  'Register as a Farmer',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                  if (result == 'registered') _checkFarmer();
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Already registered on another device?\n'
              'Log in with your phone number + PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── REGISTERED PROFILE ────────────────────────────────────
  Widget _buildProfile() {
    final name = _farmer!['name'] as String? ?? 'Farmer';
    final barangay = _farmer!['barangay'] as String? ?? '';
    final crops = (_farmer!['crops_grown'] as List?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF2D5A3D),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C3A28),
                          ),
                        ),
                        Text(
                          barangay,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Crops grown
          const Text(
            'My Crops',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1C3A28),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: crops
                .map(
                  (c) => Chip(
                    label: Text(c),
                    backgroundColor: const Color(0xFF2D5A3D).withOpacity(0.15),
                    labelStyle: const TextStyle(color: Color(0xFF1C3A28)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'More profile features coming in Day 10.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Spacer(),
          // Log out
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Log out', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await AuthService.logOut();
              _checkFarmer();
            },
          ),
        ],
      ),
    );
  }
}
