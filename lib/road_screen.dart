import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const List<String> kRoads = [
  'Halsema Highway',
  'Naguilian Road',
  'Kennon Road',
  'Marcos Highway',
  'Asin Road',
];

const List<String> kConditions = ['clear', 'slippery', 'blocked'];
const List<String> kSeverities = ['minor', 'moderate', 'severe'];

const List<String> kPassableFor = [
  'All vehicles',
  'Small vehicles only',
  'Motorcycles only',
];

class RoadScreen extends StatefulWidget {
  const RoadScreen({super.key});
  @override
  State<RoadScreen> createState() => _RoadScreenState();
}

class _RoadScreenState extends State<RoadScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _filter = 'all'; // 'all' | 'clear' | 'slippery' | 'blocked'
  final Map<dynamic, String> _myVotes = {};

  // ── DATA HELPERS ─────────────────────────────────────────

  Map<String, List<Map<String, dynamic>>> get _byRoad {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in _reports) {
      final road = r['highway_name'] as String? ?? '';
      map.putIfAbsent(road, () => []).add(r);
    }
    return map;
  }

  Map<String, dynamic>? _latestFor(String road) {
    final list = _byRoad[road];
    if (list == null || list.isEmpty) return null;
    return list.first; // already sorted descending
  }

  bool _isStale(Map<String, dynamic>? r) {
    if (r == null) return false;
    final ts = DateTime.tryParse(r['reported_at']?.toString() ?? '');
    if (ts == null) return false;
    return DateTime.now().difference(ts).inHours >= 6;
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(ts);
  }

  Map<String, dynamic> _conditionConfig(String c) {
    switch (c.toLowerCase()) {
      case 'blocked':
        return {'color': const Color(0xFFDC2626), 'label': '🔴 BLOCKED'};
      case 'slippery':
        return {'color': const Color(0xFFD97706), 'label': '🟡 SLIPPERY'};
      case 'clear':
        return {'color': const Color(0xFF16A34A), 'label': '🟢 CLEAR'};
      default:
        return {'color': Colors.grey, 'label': '— No reports'};
    }
  }

  Map<String, dynamic> _severityConfig(String s) {
    switch (s.toLowerCase()) {
      case 'severe':
        return {'color': const Color(0xFFDC2626), 'label': '⚠️ Severe'};
      case 'moderate':
        return {'color': const Color(0xFFD97706), 'label': '〽️ Moderate'};
      default:
        return {'color': const Color(0xFF6B7280), 'label': '🔹 Minor'};
    }
  }

  String _voteColumn(String vote) {
    switch (vote) {
      case 'ongoing': return 'votes_ongoing';
      case 'better':  return 'votes_better';
      case 'cleared': return 'votes_cleared';
      default:        return 'votes_ongoing';
    }
  }

  // ── NETWORK ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final list = await Connectivity().checkConnectivity();
    final online = list.any((r) => r != ConnectivityResult.none);

    if (!online) {
      setState(() { _isOffline = true; _isLoading = false; });
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('road_reports')
          .select()
          .order('reported_at', ascending: false)
          .limit(100);
      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
        _isOffline = false;
        _isLoading = false;
      });
    } catch (_) {
      setState(() { _isOffline = true; _isLoading = false; });
    }
  }

  Future<void> _castVote(Map<String, dynamic> report, String vote,
      {String passableFor = ''}) async {
    final id = report['id'];
    final prev = _myVotes[id];
    final updates = <String, dynamic>{};

    if (prev != null && prev != vote) {
      final col = _voteColumn(prev);
      updates[col] = ((report[col] as num?)?.toInt() ?? 0 - 1).clamp(0, 999);
    }
    if (prev != vote) {
      final col = _voteColumn(vote);
      updates[col] = ((report[col] as num?)?.toInt() ?? 0) + 1;
    }
    if (vote == 'cleared' && passableFor.isNotEmpty) {
      updates['passable_for'] = passableFor;
    } else if (vote != 'cleared') {
      updates['passable_for'] = '';
    }

    if (updates.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('road_reports').update(updates).eq('id', id);
      setState(() => _myVotes[id] = vote);
      _loadReports();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save vote. Check your connection.'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visibleRoads = kRoads.where((road) {
      if (_filter == 'all') return true;
      final latest = _latestFor(road);
      if (latest == null) return false;
      return (latest['condition'] as String? ?? '').toLowerCase() == _filter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '🛣️ Road Conditions',
          style: TextStyle(color: Color(0xFFE8B84B), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: _loadReports,
          ),
        ],
      ),
      floatingActionButton: _isOffline
          ? null
          : FloatingActionButton.extended(
              heroTag: 'road_fab',
              backgroundColor: const Color(0xFF1C3A28),
              icon: const Icon(Icons.add_road, color: Color(0xFFE8C96A)),
              label: const Text('Report', style: TextStyle(color: Color(0xFFE8C96A))),
              onPressed: () => _showReportDialog(context),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C3A28)))
          : Column(children: [
              if (_isOffline) _buildOfflineBanner(),
              _buildFilterRow(),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF1C3A28),
                  onRefresh: _loadReports,
                  child: visibleRoads.isEmpty
                      ? Center(
                          child: Text(
                            _filter == 'all'
                                ? 'No reports yet. Be the first to report!'
                                : 'No $_filter roads reported.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          children: visibleRoads
                              .map((r) => _buildRoadCard(r))
                              .toList(),
                        ),
                ),
              ),
            ]),
    );
  }

  // ── OFFLINE BANNER ────────────────────────────────────────

  Widget _buildOfflineBanner() => Container(
        width: double.infinity,
        color: const Color(0xFFDBEAFE),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: const Row(children: [
          Icon(Icons.wifi_off, color: Color(0xFF1D4ED8), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('No internet — road data unavailable offline',
                style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12)),
          ),
        ]),
      );

  // ── FILTER CHIPS ──────────────────────────────────────────

  Widget _buildFilterRow() {
    final chips = [
      ('all',      'All Roads',     Colors.grey.shade700, Colors.grey.shade100),
      ('blocked',  '🔴 Blocked',    const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      ('slippery', '🟡 Slippery',   const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      ('clear',    '🟢 Clear',      const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: chips.map((chip) {
          final (key, label, textColor, bg) = chip;
          final sel = _filter == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? bg : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? textColor : Colors.grey.shade300,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? textColor : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── ROAD CARD ─────────────────────────────────────────────

  Widget _buildRoadCard(String road) {
    final latest = _latestFor(road);
    final allReports = _byRoad[road] ?? [];
    final stale = _isStale(latest);
    final condition = (latest?['condition'] as String? ?? 'none').toLowerCase();
    final cfg = _conditionConfig(condition);
    final statusColor = cfg['color'] as Color;
    final notes = latest?['notes'] as String? ?? '';
    final passableFor = latest?['passable_for'] as String? ?? '';
    final ts = latest != null
        ? DateTime.tryParse(latest['reported_at']?.toString() ?? '')
        : null;

    return GestureDetector(
      onTap: latest != null
          ? () => _showRoadDetailSheet(road, allReports)
          : () => _showReportDialog(context, preselectedRoad: road),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left colour bar
                Container(
                  width: 6,
                  color: latest == null
                      ? Colors.grey.shade200
                      : stale
                          ? statusColor.withOpacity(0.3)
                          : statusColor,
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Road name + stale badge + time
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                road,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1C3A28),
                                ),
                              ),
                            ),
                            if (latest == null)
                              _quickReportBtn(road)
                            else ...[
                              if (stale)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                        color: Colors.orange.shade300),
                                  ),
                                  child: Text(
                                    'STALE',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700),
                                  ),
                                ),
                              if (ts != null)
                                Text(
                                  _timeAgo(ts),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 8),

                        if (latest == null)
                          const Text(
                            'No reports yet — tap to add one',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          )
                        else ...[
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(stale ? 0.07 : 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: statusColor
                                      .withOpacity(stale ? 0.25 : 0.45)),
                            ),
                            child: Text(
                              cfg['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor
                                    .withOpacity(stale ? 0.55 : 1.0),
                              ),
                            ),
                          ),

                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: stale
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                              ),
                            ),
                          ],

                          if (passableFor.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.directions_car,
                                  size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text('Passable: $passableFor',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ),
                            ]),
                          ],

                          if (allReports.length > 1) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${allReports.length} reports — tap to see all',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0891B2),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                if (latest != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right,
                        color: Colors.grey, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickReportBtn(String road) => GestureDetector(
        onTap: () => _showReportDialog(context, preselectedRoad: road),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C3A28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Report',
            style: TextStyle(
                color: Color(0xFFE8C96A),
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
      );

  // ── ROAD DETAIL SHEET ─────────────────────────────────────

  void _showRoadDetailSheet(
      String road, List<Map<String, dynamic>> reports) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final latest = reports.isNotEmpty ? reports.first : null;
          if (latest == null) return const SizedBox();

          final condition =
              (latest['condition'] as String? ?? '').toLowerCase();
          final cfg = _conditionConfig(condition);
          final statusColor = cfg['color'] as Color;
          final notes = latest['notes'] as String? ?? '';
          final passableFor = latest['passable_for'] as String? ?? '';
          final id = latest['id'];
          final myVote = _myVotes[id];
          final vOngoing = (latest['votes_ongoing'] as num?)?.toInt() ?? 0;
          final vBetter = (latest['votes_better'] as num?)?.toInt() ?? 0;
          final vCleared = (latest['votes_cleared'] as num?)?.toInt() ?? 0;
          final stale = _isStale(latest);
          final ts = DateTime.tryParse(
              latest['reported_at']?.toString() ?? '');

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (ctx, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Road name
                Text(road,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C3A28))),
                const SizedBox(height: 8),

                // Status + stale badge
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(cfg['label'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    if (stale && ts != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'May be outdated (${_timeAgo(ts)})',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700),
                        ),
                      ),
                  ],
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(notes,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87)),
                ],
                if (passableFor.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.directions_car,
                        size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Passable for: $passableFor',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),

                // Votes
                const Text('Is this still accurate?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1C3A28))),
                const SizedBox(height: 10),
                Row(children: [
                  _voteBtnSheet(ctx, setSheet, latest, 'ongoing',
                      '🚧 Ongoing', vOngoing, myVote,
                      const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  _voteBtnSheet(ctx, setSheet, latest, 'better',
                      '📈 Getting Better', vBetter, myVote,
                      const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _voteBtnSheet(ctx, setSheet, latest, 'cleared',
                      '✅ Cleared', vCleared, myVote,
                      const Color(0xFF16A34A), onTap: () {
                    Navigator.pop(ctx);
                    _showPassableDialog(latest);
                  }),
                ]),

                // Other reports
                if (reports.length > 1) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  Text('Other reports (${reports.length - 1})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1C3A28))),
                  const SizedBox(height: 8),
                  ...reports.skip(1).take(5).map((r) {
                    final c = (r['condition'] as String? ?? '').toLowerCase();
                    final rcfg = _conditionConfig(c);
                    final rts = DateTime.tryParse(
                        r['reported_at']?.toString() ?? '');
                    final n = r['notes'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: rcfg['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${rcfg['label']}${n.isNotEmpty ? '  —  $n' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        if (rts != null)
                          Text(_timeAgo(rts),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ]),
                    );
                  }),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1C3A28)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.add_road,
                        color: Color(0xFF1C3A28), size: 18),
                    label: const Text('Add New Report',
                        style: TextStyle(color: Color(0xFF1C3A28))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showReportDialog(context, preselectedRoad: road);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _voteBtnSheet(
    BuildContext ctx,
    StateSetter setSheet,
    Map<String, dynamic> report,
    String vote,
    String label,
    int count,
    String? myVote,
    Color activeColor, {
    VoidCallback? onTap,
  }) {
    final sel = myVote == vote;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (onTap != null) {
            onTap();
          } else {
            await _castVote(report, vote);
            setSheet(() {});
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? activeColor.withOpacity(0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? activeColor : Colors.grey.shade300,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? activeColor : Colors.black54)),
            const SizedBox(height: 3),
            Text('$count',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: sel ? activeColor : Colors.grey)),
          ]),
        ),
      ),
    );
  }

  // ── PASSABLE DIALOG ───────────────────────────────────────

  void _showPassableDialog(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Road Cleared',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C3A28))),
            const SizedBox(height: 6),
            const Text('Who can pass through?',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            ...kPassableFor.map((option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C3A28),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _castVote(report, 'cleared', passableFor: option);
                      },
                      child: Text(option,
                          style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                )),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── REPORT FORM ───────────────────────────────────────────

  void _showReportDialog(BuildContext context, {String? preselectedRoad}) {
    String selectedRoad = preselectedRoad ?? kRoads[0];
    String selectedCondition = 'slippery';
    String selectedSeverity = 'moderate';
    final notesCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Report Road Condition',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C3A28))),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Road — horizontal scrollable chips
                const Text('Road:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kRoads.map((road) {
                      final sel = selectedRoad == road;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setModal(() => selectedRoad = road),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1C3A28)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF1C3A28)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              road,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color:
                                    sel ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Condition
                const Text('Condition:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: kConditions.map((c) {
                    final cfg = _conditionConfig(c);
                    final sel = selectedCondition == c;
                    return Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setModal(() {
                            selectedCondition = c;
                            if (c == 'clear') selectedSeverity = 'minor';
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? cfg['color'] as Color
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? cfg['color'] as Color
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              cfg['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Severity — hidden when condition is 'clear'
                if (selectedCondition != 'clear') ...[
                  const Text('Severity:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: kSeverities.map((s) {
                      final cfg = _severityConfig(s);
                      final sel = selectedSeverity == s;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3),
                          child: GestureDetector(
                            onTap: () =>
                                setModal(() => selectedSeverity = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? (cfg['color'] as Color)
                                        .withOpacity(0.15)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: sel
                                      ? cfg['color'] as Color
                                      : Colors.grey.shade300,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                cfg['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: sel
                                      ? cfg['color'] as Color
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Notes
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Landslide near km 52',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: submitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                        submitting ? 'Submitting…' : 'Submit Report',
                        style: const TextStyle(fontSize: 15)),
                    onPressed: submitting
                        ? null
                        : () async {
                            setModal(() => submitting = true);
                            try {
                              await Supabase.instance.client
                                  .from('road_reports')
                                  .insert({
                                'highway_name': selectedRoad,
                                'condition': selectedCondition,
                                'severity': selectedSeverity,
                                'notes': notesCtrl.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadReports();
                            } catch (_) {
                              setModal(() => submitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                  content: Text(
                                      'No internet — could not submit.'),
                                  backgroundColor: Color(0xFFDC2626),
                                ));
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
}
