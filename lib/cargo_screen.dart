// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE SQL — run once in your Supabase SQL Editor:
//
// CREATE TABLE cargo_posts (
//   id             uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
//   farmer_id      uuid    REFERENCES farmers(id) ON DELETE CASCADE,
//   farmer_name    text,
//   barangay       text,
//   crop_name      text    NOT NULL,
//   quantity_kg    numeric NOT NULL,
//   market_name    text    NOT NULL,
//   departure_date date    NOT NULL,
//   notes          text,
//   is_open        boolean DEFAULT true,
//   created_at     timestamptz DEFAULT now()
// );
// ALTER TABLE cargo_posts ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "anon all" ON cargo_posts FOR ALL TO anon USING (true) WITH CHECK (true);
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'app_config.dart';

class CargoScreen extends StatefulWidget {
  const CargoScreen({super.key});
  @override
  State<CargoScreen> createState() => _CargoScreenState();
}

class _CargoScreenState extends State<CargoScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  Map<String, dynamic>? _farmer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _farmer = await AuthService.getLocalFarmer();
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final data = await Supabase.instance.client
          .from('cargo_posts')
          .select('*, farmers(phone)')
          .eq('is_open', true)
          .gte('departure_date', today)
          .order('departure_date', ascending: true);
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
          'Cargo Sharing',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _farmer == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'cargo_fab',
              backgroundColor: const Color(0xFF1C3A28),
              icon: const Icon(Icons.local_shipping, color: Color(0xFFE8C96A)),
              label: const Text(
                'Post Cargo',
                style: TextStyle(color: Color(0xFFE8C96A)),
              ),
              onPressed: _showAddSheet,
            ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : _posts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No open cargo posts.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  if (_farmer != null)
                    const Text(
                      'Tap the button below to share a truck.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF1C3A28),
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _posts.length,
                itemBuilder: (_, i) => _buildCard(_posts[i]),
              ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> p) {
    final crop = p['crop_name'] as String? ?? '';
    final kg = (p['quantity_kg'] as num?)?.toDouble() ?? 0;
    final market = p['market_name'] as String? ?? '';
    final depStr = p['departure_date'] as String? ?? '';
    final dt = DateTime.tryParse(depStr);
    final farmerName = p['farmer_name'] as String? ?? 'Unknown';
    final barangay = p['barangay'] as String? ?? '';
    final notes = p['notes'] as String? ?? '';
    final phone = (p['farmers'] as Map?)?['phone'] as String? ?? '';
    final isOwn = p['farmer_id'] == _farmer?['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping,
                  color: Color(0xFF2D5A3D),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$crop  →  $market',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1C3A28),
                    ),
                  ),
                ),
                if (isOwn)
                  GestureDetector(
                    onTap: () => _closePost(p['id'] as String),
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _tag('${kg.toStringAsFixed(0)} kg', const Color(0xFF2D5A3D)),
                const SizedBox(width: 6),
                _tag(
                  dt != null ? DateFormat('MMM d').format(dt) : depStr,
                  const Color(0xFF0891B2),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$farmerName  ·  $barangay',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                if (phone.isNotEmpty && !isOwn)
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call, color: Color(0xFF16A34A), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Call',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (notes.isNotEmpty)
              Text(
                notes,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
    ),
  );

  Future<void> _closePost(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close this post?'),
        content: const Text('Mark this cargo post as filled/closed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C3A28),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Post'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client
          .from('cargo_posts')
          .update({'is_open': false})
          .eq('id', id);
      _load();
    }
  }

  void _showAddSheet() {
    String crop = AppConfig.instance.crops.first;
    String market = AppConfig.instance.markets.first;
    DateTime dep = DateTime.now().add(const Duration(days: 1));
    final kgCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post Cargo Space',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A28),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Let others know you have truck space available.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Crop',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  initialValue: crop,
                  items: AppConfig.instance.crops
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setSheet(() => crop = v!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Destination Market',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  initialValue: market,
                  items: AppConfig.instance.markets
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setSheet(() => market = v!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kgCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Available space (kg) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Departure Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dep,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setSheet(() => dep = picked);
                    }
                  },
                  child: Text(
                    DateFormat('MMM d, yyyy').format(dep),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: saving || kgCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              await Supabase.instance.client
                                  .from('cargo_posts')
                                  .insert({
                                    'farmer_id': _farmer!['id'],
                                    'farmer_name': _farmer!['name'],
                                    'barangay': _farmer!['barangay'] ?? '',
                                    'crop_name': crop,
                                    'quantity_kg':
                                        double.tryParse(kgCtrl.text.trim()) ??
                                        0,
                                    'market_name': market,
                                    'departure_date': dep
                                        .toIso8601String()
                                        .substring(0, 10),
                                    'notes': notesCtrl.text.trim(),
                                  });
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              _load();
                            } catch (_) {
                              setSheet(() => saving = false);
                            }
                          },
                    child: saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Post', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
