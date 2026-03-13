// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE SQL — run once in your Supabase SQL Editor:
//
// CREATE TABLE traders (
//   id          uuid  DEFAULT gen_random_uuid() PRIMARY KEY,
//   name        text  NOT NULL,
//   phone       text,
//   location    text,
//   crops_bought text[] DEFAULT '{}',
//   notes       text,
//   created_at  timestamptz DEFAULT now()
// );
// ALTER TABLE traders ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "anon read"   ON traders FOR SELECT TO anon USING (true);
// CREATE POLICY "anon insert" ON traders FOR INSERT TO anon WITH CHECK (true);
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';

class TraderDirectoryScreen extends StatefulWidget {
  const TraderDirectoryScreen({super.key});
  @override
  State<TraderDirectoryScreen> createState() => _TraderDirectoryState();
}

class _TraderDirectoryState extends State<TraderDirectoryScreen> {
  List<Map<String, dynamic>> _traders = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('traders')
          .select()
          .order('name', ascending: true);
      setState(() {
        _traders = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _traders;
    final q = _search.toLowerCase();
    return _traders.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final loc = (t['location'] as String? ?? '').toLowerCase();
      final crops = (t['crops_bought'] as List? ?? []).join(' ').toLowerCase();
      return name.contains(q) || loc.contains(q) || crops.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: const Text(
          'Trader Directory',
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'trader_fab',
        backgroundColor: const Color(0xFF1C3A28),
        onPressed: _showAddSheet,
        child: const Icon(Icons.person_add, color: Color(0xFFE8C96A)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, location or crop…',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2D5A3D)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
                  )
                : _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No traders found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF1C3A28),
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildCard(_filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> t) {
    final name = t['name'] as String? ?? '';
    final phone = t['phone'] as String? ?? '';
    final location = t['location'] as String? ?? '';
    final crops = (t['crops_bought'] as List?)?.cast<String>() ?? [];
    final notes = t['notes'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0891B2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C3A28),
                        ),
                      ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.call, color: Color(0xFF16A34A)),
                    onPressed: () async {
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                  ),
              ],
            ),
            if (crops.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: crops
                    .map(
                      (c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(
                          0xFF0891B2,
                        ).withOpacity(0.1),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                notes,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final selectedCrops = <String>{};
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
                  'Add Trader / Buyer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A28),
                  ),
                ),
                const SizedBox(height: 16),
                _field(nameCtrl, 'Trader Name *'),
                const SizedBox(height: 10),
                _field(phoneCtrl, 'Phone Number', type: TextInputType.phone),
                const SizedBox(height: 10),
                _field(locationCtrl, 'Location / Market'),
                const SizedBox(height: 10),
                const Text(
                  'Crops They Buy',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: AppConfig.instance.crops.map((c) {
                    final sel = selectedCrops.contains(c);
                    return FilterChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      selectedColor: const Color(0xFF0891B2).withOpacity(0.25),
                      onSelected: (_) => setSheet(
                        () => sel
                            ? selectedCrops.remove(c)
                            : selectedCrops.add(c),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _field(notesCtrl, 'Notes (optional)'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: saving || nameCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              await Supabase.instance.client
                                  .from('traders')
                                  .insert({
                                    'name': nameCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'location': locationCtrl.text.trim(),
                                    'crops_bought': selectedCrops.toList(),
                                    'notes': notesCtrl.text.trim(),
                                  });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            } catch (_) {
                              setSheet(() => saving = false);
                            }
                          },
                    child: saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Add Trader',
                            style: TextStyle(fontSize: 15),
                          ),
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

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
