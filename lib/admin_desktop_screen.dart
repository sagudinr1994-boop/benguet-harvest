import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'encoder_screen.dart'; // kAllCrops, kMarkets (fallback if DB tables missing)

// Top-level function required for compute() isolate
String _bcryptHash(String pin) => BCrypt.hashpw(pin, BCrypt.gensalt());

// ─────────────────────────────────────────────────────────────────────────────
// BENGUET HARVEST — PC ADMIN DASHBOARD
// Shows automatically on Windows when role == 'admin'
// ─────────────────────────────────────────────────────────────────────────────

class AdminDesktopScreen extends StatefulWidget {
  const AdminDesktopScreen({super.key});
  @override
  State<AdminDesktopScreen> createState() => _AdminDesktopState();
}

class _AdminDesktopState extends State<AdminDesktopScreen> {
  int _tab = 0;
  int _pendingCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
    // Auto-refresh pending badge every 60 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadPendingCount(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    try {
      final data = await Supabase.instance.client
          .from('prices')
          .select('id')
          .eq('status', 'pending');
      if (mounted) setState(() => _pendingCount = (data as List).length);
    } catch (_) {}
  }

  static const _navItems = [
    (icon: Icons.table_chart_outlined, label: 'Price Grid'),
    (icon: Icons.pending_actions_outlined, label: 'Pending Approvals'),
    (icon: Icons.group_outlined, label: 'Farmer Registry'),
    (icon: Icons.inventory_2_outlined, label: 'Supply Reports'),
    (icon: Icons.settings_outlined, label: 'Configuration'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      body: Row(
        children: [
          _buildSidebar(),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 210,
      color: const Color(0xFF1C3A28),
      child: Column(
        children: [
          // Logo header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: const Row(
              children: [
                Icon(Icons.eco, color: Color(0xFFE8B84B), size: 28),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benguet Harvest',
                      style: TextStyle(
                          color: Color(0xFFE8B84B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    Text(
                      'Admin Dashboard',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          // Nav items
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final sel = _tab == i;
            // Settings gets a divider above it
            final isSettings = i == 4;
            return Column(
              children: [
                if (isSettings) ...[
                  const SizedBox(height: 4),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 4),
                ],
                GestureDetector(
                  onTap: () {
                    setState(() => _tab = i);
                    if (i == 1) _loadPendingCount();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color:
                              sel ? const Color(0xFFE8B84B) : Colors.white60,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white60,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Badge for pending
                        if (i == 1 && _pendingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_pendingCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          const Spacer(),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'BAPTC Admin PC\n${DateFormat('MMM d, yyyy').format(DateTime.now())}',
              style: const TextStyle(color: Colors.white30, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_tab) {
      0 => _PriceGridTab(onSaved: _loadPendingCount),
      1 => _PendingTab(onChanged: _loadPendingCount),
      2 => const _FarmersTab(),
      3 => const _SupplyTab(),
      4 => const _SettingsTab(),
      _ => const SizedBox(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — PRICE GRID  (loads crops & markets dynamically from DB)
// ─────────────────────────────────────────────────────────────────────────────

class _PriceGridTab extends StatefulWidget {
  final VoidCallback? onSaved;
  const _PriceGridTab({this.onSaved});
  @override
  State<_PriceGridTab> createState() => _PriceGridTabState();
}

class _PriceGridTabState extends State<_PriceGridTab> {
  DateTime _date = DateTime.now();
  // Dynamic lists loaded from DB; fall back to constants if tables missing
  List<String> _crops = [];
  List<String> _markets = [];
  Map<String, Map<String, TextEditingController>> _ctrls = {};
  bool _loading = true;
  bool _saving = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final row in _ctrls.values) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// Load crops & markets from Supabase; fall back to constants if tables
  /// don't exist yet. Then build controllers and load today's prices.
  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('crops')
            .select('name')
            .eq('is_active', true)
            .order('sort_order')
            .order('name'),
        Supabase.instance.client
            .from('markets')
            .select('name')
            .eq('is_active', true)
            .order('sort_order')
            .order('name'),
      ]);
      _crops =
          (results[0] as List).map((r) => r['name'] as String).toList();
      _markets =
          (results[1] as List).map((r) => r['name'] as String).toList();
    } catch (_) {
      // Tables don't exist yet — use hardcoded constants as fallback
      _crops = kAllCrops;
      _markets = kMarkets;
    }
    // Rebuild controllers for the new crop/market grid
    for (final row in _ctrls.values) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    _ctrls = {
      for (final crop in _crops)
        crop: {
          for (final market in _markets) market: TextEditingController()
        },
    };
    await _loadPrices();
  }

  Future<void> _loadPrices([DateTime? forDate]) async {
    final target = forDate ?? _date;
    // Clear without rebuilding controllers
    for (final row in _ctrls.values) {
      for (final c in row.values) {
        c.text = '';
      }
    }
    if (mounted) setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(target);
      final data = await Supabase.instance.client
          .from('prices')
          .select()
          .eq('date_for', dateStr)
          .or('status.eq.published,status.is.null');
      for (final row in data) {
        final crop = row['crop_name'] as String?;
        final market = row['market_name'] as String?;
        final price = row['price_per_kilo'];
        if (crop != null && market != null && price != null) {
          _ctrls[crop]?[market]?.text = price.toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _copyYesterday() async {
    final yesterday = _date.subtract(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Copy from Yesterday'),
        content: Text(
          'Load prices from ${DateFormat('EEEE, MMM d').format(yesterday)} '
          'into the grid?\n\nAny values already entered will be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C3A28),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _loadPrices(yesterday);
    if (mounted) {
      setState(() => _statusMsg =
          '↑ Copied from ${DateFormat('MMM d').format(yesterday)} — review values then save');
    }
  }

  Future<void> _saveAll() async {
    final rows = <Map<String, dynamic>>[];
    for (final crop in _crops) {
      for (final market in _markets) {
        final text = _ctrls[crop]?[market]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          final price = double.tryParse(text);
          if (price != null && price > 0) {
            rows.add({
              'crop_name': crop,
              'market_name': market,
              'price_per_kilo': price,
              'date_for': DateFormat('yyyy-MM-dd').format(_date),
              'date_updated': DateTime.now().toIso8601String(),
              'status': 'published',
              'source': 'BAPTC',
              'updated_by': 'Admin',
            });
          }
        }
      }
    }

    if (rows.isEmpty) {
      setState(() =>
          _statusMsg = '⚠ No prices entered — fill in at least one cell.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Prices'),
        content: Text(
          'Save ${rows.length} prices for '
          '${DateFormat('EEEE, MMM d, yyyy').format(_date)}?\n\n'
          'This will replace all existing published prices for this date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C3A28),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _statusMsg = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      await Supabase.instance.client
          .from('prices')
          .delete()
          .eq('date_for', dateStr)
          .eq('status', 'published');
      await Supabase.instance.client.from('prices').insert(rows);
      setState(() => _statusMsg =
          '✓ Saved ${rows.length} prices for ${DateFormat('MMM d, yyyy').format(_date)}');
      widget.onSaved?.call();
    } catch (e) {
      setState(() => _statusMsg = '✗ Error: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Cells'),
        content: const Text(
          'Clear all entered prices from the grid?\n\n'
          'Nothing is deleted from the database until you save.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final row in _ctrls.values) {
      for (final c in row.values) {
        c.text = '';
      }
    }
    setState(() => _statusMsg = null);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _loadPrices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!_saving && !_loading) _saveAll();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // ── TOOLBAR ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined,
                      color: Color(0xFF1C3A28), size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Price Entry Grid',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF1C3A28)),
                  ),
                  const SizedBox(width: 24),
                  // Date picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 15, color: Color(0xFF1C3A28)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(_date),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1C3A28)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _date = DateTime.now());
                      _loadPrices();
                    },
                    child: const Text('Today'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: const Text('Copy Yesterday'),
                    onPressed: _loading ? null : _copyYesterday,
                  ),
                  const SizedBox(width: 8),
                  // Reload config (picks up new crops/markets from Settings)
                  Tooltip(
                    message:
                        'Reload crops & markets from Configuration',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reload Grid'),
                      onPressed: _loading ? null : _loadConfig,
                    ),
                  ),
                  const Spacer(),
                  if (_statusMsg != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusMsg!.startsWith('✓')
                            ? const Color(0xFFF0FDF4)
                            : _statusMsg!.startsWith('⚠') ||
                                    _statusMsg!.startsWith('↑')
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _statusMsg!.startsWith('✓')
                              ? const Color(0xFF16A34A)
                              : _statusMsg!.startsWith('⚠') ||
                                      _statusMsg!.startsWith('↑')
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFDC2626),
                        ),
                      ),
                      child: Text(
                        _statusMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _statusMsg!.startsWith('✓')
                              ? const Color(0xFF16A34A)
                              : _statusMsg!.startsWith('⚠') ||
                                      _statusMsg!.startsWith('↑')
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear All'),
                    onPressed: _loading ? null : _clearAll,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_saving ? 'Saving…' : 'Save All Prices'),
                    onPressed: _saving || _loading ? null : _saveAll,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── INFO BAR ─────────────────────────────────────────
            Container(
              color: const Color(0xFFFFFBEB),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.keyboard_tab,
                      size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text(
                    'Tip: Press Tab to move between cells. Ctrl+S to save. '
                    'Add/remove crops & markets in the Configuration tab.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                  const Spacer(),
                  Text(
                    '${_crops.length} crops × ${_markets.length} markets',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),

            // ── GRID ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1C3A28)))
                  : _crops.isEmpty || _markets.isEmpty
                      ? const Center(
                          child: Text(
                            'No crops or markets configured.\nGo to Configuration tab to add them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildGrid(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    const headerStyle = TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white);
    const cropStyle = TextStyle(
        fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1C3A28));

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(
          color: Colors.grey.shade200,
          width: 1,
          borderRadius: BorderRadius.circular(8)),
      children: [
        // Header row
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFF1C3A28),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Text('Vegetable', style: headerStyle),
            ),
            ..._markets.map(
              (market) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  // Break long market names for compact header
                  market.replaceAll(' ', '\n'),
                  style: headerStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              alignment: Alignment.center,
              child: const Text('Avg ₱/kg',
                  style: headerStyle, textAlign: TextAlign.center),
            ),
          ],
        ),
        // Data rows
        ...List.generate(_crops.length, (cropIdx) {
          final crop = _crops[cropIdx];
          final isEven = cropIdx % 2 == 0;
          return TableRow(
            decoration: BoxDecoration(
                color: isEven ? Colors.white : const Color(0xFFF9FAFB)),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Text(crop, style: cropStyle),
              ),
              ..._markets.map(
                (market) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _ctrls[crop]?[market],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: '₱',
                        prefixStyle:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                        hintText: '—',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade300, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: Color(0xFF1C3A28), width: 2),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
              // Average column
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                alignment: Alignment.center,
                child: Builder(
                  builder: (_) {
                    final vals = _markets
                        .map((m) => double.tryParse(
                            _ctrls[crop]?[m]?.text.trim() ?? ''))
                        .whereType<double>()
                        .toList();
                    if (vals.isEmpty) {
                      return Text('—',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13));
                    }
                    final avg =
                        vals.reduce((a, b) => a + b) / vals.length;
                    return Text(
                      '₱${avg.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF2D5A3D)),
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — PENDING APPROVALS
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const _PendingTab({this.onChanged});
  @override
  State<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<_PendingTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _busy = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected.clear();
    });
    try {
      final data = await Supabase.instance.client
          .from('prices')
          .select()
          .eq('status', 'pending')
          .order('date_updated', ascending: false);
      setState(() => _rows = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _confirm(String title, String message,
      {bool danger = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      danger ? Colors.red : const Color(0xFF1C3A28),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _approveSelected() async {
    if (_selected.isEmpty) return;
    if (!await _confirm('Approve Selected',
        'Approve ${_selected.length} selected price submissions?')) {
      return;
    }
    setState(() => _busy = true);
    for (final id in _selected) {
      await Supabase.instance.client
          .from('prices')
          .update({'status': 'published'})
          .eq('id', id);
    }
    widget.onChanged?.call();
    _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _approveAll() async {
    if (!await _confirm('Approve All',
        'Approve all ${_rows.length} pending submissions? This cannot be undone.')) {
      return;
    }
    setState(() => _busy = true);
    for (final row in _rows) {
      await Supabase.instance.client
          .from('prices')
          .update({'status': 'published'})
          .eq('id', row['id']);
    }
    widget.onChanged?.call();
    _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _rejectSelected() async {
    if (_selected.isEmpty) return;
    if (!await _confirm(
        'Reject Selected',
        'Permanently delete ${_selected.length} selected submissions?',
        danger: true)) {
      return;
    }
    setState(() => _busy = true);
    for (final id in _selected) {
      await Supabase.instance.client.from('prices').delete().eq('id', id);
    }
    widget.onChanged?.call();
    _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              const Icon(Icons.pending_actions_outlined,
                  color: Color(0xFF1C3A28), size: 22),
              const SizedBox(width: 10),
              const Text('Pending Price Approvals',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1C3A28))),
              const SizedBox(width: 12),
              if (_rows.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${_rows.length} pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              const Spacer(),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _busy ? null : _load,
                  tooltip: 'Refresh'),
              const SizedBox(width: 8),
              if (_selected.isNotEmpty) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.close,
                      size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Reject Selected',
                      style: TextStyle(color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626))),
                  onPressed: _busy ? null : _rejectSelected,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Approve ${_selected.length} Selected'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white),
                  onPressed: _busy ? null : _approveSelected,
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Approve All'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A28),
                    foregroundColor: Colors.white),
                onPressed: (_rows.isEmpty || _busy) ? null : _approveAll,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C3A28)))
              : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No pending submissions.',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('All encoder submissions have been reviewed.',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildTable(),
                    ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1C3A28),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value:
                        _selected.length == _rows.length && _rows.isNotEmpty,
                    tristate: true,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected
                            .addAll(_rows.map((r) => r['id'] as String));
                      } else {
                        _selected.clear();
                      }
                    }),
                    checkColor: const Color(0xFF1C3A28),
                    fillColor: WidgetStateProperty.all(Colors.white),
                  ),
                ),
                ...[
                  ('Crop', 140.0),
                  ('Market', 180.0),
                  ('₱/kg', 80.0),
                  ('Date', 100.0),
                  ('Submitted By', 140.0),
                  ('Submitted At', 150.0),
                ].map(
                  (col) => SizedBox(
                    width: col.$2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      child: Text(col.$1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                ),
                const Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Text('Actions',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...List.generate(_rows.length, (i) {
            final r = _rows[i];
            final id = r['id'] as String;
            final isSel = _selected.contains(id);
            final at =
                DateTime.tryParse(r['date_updated']?.toString() ?? '');
            return Container(
              decoration: BoxDecoration(
                color: isSel
                    ? const Color(0xFFF0FDF4)
                    : i % 2 == 0
                        ? Colors.white
                        : const Color(0xFFF9FAFB),
                border:
                    Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Checkbox(
                      value: isSel,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      }),
                    ),
                  ),
                  _cell(r['crop_name'] ?? '—', 140, bold: true),
                  _cell(r['market_name'] ?? '—', 180),
                  _cell('₱${r['price_per_kilo'] ?? '—'}', 80,
                      color: const Color(0xFF16A34A), bold: true),
                  _cell(r['date_for'] ?? '—', 100),
                  _cell(r['updated_by'] ?? '—', 140),
                  _cell(
                      at != null
                          ? DateFormat('MMM d, h:mm a').format(at)
                          : '—',
                      150),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Supabase.instance.client
                                        .from('prices')
                                        .update({'status': 'published'})
                                        .eq('id', id);
                                    widget.onChanged?.call();
                                    _load();
                                  },
                            child: const Text('Approve',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(
                                  color: Color(0xFFDC2626)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Supabase.instance.client
                                        .from('prices')
                                        .delete()
                                        .eq('id', id);
                                    widget.onChanged?.call();
                                    _load();
                                  },
                            child: const Text('Reject',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool bold = false, Color? color}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? const Color(0xFF1C3A28),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — FARMER REGISTRY
// ─────────────────────────────────────────────────────────────────────────────

class _FarmersTab extends StatefulWidget {
  const _FarmersTab();
  @override
  State<_FarmersTab> createState() => _FarmersTabState();
}

class _FarmersTabState extends State<_FarmersTab> {
  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('farmers')
          .select()
          .order('name', ascending: true);
      setState(() {
        _farmers = List<Map<String, dynamic>>.from(data);
        _applyFilter();
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _farmers
          : _farmers.where((f) {
              final name = (f['name'] as String? ?? '').toLowerCase();
              final bgy = (f['barangay'] as String? ?? '').toLowerCase();
              return name.contains(q) || bgy.contains(q);
            }).toList();
    });
  }

  void _showAddDialog([Map<String, dynamic>? existing]) {
    final nameCtrl = TextEditingController(
        text: existing?['name'] as String? ?? '');
    final bgyCtrl = TextEditingController(
        text: existing?['barangay'] as String? ?? '');
    final phoneCtrl = TextEditingController(
        text: existing?['phone'] as String? ?? '');
    String role = existing?['role'] as String? ?? 'farmer';
    final existingCrops =
        List<String>.from(existing?['crops_grown'] as List? ?? []);
    final selectedCrops = Set<String>.from(existingCrops);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Add New Farmer' : 'Edit Farmer'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Full Name *'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bgyCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Barangay / Municipality *'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Phone (09XXXXXXXXX)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                          value: 'farmer', child: Text('Farmer')),
                      DropdownMenuItem(
                          value: 'encoder', child: Text('Encoder')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setDlg(() => role = v!),
                  ),
                  const SizedBox(height: 16),
                  const Text('Crops Grown',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: kAllCrops
                        .map((crop) => FilterChip(
                              label: Text(crop,
                                  style: const TextStyle(fontSize: 12)),
                              selected: selectedCrops.contains(crop),
                              onSelected: (v) => setDlg(() {
                                if (v) {
                                  selectedCrops.add(crop);
                                } else {
                                  selectedCrops.remove(crop);
                                }
                              }),
                              selectedColor: const Color(0xFF1C3A28)
                                  .withValues(alpha: 0.15),
                              checkmarkColor: const Color(0xFF1C3A28),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A28),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final data = {
                  'name': nameCtrl.text.trim(),
                  'barangay': bgyCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'role': role,
                  'crops_grown': selectedCrops.toList(),
                  'is_active': true,
                };
                try {
                  if (existing == null) {
                    await Supabase.instance.client
                        .from('farmers')
                        .insert(data);
                  } else {
                    await Supabase.instance.client
                        .from('farmers')
                        .update(data)
                        .eq('id', existing['id']);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(existing == null ? 'Add Farmer' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPinDialog(Map<String, dynamic> farmer) {
    final pinCtrl = TextEditingController();
    bool resetting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Reset PIN — ${farmer['name']}'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter a new 4–6 digit PIN for this farmer.',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(
                      labelText: 'New PIN',
                      hintText: '4–6 digits',
                      prefixIcon: Icon(Icons.lock_outline)),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A28),
                  foregroundColor: Colors.white),
              onPressed: resetting
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      if (pin.length < 4) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('PIN must be at least 4 digits')));
                        return;
                      }
                      setDlg(() => resetting = true);
                      try {
                        final hash = await compute(_bcryptHash, pin);
                        await Supabase.instance.client
                            .from('farmers')
                            .update({'pin_hash': hash})
                            .eq('id', farmer['id']);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(
                                  'PIN reset for ${farmer['name']}')));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red));
                        }
                      }
                      if (ctx.mounted) setDlg(() => resetting = false);
                    },
              child: resetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Reset PIN'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFarmer(Map<String, dynamic> farmer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Farmer'),
        content: Text(
          'Permanently delete "${farmer['name']}"?\n\n'
          'Their supply reports will remain but will show no farmer name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('farmers')
          .delete()
          .eq('id', farmer['id']);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${farmer['name']} deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              const Icon(Icons.group_outlined,
                  color: Color(0xFF1C3A28), size: 22),
              const SizedBox(width: 10),
              const Text('Farmer Registry',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1C3A28))),
              const SizedBox(width: 12),
              Text('${_farmers.length} farmers',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 24),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or barangay…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                  tooltip: 'Refresh'),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Add Farmer'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A28),
                    foregroundColor: Colors.white),
                onPressed: () => _showAddDialog(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C3A28)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1C3A28),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              ...[
                                ('Name', 180.0),
                                ('Barangay', 160.0),
                                ('Phone', 130.0),
                                ('Crops Grown', 220.0),
                                ('Role', 90.0),
                                ('Status', 80.0),
                              ].map(
                                (col) => SizedBox(
                                  width: col.$2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 12),
                                    child: Text(col.$1,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                  child: Text('Actions',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Rows
                        if (_filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No farmers found.',
                                style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...List.generate(_filtered.length, (i) {
                            final f = _filtered[i];
                            final isActive =
                                f['is_active'] as bool? ?? true;
                            final role =
                                f['role'] as String? ?? 'farmer';
                            final crops = List<String>.from(
                                f['crops_grown'] as List? ?? []);

                            return Container(
                              decoration: BoxDecoration(
                                color: i % 2 == 0
                                    ? Colors.white
                                    : const Color(0xFFF9FAFB),
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade100)),
                              ),
                              child: Row(
                                children: [
                                  _fCell(f['name'] as String? ?? '—',
                                      180, bold: true),
                                  _fCell(
                                      f['barangay'] as String? ?? '—',
                                      160),
                                  _fCell(
                                      f['phone'] as String? ?? '—', 130),
                                  // Crops
                                  SizedBox(
                                    width: 220,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      child: crops.isEmpty
                                          ? Text('—',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey.shade400))
                                          : Wrap(
                                              spacing: 4,
                                              runSpacing: 2,
                                              children: crops
                                                  .map((c) => Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                                  0xFF16A34A)
                                                              .withValues(
                                                                  alpha:
                                                                      0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      4),
                                                        ),
                                                        child: Text(c,
                                                            style: const TextStyle(
                                                                fontSize:
                                                                    10,
                                                                color: Color(
                                                                    0xFF166534))),
                                                      ))
                                                  .toList(),
                                            ),
                                    ),
                                  ),
                                  // Role badge
                                  SizedBox(
                                    width: 90,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: role == 'admin'
                                              ? const Color(0xFFFEF3C7)
                                              : role == 'encoder'
                                                  ? const Color(0xFFEEF2FF)
                                                  : const Color(0xFFF0FDF4),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          role[0].toUpperCase() +
                                              role.substring(1),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: role == 'admin'
                                                ? const Color(0xFFD97706)
                                                : role == 'encoder'
                                                    ? const Color(0xFF4338CA)
                                                    : const Color(
                                                        0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Status
                                  SizedBox(
                                    width: 80,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                      child: Text(
                                        isActive
                                            ? '● Active'
                                            : '○ Inactive',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isActive
                                              ? const Color(0xFF16A34A)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Actions
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 6),
                                      child: Wrap(
                                        children: [
                                          TextButton.icon(
                                            icon: const Icon(Icons.edit,
                                                size: 14),
                                            label: const Text('Edit',
                                                style: TextStyle(
                                                    fontSize: 12)),
                                            onPressed: () =>
                                                _showAddDialog(f),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(
                                                Icons.lock_reset,
                                                size: 14),
                                            label: const Text('PIN',
                                                style: TextStyle(
                                                    fontSize: 12)),
                                            onPressed: () =>
                                                _showResetPinDialog(f),
                                          ),
                                          TextButton.icon(
                                            icon: Icon(
                                                isActive
                                                    ? Icons.block
                                                    : Icons.check_circle,
                                                size: 14),
                                            label: Text(
                                                isActive
                                                    ? 'Deactivate'
                                                    : 'Activate',
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            onPressed: () async {
                                              await Supabase.instance.client
                                                  .from('farmers')
                                                  .update({
                                                    'is_active': !isActive
                                                  })
                                                  .eq('id', f['id']);
                                              _load();
                                            },
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 14,
                                                color: Colors.red),
                                            label: const Text('Delete',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red)),
                                            onPressed: () =>
                                                _deleteFarmer(f),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _fCell(String text, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF1C3A28),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — SUPPLY REPORTS
// ─────────────────────────────────────────────────────────────────────────────

enum _DateRange { week, month, all }

class _SupplyTab extends StatefulWidget {
  const _SupplyTab();
  @override
  State<_SupplyTab> createState() => _SupplyTabState();
}

class _SupplyTabState extends State<_SupplyTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _cropFilter = 'All';
  _DateRange _dateRange = _DateRange.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('supply_reports')
            .select()
            .order('planned_for', ascending: false)
            .limit(500),
        Supabase.instance.client.from('farmers').select('id,name'),
      ]);
      final reports = results[0] as List;
      final farmers = results[1] as List;
      final farmerMap = <String, String>{
        for (final f in farmers) f['id'] as String: f['name'] as String,
      };
      setState(() {
        _rows = reports.map((r) {
          final map = Map<String, dynamic>.from(r);
          map['_farmer_name'] =
              farmerMap[r['farmer_id'] as String? ?? ''] ?? '—';
          return map;
        }).toList();
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    var rows = _rows;
    if (_dateRange != _DateRange.all) {
      final cutoff = DateTime.now().subtract(
        _dateRange == _DateRange.week
            ? const Duration(days: 7)
            : const Duration(days: 30),
      );
      final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);
      rows = rows
          .where((r) =>
              (r['planned_for'] as String? ?? '').compareTo(cutoffStr) >= 0)
          .toList();
    }
    if (_cropFilter != 'All') {
      rows = rows.where((r) => r['crop_name'] == _cropFilter).toList();
    }
    return rows;
  }

  List<String> get _crops {
    final set = _rows
        .map((r) => r['crop_name'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...set];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF1C3A28), size: 22),
              const SizedBox(width: 10),
              const Text('Supply Reports',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1C3A28))),
              const SizedBox(width: 12),
              Text('${filtered.length} records',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 24),
              SegmentedButton<_DateRange>(
                segments: const [
                  ButtonSegment(
                      value: _DateRange.week, label: Text('7 days')),
                  ButtonSegment(
                      value: _DateRange.month, label: Text('30 days')),
                  ButtonSegment(
                      value: _DateRange.all, label: Text('All')),
                ],
                selected: {_dateRange},
                onSelectionChanged: (s) =>
                    setState(() => _dateRange = s.first),
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _cropFilter,
                items: _crops
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _cropFilter = v ?? 'All'),
                underline:
                    Container(height: 1, color: Colors.grey.shade300),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                  tooltip: 'Refresh'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C3A28)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1C3A28),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              ...[
                                ('Farmer', 160.0),
                                ('Crop', 140.0),
                                ('Market', 180.0),
                                ('Qty (kg)', 100.0),
                                ('Planned For', 120.0),
                                ('Reported At', 150.0),
                              ].map(
                                (col) => SizedBox(
                                  width: col.$2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 12),
                                    child: Text(col.$1,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No supply reports found.',
                                style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...List.generate(filtered.length, (i) {
                            final r = filtered[i];
                            final at = DateTime.tryParse(
                                r['reported_at']?.toString() ?? '');
                            return Container(
                              decoration: BoxDecoration(
                                color: i % 2 == 0
                                    ? Colors.white
                                    : const Color(0xFFF9FAFB),
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade100)),
                              ),
                              child: Row(
                                children: [
                                  _sCell(r['_farmer_name'] ?? '—', 160,
                                      bold: true),
                                  _sCell(r['crop_name'] ?? '—', 140),
                                  _sCell(r['market_name'] ?? '—', 180),
                                  _sCell(
                                    '${r['quantity'] ?? r['quantity_kg'] ?? '—'} ${r['unit'] ?? 'kg'}',
                                    100,
                                  ),
                                  _sCell(r['planned_for'] ?? '—', 120),
                                  _sCell(
                                    at != null
                                        ? DateFormat('MMM d, h:mm a')
                                            .format(at)
                                        : '—',
                                    150,
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sCell(String text, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF1C3A28),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — CONFIGURATION  (manage crops & markets stored in Supabase)
// ─────────────────────────────────────────────────────────────────────────────

const _kSetupSql = '''
-- Run this once in your Supabase SQL Editor to enable crop/market management

CREATE TABLE IF NOT EXISTS crops (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0
);

CREATE TABLE IF NOT EXISTS markets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0
);

-- Seed default crops
INSERT INTO crops (name, sort_order) VALUES
  ('Repolyo',1),('Karot',2),('Patatas',3),('Kamatis',4),
  ('Baguio Beans',5),('Sayote',6),('Sitaw',7),('Petsay',8),
  ('Lettuce',9),('Broccoli',10),('Pipino',11),('Sibuyas',12)
ON CONFLICT (name) DO NOTHING;

-- Seed default markets
INSERT INTO markets (name, sort_order) VALUES
  ('BAPTC La Trinidad',1),('Baguio City Market',2),
  ('Balintawak',3),('Kamuning',4),('Divisoria',5)
ON CONFLICT (name) DO NOTHING;

-- RLS: allow anon read+write (same pattern as other tables)
ALTER TABLE crops ENABLE ROW LEVEL SECURITY;
ALTER TABLE markets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "crops_anon" ON crops FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "markets_anon" ON markets FOR ALL TO anon USING (true) WITH CHECK (true);
''';

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _markets = [];
  bool _loading = true;
  bool _tablesExist = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('crops')
            .select()
            .order('sort_order')
            .order('name'),
        Supabase.instance.client
            .from('markets')
            .select()
            .order('sort_order')
            .order('name'),
      ]);
      setState(() {
        _crops = List<Map<String, dynamic>>.from(results[0]);
        _markets = List<Map<String, dynamic>>.from(results[1]);
        _tablesExist = true;
      });
    } catch (_) {
      setState(() => _tablesExist = false);
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Generic CRUD ────────────────────────────────────────────────────────────

  Future<void> _addItem(String table, List<Map<String, dynamic>> list) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Add ${table == 'crops' ? 'Vegetable' : 'Market'}'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText:
                  table == 'crops' ? 'Vegetable name' : 'Market name',
              hintText:
                  table == 'crops' ? 'e.g. Sibuyas Dahon' : 'e.g. Pangasinan',
            ),
            onSubmitted: (_) async {
              await _doInsert(ctx, table, ctrl.text.trim(), list.length);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C3A28),
                foregroundColor: Colors.white),
            onPressed: () =>
                _doInsert(ctx, table, ctrl.text.trim(), list.length),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _doInsert(BuildContext ctx, String table, String name,
      int sortOrder) async {
    if (name.isEmpty) return;
    try {
      await Supabase.instance.client.from(table).insert({
        'name': name,
        'is_active': true,
        'sort_order': sortOrder,
      });
      if (ctx.mounted) Navigator.pop(ctx);
      _load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _editItem(
      Map<String, dynamic> item, String table) async {
    final ctrl = TextEditingController(text: item['name'] as String);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename ${table == 'crops' ? 'Vegetable' : 'Market'}'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C3A28),
                foregroundColor: Colors.white),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              try {
                await Supabase.instance.client
                    .from(table)
                    .update({'name': name})
                    .eq('id', item['id']);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _toggleActive(Map<String, dynamic> item, String table) async {
    final current = item['is_active'] as bool? ?? true;
    await Supabase.instance.client
        .from(table)
        .update({'is_active': !current})
        .eq('id', item['id']);
    _load();
  }

  Future<void> _deleteItem(
      Map<String, dynamic> item, String table) async {
    final label = table == 'crops' ? 'vegetable' : 'market';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${item['name']}'),
        content: Text(
          'Remove "${item['name']}" from the $label list?\n\n'
          'Existing prices that used this $label will still be in the database.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client
        .from(table)
        .delete()
        .eq('id', item['id']);
    _load();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              const Icon(Icons.settings_outlined,
                  color: Color(0xFF1C3A28), size: 22),
              const SizedBox(width: 10),
              const Text('Configuration',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1C3A28))),
              const SizedBox(width: 12),
              const Text(
                'Manage the vegetables and markets used throughout the app',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                  tooltip: 'Refresh'),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C3A28)))
              : !_tablesExist
                  ? _buildSetupRequired()
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Vegetables
                          Expanded(
                              child: _buildPanel(
                            icon: Icons.grass,
                            iconColor: const Color(0xFF16A34A),
                            title: 'Vegetables',
                            subtitle: '${_crops.length} total, '
                                '${_crops.where((c) => c['is_active'] == true).length} active',
                            items: _crops,
                            table: 'crops',
                          )),
                          const SizedBox(width: 20),
                          // Right: Markets
                          Expanded(
                              child: _buildPanel(
                            icon: Icons.storefront_outlined,
                            iconColor: const Color(0xFF0891B2),
                            title: 'Markets',
                            subtitle: '${_markets.length} total, '
                                '${_markets.where((m) => m['is_active'] == true).length} active',
                            items: _markets,
                            table: 'markets',
                          )),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPanel({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required String table,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1C3A28))),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A28),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () => _addItem(table, items),
                ),
              ],
            ),
          ),
          // Item list
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No items yet. Click Add to get started.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...items.map((item) {
              final isActive = item['is_active'] as bool? ?? true;
              return Container(
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : const Color(0xFFFAFAFA),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isActive ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: isActive
                        ? const Color(0xFF16A34A)
                        : Colors.grey.shade400,
                  ),
                  title: Text(
                    item['name'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? const Color(0xFF1C3A28)
                          : Colors.grey.shade500,
                      decoration: isActive
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    isActive ? 'Active — shows in Price Grid & Encoder' : 'Hidden',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isActive ? Colors.grey.shade500 : Colors.grey.shade400),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Rename',
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _editItem(item, table),
                        ),
                      ),
                      Tooltip(
                        message: isActive ? 'Hide (deactivate)' : 'Show (activate)',
                        child: IconButton(
                          icon: Icon(
                            isActive
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                            color: isActive
                                ? Colors.orange.shade600
                                : const Color(0xFF16A34A),
                          ),
                          onPressed: () => _toggleActive(item, table),
                        ),
                      ),
                      Tooltip(
                        message: 'Delete permanently',
                        child: IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 16, color: Colors.red.shade400),
                          onPressed: () => _deleteItem(item, table),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Shown when crops/markets tables don't exist in Supabase yet
  Widget _buildSetupRequired() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Database Setup Required',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'The crops and markets tables do not exist in your Supabase project yet.\n'
                        'Copy the SQL below, open your Supabase dashboard → SQL Editor, paste and run it.\n'
                        'Then click Retry.',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C3A28),
                                foregroundColor: Colors.white),
                            onPressed: _load,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy SQL'),
                            onPressed: () {
                              Clipboard.setData(
                                  const ClipboardData(text: _kSetupSql));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('SQL copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // SQL code block
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Code header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D2D3F),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.code,
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      const Text('SQL — paste in Supabase SQL Editor',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.copy,
                            size: 14, color: Colors.white54),
                        label: const Text('Copy',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(
                              const ClipboardData(text: _kSetupSql));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('SQL copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Code content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _kSetupSql.trim(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFCDD6F4),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
