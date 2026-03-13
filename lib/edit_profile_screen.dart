import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'register_screen.dart'; // kBarangays

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;
  const EditProfileScreen({super.key, required this.farmer});
  @override
  State<EditProfileScreen> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late String _barangay;
  late Set<String> _crops;
  double? _latitude;
  double? _longitude;

  bool _saving = false;
  bool _gpsLoading = false;
  String? _error;
  bool _locationChanged = false;

  @override
  void initState() {
    super.initState();
    final f = widget.farmer;
    _nameCtrl = TextEditingController(text: f['name'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: f['phone'] as String? ?? '');
    _barangay = f['barangay'] as String? ?? kBarangays.first;
    // Ensure barangay is in the list
    if (!kBarangays.contains(_barangay)) _barangay = kBarangays.first;
    _crops = Set<String>.from(
        (f['crops_grown'] as List?)?.cast<String>() ?? []);
    _latitude = (f['latitude'] as num?)?.toDouble();
    _longitude = (f['longitude'] as num?)?.toDouble();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureGPS() async {
    setState(() { _gpsLoading = true; _error = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied. Enable in phone settings.';
          _gpsLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationChanged = true;
        _gpsLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not get location. Check that GPS is on.';
        _gpsLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters.');
      return;
    }
    if (phone.length < 11) {
      setState(() => _error = 'Enter a valid 11-digit mobile number.');
      return;
    }

    // Warn if phone changed — it's used for login
    final phoneChanged = phone != (widget.farmer['phone'] as String? ?? '');
    if (phoneChanged) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change phone number?'),
          content: const Text(
            'Your phone number is used to log in. '
            'If you change it, you will need to use the new number next time you log in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A28),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, update'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final updates = <String, dynamic>{
        'name': name,
        'barangay': _barangay,
        'phone': phone,
        'crops_grown': _crops.toList(),
      };
      if (_locationChanged) {
        updates['latitude'] = _latitude;
        updates['longitude'] = _longitude;
      }

      await Supabase.instance.client
          .from('farmers')
          .update(updates)
          .eq('id', widget.farmer['id'] as String);

      if (mounted) Navigator.of(context).pop('updated');
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Failed to save. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
              color: Color(0xFFE8B84B), fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Color(0xFFE8B84B), strokeWidth: 2))
                : const Text(
                    'Save',
                    style: TextStyle(
                        color: Color(0xFFE8B84B),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── NAME ────────────────────────────────────────
            _label('Full Name'),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('e.g. Maria Santos',
                  prefixIcon: Icons.person_outline),
            ),
            const SizedBox(height: 16),

            // ── BARANGAY ────────────────────────────────────
            _label('Barangay / Municipality'),
            DropdownButtonFormField<String>(
              initialValue: _barangay,
              decoration: _dec('Select barangay'),
              items: kBarangays
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _barangay = v!),
            ),
            const SizedBox(height: 16),

            // ── PHONE ────────────────────────────────────────
            _label('Mobile Number'),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dec('09XXXXXXXXX',
                  prefixIcon: Icons.phone_outlined,
                  helperText: 'Used for login — change carefully'),
            ),
            const SizedBox(height: 20),

            // ── CROPS ────────────────────────────────────────
            _label('Crops I Grow'),
            const Text(
              'Tap to select / deselect',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConfig.instance.crops.map((crop) {
                final sel = _crops.contains(crop);
                return FilterChip(
                  label: Text(crop),
                  selected: sel,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _crops.add(crop);
                    } else {
                      _crops.remove(crop);
                    }
                  }),
                  selectedColor:
                      const Color(0xFF2D5A3D).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF1C3A28),
                  labelStyle: TextStyle(
                    color: sel
                        ? const Color(0xFF1C3A28)
                        : Colors.black87,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── GPS LOCATION ─────────────────────────────────
            _label('Farm Location (GPS)'),
            if (_latitude != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _locationChanged
                      ? const Color(0xFFF0FDF4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _locationChanged
                        ? const Color(0xFF4A8C5C)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _locationChanged
                          ? const Color(0xFF2D5A3D)
                          : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_latitude!.toStringAsFixed(5)}, '
                          '${_longitude!.toStringAsFixed(5)}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                        if (_locationChanged)
                          const Text(
                            'Updated — tap Save to confirm',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF2D5A3D)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2D5A3D)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _gpsLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2D5A3D)))
                    : const Icon(Icons.my_location,
                        color: Color(0xFF2D5A3D)),
                label: Text(
                  _latitude != null
                      ? 'Update Farm Location'
                      : 'Set Farm Location',
                  style: const TextStyle(color: Color(0xFF2D5A3D)),
                ),
                onPressed: _gpsLoading ? null : _captureGPS,
              ),
            ),
            if (_latitude == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Your farm location helps BAPTC see where produce comes from '
                  'and places you on the farm map.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),

            // ── ERROR ────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold)),
            ],

            const SizedBox(height: 24),

            // ── SAVE BUTTON ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A28),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28))),
      );

  InputDecoration _dec(String hint,
      {IconData? prefixIcon, String? helperText}) =>
      InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        helperText: helperText,
      );
}
