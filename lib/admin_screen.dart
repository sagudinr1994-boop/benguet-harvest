// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE SQL for price approval workflow — run once:
//
// ALTER TABLE prices ADD COLUMN IF NOT EXISTS status text DEFAULT 'published';
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  bool _loadingPending = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _loadPending();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final farmers = await AdminService.getAllFarmers();
      setState(() {
        _farmers = farmers;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Admin load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final data = await Supabase.instance.client
          .from('prices')
          .select()
          .eq('status', 'pending')
          .order('date_updated', ascending: false);
      setState(() {
        _pending = List<Map<String, dynamic>>.from(data);
        _loadingPending = false;
      });
    } catch (_) {
      setState(() => _loadingPending = false);
    }
  }

  Future<void> _approve(String id) async {
    await Supabase.instance.client
        .from('prices')
        .update({'status': 'published'}).eq('id', id);
    _loadPending();
  }

  Future<void> _reject(String id) async {
    await Supabase.instance.client
        .from('prices')
        .delete()
        .eq('id', id);
    _loadPending();
  }

  // Filter farmers by search text
  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _farmers;
    final q = _search.toLowerCase();
    return _farmers.where((f) {
      final name = (f['name'] as String? ?? '').toLowerCase();
      final barangay = (f['barangay'] as String? ?? '').toLowerCase();
      return name.contains(q) || barangay.contains(q);
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
          'Admin',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: () {
              _load();
              _loadPending();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE8C96A),
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFE8C96A),
          tabs: [
            Tab(
              text: _loading
                  ? 'Farmers'
                  : 'Farmers (${_farmers.length})',
            ),
            Tab(
              text: _loadingPending
                  ? 'Pending'
                  : 'Pending (${_pending.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: FARMERS ────────────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                hintText: 'Search by name or barangay...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Farmer list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
                  )
                : _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No farmers found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _farmerCard(_filtered[i]),
                  ),
          ),
        ],
      ),
          // ── TAB 2: PENDING PRICES ─────────────────────
          _buildPendingTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_loadingPending) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1C3A28)));
    }
    if (_pending.isEmpty) {
      return const Center(
        child: Text(
          'No pending prices to review.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pending.length,
      itemBuilder: (_, i) {
        final p = _pending[i];
        final crop = p['crop_name'] as String? ?? '';
        final market = p['market_name'] as String? ?? '';
        final price =
            (p['price_per_kilo'] as num?)?.toDouble() ?? 0;
        final date = p['date_for'] as String? ?? '';
        final updated = DateTime.tryParse(
            p['date_updated']?.toString() ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$crop  ·  ₱${price.toStringAsFixed(0)}/kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1C3A28)),
                ),
                Text(
                  '$market  ·  $date',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
                if (updated != null)
                  Text(
                    'Submitted: ${DateFormat("MMM d, h:mm a").format(updated)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFDC2626)),
                        ),
                        icon: const Icon(Icons.close,
                            color: Color(0xFFDC2626),
                            size: 16),
                        label: const Text('Reject',
                            style: TextStyle(
                                color: Color(0xFFDC2626))),
                        onPressed: () =>
                            _reject(p['id'] as String),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF1C3A28),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check,
                            size: 16),
                        label: const Text('Approve'),
                        onPressed: () =>
                            _approve(p['id'] as String),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _farmerCard(Map<String, dynamic> farmer) {
    final name = farmer['name'] as String? ?? 'Unknown';
    final barangay = farmer['barangay'] as String? ?? '';
    final phone = farmer['phone'] as String? ?? '';
    final role = farmer['role'] as String? ?? 'farmer';
    final hasGps = farmer['latitude'] != null;
    final crops = (farmer['crops_grown'] as List?)?.cast<String>() ?? [];
    final active = farmer['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + role badge
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2D5A3D),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C3A28),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (role != 'farmer') _roleBadge(role),
                          if (!active) _badge('Inactive', Colors.grey),
                        ],
                      ),
                      Text(
                        '$barangay  ·  $phone',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasGps ? Icons.gps_fixed : Icons.gps_off,
                  size: 18,
                  color: hasGps ? const Color(0xFF2D5A3D) : Colors.grey,
                ),
              ],
            ),
            // Crops
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
                          0xFF2D5A3D,
                        ).withOpacity(0.1),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isAdmin = role == 'admin';
    return _badge(
      role[0].toUpperCase() + role.substring(1),
      isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF0891B2),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    ),
  );
}
