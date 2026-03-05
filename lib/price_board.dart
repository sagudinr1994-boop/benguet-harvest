import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ── CONSTANTS ────────────────────────────────────────────────
const List<String> kMarkets = [
  'BAPTC La Trinidad',
  'Baguio City Market',
  'Balintawak',
  'Kamuning',
  'Divisoria',
];

// Short labels shown on the tabs (full names don't fit)
const List<String> kMarketLabels = [
  'BAPTC',
  'Baguio',
  'Balintawak',
  'Kamuning',
  'Divisoria',
];

// ── MAIN PRICE BOARD WIDGET ──────────────────────────────────
class PriceBoard extends StatefulWidget {
  const PriceBoard({super.key});
  @override
  State<PriceBoard> createState() => _PriceBoardState();
}

class _PriceBoardState extends State<PriceBoard>
    with SingleTickerProviderStateMixin {
  // Tab controller manages which market tab is selected
  late TabController _tabController;

  // Data: today's prices and yesterday's for arrows
  Map<String, List<Map<String, dynamic>>> _todayByMarket = {};
  Map<String, List<Map<String, dynamic>>> _yesterdayByMarket = {};

  bool _isLoading = true;
  bool _isStale = false; // true when prices are >24 h old
  String _search = ''; // current search query text
  DateTime? _lastUpdated; // when the newest price was entered

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kMarkets.length, vsync: this);
    _loadAllPrices();
  }

  @override
  void dispose() {
    _tabController.dispose(); // clean up the tab controller
    super.dispose();
  }

  // ── LOAD PRICES FROM SUPABASE ────────────────────────────
  Future<void> _loadAllPrices() async {
    setState(() => _isLoading = true);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    // Fetch both today and yesterday in parallel (faster)
    final results = await Future.wait([
      Supabase.instance.client
          .from('prices')
          .select()
          .eq('date_for', today)
          .order('crop_name'),
      Supabase.instance.client
          .from('prices')
          .select()
          .eq('date_for', yesterday)
          .order('crop_name'),
    ]);

    final todayRows = List<Map<String, dynamic>>.from(results[0]);
    final yesterdayRows = List<Map<String, dynamic>>.from(results[1]);

    // Group rows by market name
    final todayMap = <String, List<Map<String, dynamic>>>{};
    final yesterdayMap = <String, List<Map<String, dynamic>>>{};

    for (final row in todayRows) {
      final m = row['market_name'] as String;
      todayMap.putIfAbsent(m, () => []).add(row);
    }
    for (final row in yesterdayRows) {
      final m = row['market_name'] as String;
      yesterdayMap.putIfAbsent(m, () => []).add(row);
    }

    // Find the most recent update time to check staleness
    DateTime? newest;
    for (final row in todayRows) {
      final ts = DateTime.tryParse(row['date_updated']?.toString() ?? '');
      if (ts != null && (newest == null || ts.isAfter(newest))) newest = ts;
    }

    setState(() {
      _todayByMarket = todayMap;
      _yesterdayByMarket = yesterdayMap;
      _lastUpdated = newest;
      // Stale if newest price is more than 24 hours ago
      _isStale =
          newest != null && DateTime.now().difference(newest).inHours > 24;
      _isLoading = false;
    });
  }

  // ── BUILD UI ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '🌿 Benguet Harvest',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
        // Refresh button top-right
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: _loadAllPrices,
            tooltip: 'Refresh prices',
          ),
        ],
        // Market tabs
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // lets tabs scroll if too wide
          labelColor: const Color(0xFFE8C96A),
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFE8C96A),
          tabs: kMarketLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : Column(
              children: [
                if (_isStale) _buildStaleBanner(),
                _buildSearchBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: kMarkets.map(_buildMarketTab).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  // ── STALE BANNER ─────────────────────────────────────────
  Widget _buildStaleBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3CD),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFF856404), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Prices may be outdated — last updated: '
              '${_lastUpdated != null ? DateFormat("MMM d, h:mm a").format(_lastUpdated!) : "unknown"}',
              style: const TextStyle(color: Color(0xFF856404), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── SEARCH BAR ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search crops...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF2D5A3D)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
      ),
    );
  }

  // ── ONE MARKET TAB ───────────────────────────────────────
  Widget _buildMarketTab(String market) {
    final rows = (_todayByMarket[market] ?? []).where((r) {
      // Filter by search text
      return _search.isEmpty ||
          (r['crop_name'] as String).toLowerCase().contains(_search);
    }).toList();

    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No prices available for this market today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1C3A28),
      onRefresh: _loadAllPrices, // pull-to-refresh gesture
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, i) => _buildPriceCard(rows[i], market),
      ),
    );
  }

  // ── PRICE CARD ───────────────────────────────────────────
  Widget _buildPriceCard(Map<String, dynamic> row, String market) {
    final crop = row['crop_name'] as String;
    final price = (row['price_per_kilo'] as num).toDouble();
    final updated = DateTime.tryParse(row['date_updated']?.toString() ?? '');

    // Find yesterday's price for this same crop+market
    final yesterday = (_yesterdayByMarket[market] ?? []).firstWhere(
      (r) => r['crop_name'] == crop,
      orElse: () => {},
    );
    final yPrice = yesterday.isEmpty
        ? null
        : (yesterday['price_per_kilo'] as num?)?.toDouble();

    // Determine arrow direction and colour
    IconData? arrowIcon;
    Color arrowColor = Colors.grey;
    String changeText = '';

    if (yPrice != null && yPrice != price) {
      if (price > yPrice) {
        arrowIcon = Icons.arrow_upward;
        arrowColor = const Color(0xFFDC2626); // red  = price went UP
        changeText = '+${(price - yPrice).toStringAsFixed(0)}';
      } else {
        arrowIcon = Icons.arrow_downward;
        arrowColor = const Color(0xFF16A34A); // green = price went DOWN
        changeText = '-${(yPrice - price).toStringAsFixed(0)}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // LEFT: crop name + timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crop,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1C3A28),
                    ),
                  ),
                  if (updated != null)
                    Text(
                      'Updated: ${DateFormat("MMM d, h:mm a").format(updated)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
            // RIGHT: price + arrow + change amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${price.toStringAsFixed(0)}/kg',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5A3D),
                  ),
                ),
                if (arrowIcon != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(arrowIcon, color: arrowColor, size: 14),
                      Text(
                        changeText,
                        style: TextStyle(
                          color: arrowColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
