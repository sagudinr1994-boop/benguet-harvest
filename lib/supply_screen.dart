import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const List<String> kSupplyMarkets = [
  'BAPTC La Trinidad',
  'Baguio City Market',
  'Balintawak',
  'Kamuning',
  'Divisoria',
];

const List<String> kCrops = [
  'Repolyo',
  'Karot',
  'Patatas',
  'Kamatis',
  'Sitaw',
  'Baguio Beans',
  'Sayote',
  'Petsay',
  'Broccoli',
];

// Quantity units used by Benguet farmers
const List<String> kUnits = ['kg', 'sack', 'crate', 'load'];

class SupplyScreen extends StatefulWidget {
  const SupplyScreen({super.key});
  @override
  State<SupplyScreen> createState() => _SupplyScreenState();
}

class _SupplyScreenState extends State<SupplyScreen> {
  Map<String, List<Map<String, dynamic>>> _byDate = {};
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadSupply();
  }

  Future<void> _loadSupply() async {
    setState(() => _isLoading = true);

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity != ConnectivityResult.none;

    if (!online) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await Supabase.instance.client
          .from('supply_reports')
          .select()
          .gte('planned_for', today)
          .order('planned_for', ascending: true)
          .order('crop_name', ascending: true);

      final rows = List<Map<String, dynamic>>.from(data);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final d = row['planned_for']?.toString().substring(0, 10) ?? '';
        grouped.putIfAbsent(d, () => []).add(row);
      }
      setState(() {
        _byDate = grouped;
        _isOffline = false;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '🌾 Supply Alerts',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: _loadSupply,
          ),
        ],
      ),
      floatingActionButton: _isOffline
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1C3A28),
              icon: const Icon(Icons.agriculture, color: Color(0xFFE8C96A)),
              label: const Text(
                'Report Supply',
                style: TextStyle(color: Color(0xFFE8C96A)),
              ),
              onPressed: () => _showSupplyDialog(context),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : Column(
              children: [
                if (_isOffline) _buildOfflineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF1C3A28),
                    onRefresh: _loadSupply,
                    child: _byDate.isEmpty
                        ? const Center(
                            child: Text(
                              'No supply reports yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                            children: _byDate.entries
                                .map(_buildDateSection)
                                .toList(),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── OFFLINE BANNER ───────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFDBEAFE),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Color(0xFF1D4ED8), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet — supply data unavailable offline',
              style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── DATE SECTION HEADER ──────────────────────────────────
  Widget _buildDateSection(MapEntry<String, List<Map<String, dynamic>>> entry) {
    final dateStr = entry.key;
    final rows = entry.value;
    final dt = DateTime.tryParse(dateStr);
    final today = DateTime.now();

    String label;
    if (dt != null) {
      final diff = dt
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      if (diff == 0)
        label = 'Today';
      else if (diff == 1)
        label = 'Tomorrow';
      else
        label = DateFormat('EEEE, MMM d').format(dt);
    } else {
      label = dateStr;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1C3A28),
            ),
          ),
        ),
        ...rows.map(_buildSupplyCard),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── SUPPLY CARD ──────────────────────────────────────────
  Widget _buildSupplyCard(Map<String, dynamic> r) {
    final crop = r['crop_name'] as String? ?? '';
    final market = r['market_name'] as String? ?? '';
    final quantity = r['quantity'];
    final unit = r['unit'] as String? ?? 'kg';
    final ts = DateTime.tryParse(r['reported_at']?.toString() ?? '');

    // "X hours ago" or "just now"
    String timeLabel = '';
    if (ts != null) {
      final diff = DateTime.now().difference(ts);
      if (diff.inMinutes < 1)
        timeLabel = 'just now';
      else if (diff.inHours < 1)
        timeLabel = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24)
        timeLabel = '${diff.inHours}h ago';
      else
        timeLabel = DateFormat('MMM d').format(ts);
    }

    // Quantity string — only show if quantity > 0
    final hasQty = quantity != null && (quantity as num) > 0;
    final qtyLabel = hasQty
        ? '${(quantity as num).toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} $unit'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: crop icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF2D5A3D).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.grass,
                color: Color(0xFF2D5A3D),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // MIDDLE: crop name + market badge + quantity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crop,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1C3A28),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Market badge — bold, green, pill-shaped
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5A3D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      market,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (hasQty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Qty: $qtyLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2D5A3D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // RIGHT: time ago
            if (timeLabel.isNotEmpty)
              Text(
                timeLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // ── REPORT FORM ──────────────────────────────────────────
  void _showSupplyDialog(BuildContext context) {
    String selectedCrop = kCrops[0];
    String selectedMarket = kSupplyMarkets[0];
    String selectedUnit = 'kg';
    DateTime plannedFor = DateTime.now().add(const Duration(days: 1));
    bool submitting = false;
    final qtyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                  'Report Upcoming Supply',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A28),
                  ),
                ),
                const SizedBox(height: 16),

                // Crop dropdown
                const Text(
                  'Crop:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  value: selectedCrop,
                  items: kCrops
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedCrop = v!),
                ),
                const SizedBox(height: 12),

                // Market dropdown
                const Text(
                  'Destination Market:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  value: selectedMarket,
                  items: kSupplyMarkets
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedMarket = v!),
                ),
                const SizedBox(height: 12),

                // Quantity + Unit side by side
                const Text(
                  'Quantity:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Number input
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 50',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Unit selector buttons
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        spacing: 4,
                        children: kUnits.map((u) {
                          final selected = selectedUnit == u;
                          return ChoiceChip(
                            label: Text(
                              u,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: selected,
                            selectedColor: const Color(0xFF2D5A3D),
                            backgroundColor: Colors.grey.shade200,
                            onSelected: (_) =>
                                setModalState(() => selectedUnit = u),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Delivery date picker
                const Text(
                  'Delivery Date:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: plannedFor,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 14)),
                    );
                    if (picked != null)
                      setModalState(() => plannedFor = picked);
                  },
                  child: Text(
                    DateFormat('MMM d, yyyy').format(plannedFor),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            setModalState(() => submitting = true);
                            try {
                              final qty =
                                  double.tryParse(qtyController.text.trim()) ??
                                  0;
                              await Supabase.instance.client
                                  .from('supply_reports')
                                  .insert({
                                    'crop_name': selectedCrop,
                                    'market_name': selectedMarket,
                                    'planned_for': DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(plannedFor),
                                    'quantity': qty,
                                    'unit': selectedUnit,
                                  });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadSupply();
                            } catch (_) {
                              setModalState(() => submitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No internet — could not submit. Try again when online.',
                                    ),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text('Submit', style: TextStyle(fontSize: 16)),
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
