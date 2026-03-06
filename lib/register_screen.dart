import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_service.dart';

// The crops a farmer can select (multi-select checkboxes)
const List<String> kAllCrops = [
  'Repolyo',
  'Karot',
  'Patatas',
  'Kamatis',
  'Sitaw',
  'Baguio Beans',
  'Sayote',
  'Petsay',
  'Broccoli',
  'Habitchuelas',
  'Chayote',
  'Lettuce',
];

// Benguet barangays (partial list — add more as needed)
const List<String> kBarangays = [
  'Atok',
  'Bakun',
  'Bokod',
  'Buguias',
  'Itogon',
  'Kabayan',
  'Kapangan',
  'Kibungan',
  'La Trinidad',
  'Mankayan',
  'Sablan',
  'Tuba',
  'Tublay',
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Multi-step form: 0=Name, 1=Barangay+Phone, 2=Crops, 3=GPS, 4=PIN
  int _step = 0;
  bool _submitting = false;

  // Form field values collected across steps
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pin1Ctrl = TextEditingController();
  final _pin2Ctrl = TextEditingController();
  String _barangay = kBarangays[0];
  final _selectedCrops = <String>{}; // Set — no duplicates
  double? _latitude;
  double? _longitude;
  bool _gpsLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pin1Ctrl.dispose();
    _pin2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: Text(
          'Register — Step ${_step + 1} of 5',
          style: const TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 24),
              if (_step == 0) _buildStep0Name(),
              if (_step == 1) _buildStep1Contact(),
              if (_step == 2) _buildStep2Crops(),
              if (_step == 3) _buildStep3GPS(),
              if (_step == 4) _buildStep4PIN(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Green progress bar — fills as steps complete
  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${_step + 1} of 5',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (_step + 1) / 5,
          backgroundColor: const Color(0xFFE5E7EB),
          color: const Color(0xFF2D5A3D),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  // ── STEP 0: Full Name ─────────────────────────────────────
  Widget _buildStep0Name() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What is your full name?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g. Maria Santos',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        _nextButton('Next: Contact Info', () {
          if (_nameCtrl.text.trim().length < 2) {
            setState(() => _errorMessage = 'Please enter your full name.');
          } else {
            setState(() {
              _step = 1;
              _errorMessage = null;
            });
          }
        }),
      ],
    );
  }

  // ── STEP 1: Barangay + Phone ──────────────────────────────
  Widget _buildStep1Contact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where are you from?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _barangay,
          decoration: const InputDecoration(
            labelText: 'Barangay / Municipality',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: kBarangays
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() => _barangay = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            hintText: '09XXXXXXXXX',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        _nextButton('Next: Crops I Grow', () async {
          final phone = _phoneCtrl.text.trim();
          if (phone.length < 11) {
            setState(
              () => _errorMessage = 'Enter a valid 11-digit mobile number.',
            );
            return;
          }
          final exists = await AuthService.phoneExists(phone);
          if (exists) {
            setState(
              () => _errorMessage =
                  'This number is already registered. Please log in instead.',
            );
            return;
          }
          setState(() {
            _step = 2;
            _errorMessage = null;
          });
        }),
      ],
    );
  }

  // ── STEP 2: Crops (multi-select) ──────────────────────────
  Widget _buildStep2Crops() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What crops do you grow?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        const Text(
          'Select all that apply.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAllCrops.map((crop) {
            final selected = _selectedCrops.contains(crop);
            return FilterChip(
              label: Text(crop),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v)
                  _selectedCrops.add(crop);
                else
                  _selectedCrops.remove(crop);
              }),
              selectedColor: const Color(0xFF2D5A3D).withOpacity(0.2),
              checkmarkColor: const Color(0xFF1C3A28),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF1C3A28) : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _nextButton('Next: My Farm Location', () {
          if (_selectedCrops.isEmpty) {
            setState(() => _errorMessage = 'Please select at least one crop.');
          } else {
            setState(() {
              _step = 3;
              _errorMessage = null;
            });
          }
        }),
      ],
    );
  }

  // ── STEP 3: GPS Location ──────────────────────────────────
  Widget _buildStep3GPS() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where is your farm?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        const Text(
          'Tap the button to get your GPS coordinates. '
          'This helps BAPTC see where produce comes from. '
          'You can skip this step.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        if (_latitude != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4A8C5C)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2D5A3D)),
                const SizedBox(width: 8),
                Text(
                  'Lat: ${_latitude!.toStringAsFixed(5)}\n'
                  'Lng: ${_longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _gpsLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: Color(0xFF2D5A3D)),
            label: Text(
              _latitude != null ? 'Update Location' : 'Get My Location',
              style: const TextStyle(color: Color(0xFF2D5A3D)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2D5A3D)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _gpsLoading ? null : _captureGPS,
          ),
        ),
        const SizedBox(height: 24),
        _nextButton('Next: Create PIN', () {
          setState(() {
            _step = 4;
            _errorMessage = null;
          });
        }),
        TextButton(
          onPressed: () => setState(() {
            _step = 4;
            _errorMessage = null;
          }),
          child: const Text(
            'Skip — I\'ll add location later',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // Capture GPS coordinates from the device
  Future<void> _captureGPS() async {
    setState(() {
      _gpsLoading = true;
      _errorMessage = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permission denied. Enable in phone settings.';
          _gpsLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _gpsLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not get location. Check GPS is on.';
        _gpsLoading = false;
      });
    }
  }

  // ── STEP 4: Create PIN ────────────────────────────────────
  Widget _buildStep4PIN() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create your 6-digit PIN',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        const Text(
          'You will use this PIN to log in. Keep it secret.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _pin1Ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'PIN (6 digits)',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin2Ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Confirm PIN',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C3A28),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _submitting ? null : _submitRegistration,
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Complete Registration',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  // ── SUBMIT REGISTRATION ───────────────────────────────────
  Future<void> _submitRegistration() async {
    final pin1 = _pin1Ctrl.text.trim();
    final pin2 = _pin2Ctrl.text.trim();

    if (pin1.length != 6) {
      setState(() => _errorMessage = 'PIN must be exactly 6 digits.');
      return;
    }
    if (pin1 != pin2) {
      setState(() => _errorMessage = 'PINs do not match. Try again.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await AuthService.register(
        name: _nameCtrl.text.trim(),
        barangay: _barangay,
        phone: _phoneCtrl.text.trim(),
        pin: pin1,
        cropsGrown: _selectedCrops.toList(),
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted) Navigator.of(context).pop('registered');
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Registration failed: ${e.toString()}';
      });
    }
  }

  // Reusable Next button
  Widget _nextButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C3A28),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
