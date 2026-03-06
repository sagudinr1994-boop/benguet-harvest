import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db.dart';

class PriceHistoryScreen extends StatefulWidget {
  final String crop;
  final String market;
  const PriceHistoryScreen({
    super.key,
    required this.crop,
    required this.market,
  });

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryState();
}

class _PriceHistoryState extends State<PriceHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // First try Supabase for the most up-to-date 7 days
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);

    List<Map<String, dynamic>> rows = [];
    try {
      final data = await Supabase.instance.client
          .from('prices')
          .select('date_for, price_per_kilo')
          .eq('crop_name', widget.crop)
          .eq('market_name', widget.market)
          .gte('date_for', cutoffStr)
          .order('date_for', ascending: true);
      rows = List<Map<String, dynamic>>.from(data);

      // Cache these rows so chart works offline too
      final cacheRows = rows
          .map(
            (r) => {
              'crop_name': widget.crop,
              'market_name': widget.market,
              'price_per_kilo': r['price_per_kilo'],
              'date_for': r['date_for'],
              'date_updated': DateTime.now().toIso8601String(),
            },
          )
          .toList();
      await LocalDb.cachePrices(cacheRows);
    } catch (_) {
      // Offline — use device cache
      final cached = await LocalDb.loadHistory(
        crop: widget.crop,
        market: widget.market,
      );
      rows = cached
          .map((r) => {'date_for': r['date_for'], 'price_per_kilo': r['price']})
          .toList();
    }
    setState(() {
      _history = rows;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.crop,
              style: const TextStyle(
                color: Color(0xFFE8B84B),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.market,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : _history.isEmpty
          ? const Center(
              child: Text(
                'No price history available.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildChart()),
                  const SizedBox(height: 16),
                  _buildHistoryTable(),
                ],
              ),
            ),
    );
  }

  // Summary row: current price, 7-day high, 7-day low
  Widget _buildSummaryRow() {
    final prices = _history
        .map((r) => (r['price_per_kilo'] as num).toDouble())
        .toList();
    final latest = prices.last;
    final high = prices.reduce((a, b) => a > b ? a : b);
    final low = prices.reduce((a, b) => a < b ? a : b);

    return Row(
      children: [
        _statCard(
          'Current',
          '₱${latest.toStringAsFixed(0)}',
          const Color(0xFF2D5A3D),
        ),
        const SizedBox(width: 8),
        _statCard(
          '7-Day High',
          '₱${high.toStringAsFixed(0)}',
          const Color(0xFFDC2626),
        ),
        const SizedBox(width: 8),
        _statCard(
          '7-Day Low',
          '₱${low.toStringAsFixed(0)}',
          const Color(0xFF16A34A),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The fl_chart line chart
  Widget _buildChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < _history.length; i++) {
      final price = (_history[i]['price_per_kilo'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), price));
    }
    final prices = spots.map((s) => s.y).toList();
    final minY = prices.reduce((a, b) => a < b ? a : b) - 5;
    final maxY = prices.reduce((a, b) => a > b ? a : b) + 5;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF2D5A3D),
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF2D5A3D).withOpacity(0.15),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= _history.length) return const SizedBox();
                final dateStr = _history[i]['date_for']?.toString() ?? '';
                final dt = DateTime.tryParse(dateStr);
                if (dt == null) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('M/d').format(dt),
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                '₱${value.toInt()}',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '₱${s.y.toStringAsFixed(0)}/kg',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  // Table below the chart listing all 7 data points
  Widget _buildHistoryTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 8),
            ..._history.reversed.map((r) {
              final dt = DateTime.tryParse(r['date_for']?.toString() ?? '');
              final prc = (r['price_per_kilo'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(
                      dt != null ? DateFormat('EEE, MMM d').format(dt) : '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    Text(
                      '₱${prc.toStringAsFixed(0)}/kg',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D5A3D),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
