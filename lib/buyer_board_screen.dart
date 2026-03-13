// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE SQL — run once in your Supabase SQL Editor:
//
// -- Main requests table (already created)
// CREATE TABLE IF NOT EXISTS buyer_requests ( ... );
//
// -- NEW: Farmer interest responses
// CREATE TABLE buyer_responses (
//   id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
//   request_id    uuid        NOT NULL,
//   farmer_name   text        NOT NULL,
//   barangay      text,
//   phone         text        NOT NULL,
//   qty_available numeric,
//   created_at    timestamptz DEFAULT now()
// );
// ALTER TABLE buyer_responses ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "anon read"   ON buyer_responses FOR SELECT TO anon USING (true);
// CREATE POLICY "anon insert" ON buyer_responses FOR INSERT TO anon WITH CHECK (true);
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';

const List<String> kBuyerTypes = [
  'Restaurant',
  'Canteen',
  'School / University',
  'Hospital',
  'Supermarket',
  'Individual / Household',
];

class BuyerBoardScreen extends StatefulWidget {
  const BuyerBoardScreen({super.key});
  @override
  State<BuyerBoardScreen> createState() => _BuyerBoardState();
}

class _BuyerBoardState extends State<BuyerBoardScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _cropFilter = 'All';
  Set<String> _myPostIds = {}; // backward-compat for old posts
  Set<String> _myRespondedIds = {};
  String _deviceId = ''; // permanent per-device UUID for ownership
  bool _isAdmin = false;

  static const _postsKey = 'my_buyer_post_ids';
  static const _respondedKey = 'my_buyer_responded_ids';
  static const _deviceKey = 'buyer_device_id';

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _load());
  }

  /// Returns a random hex UUID stored permanently on this device.
  String _generateDeviceId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceKey) ?? '';
    if (deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceKey, deviceId);
    }
    setState(() {
      _deviceId = deviceId;
      _myPostIds = (prefs.getStringList(_postsKey) ?? []).toSet();
      _myRespondedIds = (prefs.getStringList(_respondedKey) ?? []).toSet();
      _isAdmin = (prefs.getString('farmer_role') ?? '') == 'admin';
    });
  }

  Future<void> _saveMyPost(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _myPostIds.add(id);
    await prefs.setStringList(_postsKey, _myPostIds.toList());
    if (mounted) setState(() {});
  }

  Future<void> _saveMyResponse(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    _myRespondedIds.add(requestId);
    await prefs.setStringList(_respondedKey, _myRespondedIds.toList());
    setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Fetch requests
      final data = await Supabase.instance.client
          .from('buyer_requests')
          .select()
          .eq('is_open', true)
          .gte('needed_by', today)
          .order('needed_by', ascending: true);

      final requests = List<Map<String, dynamic>>.from(data);

      // Fetch response counts separately (avoids needing FK constraint)
      if (requests.isNotEmpty) {
        final ids = requests.map((r) => r['id'] as String).toList();
        final responses = await Supabase.instance.client
            .from('buyer_responses')
            .select('request_id')
            .inFilter('request_id', ids);

        // Count per request_id
        final counts = <String, int>{};
        for (final row in responses) {
          final rid = row['request_id'] as String;
          counts[rid] = (counts[rid] ?? 0) + 1;
        }

        // Attach counts into each request map
        for (final r in requests) {
          r['_response_count'] = counts[r['id'] as String] ?? 0;
        }
      }

      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_cropFilter == 'All') return _requests;
    return _requests.where((r) => r['crop_name'] == _cropFilter).toList();
  }

  List<String> get _availableCrops {
    final crops =
        _requests
            .map((r) => r['crop_name'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...crops];
  }

  int _responseCount(Map<String, dynamic> r) {
    return (r['_response_count'] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: const Text(
          'Buyer Board',
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'buyer_fab',
        backgroundColor: const Color(0xFF1C3A28),
        icon: const Icon(Icons.add_business, color: Color(0xFFE8C96A)),
        label: const Text(
          'Post Request',
          style: TextStyle(color: Color(0xFFE8C96A)),
        ),
        onPressed: _showPostSheet,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : Column(
              children: [
                _buildHeader(),
                if (_availableCrops.length > 1) _buildCropFilter(),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF1C3A28),
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _buildCard(_filtered[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────

  Widget _buildHeader() {
    final urgent = _requests.where((r) {
      final dt = DateTime.tryParse(r['needed_by']?.toString() ?? '');
      if (dt == null) return false;
      return dt.difference(DateTime.now()).inDays <= 2;
    }).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_requests.length} open request${_requests.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1C3A28),
                  ),
                ),
                const Text(
                  'Restaurants and buyers looking for vegetables',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (urgent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 13,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$urgent urgent',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── CROP FILTER ──────────────────────────────────────────

  Widget _buildCropFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _availableCrops.map((crop) {
            final sel = _cropFilter == crop;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _cropFilter = crop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1C3A28) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF1C3A28)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    crop,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── EMPTY STATE ──────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            _cropFilter == 'All'
                ? 'No open buyer requests yet.'
                : 'No requests for $_cropFilter right now.',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Restaurants and canteens can post\nwhat vegetables they need here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── REQUEST CARD ─────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> r) {
    final id = r['id'] as String? ?? '';
    final buyerName = r['buyer_name'] as String? ?? '';
    final buyerType = r['buyer_type'] as String? ?? 'Restaurant';
    final crop = r['crop_name'] as String? ?? '';
    final kg = (r['quantity_kg'] as num?)?.toDouble() ?? 0;
    final neededBy = DateTime.tryParse(r['needed_by']?.toString() ?? '');
    final priceOffer = (r['price_offer'] as num?)?.toDouble();
    final location = r['location'] as String? ?? '';
    final notes = r['notes'] as String? ?? '';
    final responseCount = _responseCount(r);

    final daysLeft = neededBy
        ?.difference(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;
    final isUrgent = daysLeft != null && daysLeft <= 2;
    final typeColor = _typeColor(buyerType);

    // Owner check: strict UUID match for new posts (poster_device_id set).
    // For old posts where poster_device_id is empty, fall back to local SharedPreferences
    // tracking (_myPostIds) — safe because only this device has those IDs saved.
    final postDeviceId = r['poster_device_id'] as String? ?? '';
    final isMyPost = (_deviceId.isNotEmpty && postDeviceId == _deviceId) ||
        (_myPostIds.contains(id) && postDeviceId.isEmpty);
    final iResponded = !isMyPost && _myRespondedIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP ROW ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_typeIcon(buyerType), color: typeColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1C3A28),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              buyerType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '· $location',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Days left badge
                if (daysLeft != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUrgent
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          daysLeft == 0
                              ? 'TODAY'
                              : daysLeft == 1
                              ? 'TOMORROW'
                              : '${daysLeft}d left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUrgent
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                        if (neededBy != null)
                          Text(
                            DateFormat('MMM d').format(neededBy),
                            style: TextStyle(
                              fontSize: 9,
                              color: isUrgent
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── CROP + QTY + PRICE + RESPONSE COUNT ──────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _badge(crop, const Color(0xFF1C3A28), Colors.white),
                _badge(
                  '${kg.toStringAsFixed(0)} kg',
                  Colors.grey.shade100,
                  const Color(0xFF1C3A28),
                  border: Colors.grey.shade300,
                ),
                if (priceOffer != null)
                  _badge(
                    '₱${priceOffer.toStringAsFixed(0)}/kg offered',
                    const Color(0xFFF0FDF4),
                    const Color(0xFF16A34A),
                    border: const Color(0xFF16A34A),
                  ),
                if (responseCount > 0)
                  _badge(
                    '$responseCount farmer${responseCount == 1 ? '' : 's'} interested',
                    const Color(0xFFFFF7ED),
                    const Color(0xFFEA580C),
                    border: const Color(0xFFEA580C),
                    icon: Icons.people_outline,
                  ),
              ],
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── ACTION BUTTONS ────────────────────────────────
            if (isMyPost)
              _ownerActions(id, buyerName, responseCount)
            else if (_isAdmin)
              _adminActions(id, buyerName, responseCount)
            else if (iResponded)
              _respondedActions()
            else
              _farmerActions(id, crop, kg, buyerName),
          ],
        ),
      ),
    );
  }

  // ── BADGE HELPER ─────────────────────────────────────────

  Widget _badge(
    String text,
    Color bg,
    Color fg, {
    Color? border,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ── OWNER ACTIONS (buyer who posted) ─────────────────────

  Widget _ownerActions(String id, String buyerName, int responseCount) {
    return Row(
      children: [
        // My Post label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF16A34A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_outlined, size: 14, color: Color(0xFF16A34A)),
              SizedBox(width: 5),
              Text(
                'My Post',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // View Responses button (expanded)
        Expanded(
          child: GestureDetector(
            onTap: () => _showResponsesSheet(id, buyerName, responseCount),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: responseCount > 0
                    ? const Color(0xFFFFF7ED)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: responseCount > 0
                      ? const Color(0xFFEA580C)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    responseCount > 0 ? Icons.people : Icons.people_outline,
                    color: responseCount > 0
                        ? const Color(0xFFEA580C)
                        : Colors.grey,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    responseCount > 0
                        ? '$responseCount Interested'
                        : 'No responses yet',
                    style: TextStyle(
                      color: responseCount > 0
                          ? const Color(0xFFEA580C)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Delete
        GestureDetector(
          onTap: () => _markFilled(id, buyerName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC2626)),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Color(0xFFDC2626),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  // ── ADMIN ACTIONS (delete any post) ──────────────────────

  Widget _adminActions(String id, String buyerName, int responseCount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD97706)),
          ),
          child: const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFFD97706)),
              SizedBox(width: 5),
              Text(
                'Admin',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _showResponsesSheet(id, buyerName, responseCount),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: responseCount > 0 ? const Color(0xFFFFF7ED) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: responseCount > 0 ? const Color(0xFFEA580C) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    responseCount > 0 ? Icons.people : Icons.people_outline,
                    color: responseCount > 0 ? const Color(0xFFEA580C) : Colors.grey,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    responseCount > 0 ? '$responseCount Interested' : 'No responses yet',
                    style: TextStyle(
                      color: responseCount > 0 ? const Color(0xFFEA580C) : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _adminDelete(id, buyerName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC2626)),
            ),
            child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _adminDelete(String id, String buyerName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Post?'),
        content: Text('Remove "$buyerName\'s" request from the board as admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client
          .from('buyer_requests')
          .update({'is_open': false})
          .eq('id', id);
      _load();
    }
  }

  // ── ALREADY RESPONDED ────────────────────────────────────

  Widget _respondedActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF16A34A)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 15),
          SizedBox(width: 6),
          Text(
            'You already sent your interest',
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── FARMER ACTIONS ───────────────────────────────────────

  Widget _farmerActions(String id, String crop, double kg, String buyerName) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () => _showSupplySheet(id, crop, kg, buyerName),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C3A28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.agriculture, color: Color(0xFFE8C96A), size: 18),
              SizedBox(width: 8),
              Text(
                'I Can Supply This',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── I CAN SUPPLY SHEET ───────────────────────────────────

  void _showSupplySheet(
    String requestId,
    String crop,
    double kgNeeded,
    String buyerName,
  ) {
    final nameCtrl = TextEditingController();
    final barangayCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: kgNeeded.toStringAsFixed(0));
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'I Can Supply This',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C3A28),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  '$buyerName needs $crop — enter your details and they will call you back.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                _sheetLabel('Your Name *'),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('e.g. Juan dela Cruz'),
                ),
                const SizedBox(height: 10),

                _sheetLabel('Barangay *'),
                TextField(
                  controller: barangayCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('e.g. Atok, Benguet'),
                ),
                const SizedBox(height: 10),

                _sheetLabel('Your Phone Number *'),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('09XXXXXXXXX'),
                ),
                const SizedBox(height: 10),

                _sheetLabel('How many kg can you supply?'),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec('kg'),
                ),
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your phone number will be shared with the buyer so they can contact you directly.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                      saving ? 'Sending…' : 'Send My Interest',
                      style: const TextStyle(fontSize: 15),
                    ),
                    onPressed:
                        saving ||
                            nameCtrl.text.trim().isEmpty ||
                            barangayCtrl.text.trim().isEmpty ||
                            phoneCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              await Supabase.instance.client
                                  .from('buyer_responses')
                                  .insert({
                                    'request_id': requestId,
                                    'farmer_name': nameCtrl.text.trim(),
                                    'barangay': barangayCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'qty_available': double.tryParse(
                                      qtyCtrl.text.trim(),
                                    ),
                                  });
                              await _saveMyResponse(requestId);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showSentConfirmation(buyerName);
                              }
                              _load();
                            } catch (_) {
                              setSheet(() => saving = false);
                            }
                          },
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

  void _showSentConfirmation(String buyerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Color(0xFF16A34A),
          size: 48,
        ),
        title: const Text('Interest Sent!'),
        content: Text(
          '$buyerName will see your details and call you back. Keep your phone ready!',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C3A28),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── VIEW RESPONSES SHEET (owner only) ────────────────────

  void _showResponsesSheet(String requestId, String buyerName, int count) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => _ResponsesView(
          requestId: requestId,
          buyerName: buyerName,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  // ── MARK AS FILLED / DELETE ───────────────────────────────

  Future<void> _markFilled(String id, String buyerName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Post?'),
        content: Text(
          'This will remove your request from the board. Farmers who already responded will no longer see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Strict: only the device that created the post can close it.
      await Supabase.instance.client
          .from('buyer_requests')
          .update({'is_open': false})
          .eq('id', id)
          .eq('poster_device_id', _deviceId);
      _load();
    }
  }

  // ── POST REQUEST SHEET ───────────────────────────────────

  void _showPostSheet() {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final kgCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String buyerType = kBuyerTypes[0];
    String crop = AppConfig.instance.crops.first;
    DateTime neededBy = DateTime.now().add(const Duration(days: 3));
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Post a Buyer Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C3A28),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Text(
                  'Farmers will see this and send you their interest. You call them back.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Buyer type chips
                _sheetLabel('Establishment Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kBuyerTypes.map((t) {
                    final sel = buyerType == t;
                    final color = _typeColor(t);
                    return GestureDetector(
                      onTap: () => setSheet(() => buyerType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? color.withOpacity(0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? color : Colors.grey.shade300,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _typeIcon(t),
                              size: 13,
                              color: sel ? color : Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: sel ? color : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                _sheetLabel('Establishment Name *'),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('e.g. Baguio Country Club'),
                ),
                const SizedBox(height: 10),

                _sheetLabel('Location / Address'),
                TextField(
                  controller: locationCtrl,
                  decoration: _dec('e.g. Session Road, Baguio City'),
                ),
                const SizedBox(height: 10),

                _sheetLabel('Your Contact Number *'),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('09XXXXXXXXX'),
                ),
                const SizedBox(height: 14),

                _sheetLabel('Vegetable Needed *'),
                DropdownButtonFormField<String>(
                  initialValue: crop,
                  decoration: _dec('Select crop'),
                  items: AppConfig.instance.crops
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setSheet(() => crop = v!),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetLabel('Quantity (kg) *'),
                          TextField(
                            controller: kgCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec('e.g. 50'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetLabel('Price Offer (₱/kg, optional)'),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec('e.g. 45'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _sheetLabel('Needed By *'),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: neededBy,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setSheet(() => neededBy = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFF2D5A3D),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy').format(neededBy),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                _sheetLabel('Additional Notes (optional)'),
                TextField(
                  controller: notesCtrl,
                  decoration: _dec(
                    'e.g. Must be fresh, deliver to back entrance',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.post_add, size: 18),
                    label: Text(
                      saving ? 'Posting…' : 'Post Request',
                      style: const TextStyle(fontSize: 15),
                    ),
                    onPressed:
                        saving ||
                            nameCtrl.text.trim().isEmpty ||
                            phoneCtrl.text.trim().isEmpty ||
                            kgCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              final payload = {
                                'buyer_name': nameCtrl.text.trim(),
                                'buyer_type': buyerType,
                                'location': locationCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'crop_name': crop,
                                'quantity_kg':
                                    double.tryParse(kgCtrl.text.trim()) ?? 0,
                                'needed_by': neededBy
                                    .toIso8601String()
                                    .substring(0, 10),
                                'price_offer': priceCtrl.text.trim().isEmpty
                                    ? null
                                    : double.tryParse(priceCtrl.text.trim()),
                                'notes': notesCtrl.text.trim(),
                              };
                              // Try with device ID (requires SQL migration).
                              // Falls back without it if column doesn't exist yet.
                              Map<String, dynamic> res;
                              try {
                                res = await Supabase.instance.client
                                    .from('buyer_requests')
                                    .insert({
                                      ...payload,
                                      'poster_device_id': _deviceId,
                                    })
                                    .select('id')
                                    .single();
                              } catch (_) {
                                res = await Supabase.instance.client
                                    .from('buyer_requests')
                                    .insert(payload)
                                    .select('id')
                                    .single();
                              }
                              await _saveMyPost(res['id'] as String);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            } catch (e) {
                              setSheet(() => saving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to post: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
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

  // ── HELPERS ──────────────────────────────────────────────

  Widget _sheetLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Color(0xFF1C3A28),
      ),
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    border: const OutlineInputBorder(),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return const Color(0xFFEA580C);
      case 'canteen':
        return const Color(0xFF0891B2);
      case 'school / university':
        return const Color(0xFF7C3AED);
      case 'hospital':
        return const Color(0xFFDC2626);
      case 'supermarket':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'canteen':
        return Icons.lunch_dining;
      case 'school / university':
        return Icons.school_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'supermarket':
        return Icons.storefront_outlined;
      default:
        return Icons.person_outline;
    }
  }
}

// ── RESPONSES VIEW (separate widget for clean sheet) ─────────────────────────

class _ResponsesView extends StatefulWidget {
  final String requestId;
  final String buyerName;
  final ScrollController scrollController;

  const _ResponsesView({
    required this.requestId,
    required this.buyerName,
    required this.scrollController,
  });

  @override
  State<_ResponsesView> createState() => _ResponsesViewState();
}

class _ResponsesViewState extends State<_ResponsesView> {
  List<Map<String, dynamic>> _responses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await Supabase.instance.client
        .from('buyer_responses')
        .select()
        .eq('request_id', widget.requestId)
        .order('created_at', ascending: true);
    setState(() {
      _responses = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.people, color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Farmers Interested',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1C3A28),
                      ),
                    ),
                    Text(
                      '${widget.buyerName} — tap a farmer to call them',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
                )
              : _responses.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No farmers have responded yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Share this post so more farmers can see it.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _responses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildResponseCard(_responses[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildResponseCard(Map<String, dynamic> r) {
    final name = r['farmer_name'] as String? ?? '';
    final barangay = r['barangay'] as String? ?? '';
    final phone = r['phone'] as String? ?? '';
    final qty = (r['qty_available'] as num?)?.toDouble();
    final at = DateTime.tryParse(r['created_at']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C3A28).withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.person, color: Color(0xFF1C3A28), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1C3A28),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      barangay,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (qty != null) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${qty.toStringAsFixed(0)} kg available',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C3A28),
                        ),
                      ),
                    ],
                  ],
                ),
                if (at != null)
                  Text(
                    'Responded ${DateFormat('MMM d, h:mm a').format(at)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Call button
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.call, color: Colors.white, size: 18),
                  SizedBox(height: 2),
                  Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
