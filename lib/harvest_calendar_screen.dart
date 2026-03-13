// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE SQL — run once in your Supabase SQL Editor before using this screen:
//
// CREATE TABLE harvest_plans (
//   id          uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
//   farmer_id   uuid    REFERENCES farmers(id) ON DELETE CASCADE,
//   crop_name   text    NOT NULL,
//   expected_date date  NOT NULL,
//   estimated_kg  numeric DEFAULT 0,
//   notes       text,
//   created_at  timestamptz DEFAULT now()
// );
// ALTER TABLE harvest_plans ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "anon all" ON harvest_plans FOR ALL TO anon USING (true) WITH CHECK (true);
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'app_config.dart';

class HarvestCalendarScreen extends StatefulWidget {
  const HarvestCalendarScreen({super.key});
  @override
  State<HarvestCalendarScreen> createState() => _HarvestCalendarState();
}

class _HarvestCalendarState extends State<HarvestCalendarScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _farmerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = await AuthService.getLocalFarmerId();
    if (id == null) {
      setState(() {
        _farmerId = null;
        _loading = false;
      });
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('harvest_plans')
          .select()
          .eq('farmer_id', id)
          .gte(
            'expected_date',
            DateTime.now().toIso8601String().substring(0, 10),
          )
          .order('expected_date', ascending: true);
      setState(() {
        _farmerId = id;
        _plans = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _farmerId = id;
        _loading = false;
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
          'Harvest Calendar',
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
      floatingActionButton: _farmerId == null
          ? null
          : FloatingActionButton(
              heroTag: 'harvest_fab',
              backgroundColor: const Color(0xFF1C3A28),
              child: const Icon(Icons.add, color: Color(0xFFE8C96A)),
              onPressed: () => _showAddSheet(),
            ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : _farmerId == null
          ? const Center(
              child: Text(
                'Log in to manage your harvest plans.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : _plans.isEmpty
          ? const Center(
              child: Text(
                'No upcoming harvest plans.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF1C3A28),
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _plans.length,
                itemBuilder: (_, i) => _buildCard(_plans[i]),
              ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> plan) {
    final crop = plan['crop_name'] as String? ?? '';
    final dateStr = plan['expected_date'] as String? ?? '';
    final kg = (plan['estimated_kg'] as num?)?.toDouble() ?? 0;
    final notes = plan['notes'] as String? ?? '';
    final dt = DateTime.tryParse(dateStr);
    final daysUntil = dt?.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2D5A3D).withOpacity(0.15),
          child: Text(
            crop.isNotEmpty ? crop[0] : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D5A3D),
            ),
          ),
        ),
        title: Text(
          crop,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dt != null ? DateFormat('EEE, MMM d yyyy').format(dt) : dateStr,
              style: const TextStyle(fontSize: 12),
            ),
            if (kg > 0)
              Text(
                'Est. ${kg.toStringAsFixed(0)} kg',
                style: const TextStyle(fontSize: 12, color: Color(0xFF2D5A3D)),
              ),
            if (notes.isNotEmpty)
              Text(
                notes,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: daysUntil != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: daysUntil <= 3
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  daysUntil == 0 ? 'Today' : '${daysUntil}d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: daysUntil <= 3
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                ),
              )
            : null,
        onLongPress: () => _confirmDelete(plan['id'] as String),
      ),
    );
  }

  void _showAddSheet() {
    String crop = AppConfig.instance.crops.first;
    DateTime date = DateTime.now().add(const Duration(days: 7));
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
                  'Add Harvest Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A28),
                  ),
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
                const SizedBox(height: 12),
                const Text(
                  'Expected Harvest Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kgCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Estimated kg (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
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
                    onPressed: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              await Supabase.instance.client
                                  .from('harvest_plans')
                                  .insert({
                                    'farmer_id': _farmerId,
                                    'crop_name': crop,
                                    'expected_date': date
                                        .toIso8601String()
                                        .substring(0, 10),
                                    'estimated_kg':
                                        double.tryParse(kgCtrl.text.trim()) ??
                                        0,
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
                            'Save Plan',
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

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client
          .from('harvest_plans')
          .delete()
          .eq('id', id);
      _load();
    }
  }
}
