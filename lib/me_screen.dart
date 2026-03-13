import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import 'biometric_service.dart';
import 'encoder_screen.dart';
import 'admin_screen.dart';
import 'encoder_log_screen.dart';
import 'edit_profile_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? _farmer;
  List<Map<String, dynamic>> _myReports = [];
  bool _loading = true;
  bool _biometricAvailable = false;
  String _role = 'farmer';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final farmer = await AuthService.getLocalFarmer();
    final role = await AuthService.getLocalRole();

    List<Map<String, dynamic>> reports = [];
    if (farmer != null) {
      try {
        final data = await Supabase.instance.client
            .from('supply_reports')
            .select()
            .eq('farmer_id', farmer['id'])
            .order('reported_at', ascending: false)
            .limit(5);
        reports = List<Map<String, dynamic>>.from(data);
      } catch (_) {}
    }

    final bioAvailable = await BiometricService.isAvailable();

    setState(() {
      _farmer = farmer;
      _role = role;
      _myReports = reports;
      _biometricAvailable = bioAvailable;
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
          '👤 My Farm',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_farmer != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
              onPressed: _reload,
            ),
        ],
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
              'Register once to track your supply reports and '
              'get personalised price alerts.',
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
                  final r = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                  if (r == 'registered') _reload();
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2D5A3D)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.login, color: Color(0xFF2D5A3D)),
                label: const Text(
                  'Already registered? Log In',
                  style: TextStyle(color: Color(0xFF2D5A3D), fontSize: 15),
                ),
                onPressed: () async {
                  final r = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  if (r == 'logged_in') _reload();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FULL PROFILE ──────────────────────────────────────────
  Widget _buildProfile() {
    final name = _farmer!['name'] as String? ?? 'Farmer';
    final barangay = _farmer!['barangay'] as String? ?? '';
    final crops = (_farmer!['crops_grown'] as List?)?.cast<String>() ?? [];
    final lat = _farmer!['latitude'] as double?;
    final lng = _farmer!['longitude'] as double?;
    final farmerId = _farmer!['id'] as String;

    return RefreshIndicator(
      color: const Color(0xFF1C3A28),
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(name, barangay),
          const SizedBox(height: 12),
          if (lat != null && lng != null) _gpsCard(lat, lng),
          if (lat != null) const SizedBox(height: 12),
          _cropsCard(crops),
          const SizedBox(height: 12),
          _activityCard(),
          const SizedBox(height: 12),
          if (_biometricAvailable) _biometricInfoTile(),
          if (_biometricAvailable) const SizedBox(height: 12),

          // ── ENCODER / ADMIN ACTIONS ──────────────────────
          if (_role == 'encoder' || _role == 'admin') ...[
            _sectionHeader('Encoder Actions'),
            _encoderTile(),
            const SizedBox(height: 4),
            _encoderLogTile(),
            const SizedBox(height: 4),
          ],
          if (_role == 'admin') ...[
            _sectionHeader('Admin'),
            _adminTile(),
            const SizedBox(height: 4),
          ],

          // ── SETTINGS ─────────────────────────────────────
          _sectionHeader('Settings'),
          _changePinTile(farmerId),
          const SizedBox(height: 4),
          _logOutTile(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerCard(String name, String barangay) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF2D5A3D),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C3A28),
                          ),
                        ),
                      ),
                      if (_role == 'encoder' || _role == 'admin')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _role == 'admin'
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF0891B2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (barangay.isNotEmpty)
                    Text(
                      barangay,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                ],
              ),
            ),
            // Edit button
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFF2D5A3D), size: 20),
              onPressed: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(farmer: _farmer!),
                  ),
                );
                if (result == 'updated') _reload();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gpsCard(double lat, double lng) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.location_on, color: Color(0xFF2D5A3D), size: 18),
                SizedBox(width: 6),
                Text(
                  'Farm Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(
                Icons.map_outlined,
                color: Color(0xFF1D4ED8),
                size: 16,
              ),
              label: const Text(
                'Open in Google Maps',
                style: TextStyle(color: Color(0xFF1D4ED8)),
              ),
              onPressed: () async {
                final url = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                );
                if (await canLaunchUrl(url)) launchUrl(url);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cropsCard(List<String> crops) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Crops',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 10),
            crops.isEmpty
                ? const Text(
                    'No crops added yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: crops
                        .map(
                          (c) => Chip(
                            label: Text(c),
                            backgroundColor: const Color(
                              0xFF2D5A3D,
                            ).withOpacity(0.15),
                            labelStyle: const TextStyle(
                              color: Color(0xFF1C3A28),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _activityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Supply Reports',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 10),
            _myReports.isEmpty
                ? const Text(
                    'No supply reports yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                : Column(
                    children: _myReports.map((r) {
                      final crop = r['crop_name'] as String? ?? '';
                      final market = r['market_name'] as String? ?? '';
                      final forDate = r['planned_for'] as String? ?? '';
                      final ts = DateTime.tryParse(
                        r['reported_at']?.toString() ?? '',
                      );
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.grass,
                          color: Color(0xFF2D5A3D),
                          size: 20,
                        ),
                        title: Text(
                          '$crop → $market',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          forDate,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: ts != null
                            ? Text(
                                DateFormat('MMM d').format(ts),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ── BIOMETRIC INFO TILE ───────────────────────────────────
  Widget _biometricInfoTile() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fingerprint, color: Color(0xFF2D5A3D)),
        title: const Text('Fingerprint / Face ID'),
        subtitle: const Text(
          'Active — use biometrics on the login screen',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.check_circle, color: Color(0xFF2D5A3D)),
      ),
    );
  }

  // ── ENCODER TILE (encoder + admin) ───────────────────────
  Widget _encoderTile() {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.price_change_outlined,
          color: Color(0xFF0891B2),
        ),
        title: const Text(
          'Submit Market Price',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          "Enter today's price for a crop",
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EncoderScreen()),
        ),
      ),
    );
  }

  // ── ADMIN TILE (admin only) ───────────────────────────────
  Widget _adminTile() {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.people_alt_outlined,
          color: Color(0xFF7C3AED),
        ),
        title: const Text(
          'All Farmers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'View all registered farmers',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _encoderLogTile() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history, color: Color(0xFF2D5A3D)),
        title: const Text('Price Activity Log',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('View recent price submissions',
            style: TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const EncoderLogScreen()),
        ),
      ),
    );
  }

  Widget _changePinTile(String farmerId) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_reset, color: Color(0xFF2D5A3D)),
        title: const Text('Change PIN'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showChangePinSheet(farmerId),
      ),
    );
  }

  Widget _logOutTile() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Log Out', style: TextStyle(color: Colors.red)),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Log Out?'),
              content: const Text(
                'You will need your phone number and PIN to log back in.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await AuthService.logOut();
            _reload();
          }
        },
      ),
    );
  }

  // ── CHANGE PIN BOTTOM SHEET ───────────────────────────────
  void _showChangePinSheet(String farmerId) {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    String? sheetError;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C3A28),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: curCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              if (sheetError != null)
                Text(sheetError!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A28),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final n = newCtrl.text.trim();
                          if (newCtrl.text != confCtrl.text) {
                            setSheet(
                              () => sheetError = 'New PINs do not match.',
                            );
                            return;
                          }
                          if (n.length != 6) {
                            setSheet(
                              () => sheetError = 'PIN must be 6 digits.',
                            );
                            return;
                          }
                          setSheet(() => saving = true);
                          final ok = await AuthService.changePin(
                            farmerId: farmerId,
                            currentPin: curCtrl.text.trim(),
                            newPin: n,
                          );
                          if (ok) {
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PIN changed!'),
                                  backgroundColor: Color(0xFF2D5A3D),
                                ),
                              );
                            }
                          } else {
                            setSheet(() {
                              saving = false;
                              sheetError = 'Current PIN is incorrect.';
                            });
                          }
                        },
                  child: saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save New PIN',
                          style: TextStyle(fontSize: 15),
                        ),
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
