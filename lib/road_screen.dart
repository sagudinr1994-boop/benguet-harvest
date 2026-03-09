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

// Status vote options
const List<String> kVotes = ['ongoing', 'better', 'cleared'];

// Passable-for options shown when user votes 'cleared'
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

  // Track which report ID the user voted on and what they voted
  final Map<dynamic, String> _myVotes = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
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
      final data = await Supabase.instance.client
          .from('road_reports')
          .select()
          .order('reported_at', ascending: false)
          .limit(50);
      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
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

  // Cast a status vote — if user already voted, subtract from old and add to new
  Future<void> _castVote(
    Map<String, dynamic> report,
    String vote, {
    String passableFor = '',
  }) async {
    final id = report['id'];
    final prevVote = _myVotes[id]; // what they voted before (if any)

    // Build the update map
    final updates = <String, dynamic>{};

    // Remove previous vote if switching
    if (prevVote != null && prevVote != vote) {
      final prevCol = _voteColumn(prevVote);
      final prevCount = (report[prevCol] as num?)?.toInt() ?? 0;
      updates[prevCol] = (prevCount - 1).clamp(0, 999);
    }

    // Add new vote (only if not already on this option)
    if (prevVote != vote) {
      final newCol = _voteColumn(vote);
      final newCount = (report[newCol] as num?)?.toInt() ?? 0;
      updates[newCol] = newCount + 1;
    }

    // Save passable_for if cleared
    if (vote == 'cleared' && passableFor.isNotEmpty) {
      updates['passable_for'] = passableFor;
    } else if (vote != 'cleared') {
      updates['passable_for'] = '';
    }

    if (updates.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('road_reports')
          .update(updates)
          .eq('id', id);
      setState(() => _myVotes[id] = vote);
      _loadReports();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save vote. Check your connection.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String _voteColumn(String vote) {
    switch (vote) {
      case 'ongoing':
        return 'votes_ongoing';
      case 'better':
        return 'votes_better';
      case 'cleared':
        return 'votes_cleared';
      default:
        return 'votes_ongoing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '🛣️ Road Conditions',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
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
              backgroundColor: const Color(0xFF1C3A28),
              icon: const Icon(Icons.add_road, color: Color(0xFFE8C96A)),
              label: const Text(
                'Report',
                style: TextStyle(color: Color(0xFFE8C96A)),
              ),
              onPressed: () => _showReportDialog(context),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : Column(
              children: [
                if (_isOffline) _buildOfflineBanner(),
                if (!_isOffline && _reports.isNotEmpty) _buildSummaryBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF1C3A28),
                    onRefresh: _loadReports,
                    child: _reports.isEmpty
                        ? const Center(
                            child: Text(
                              'No road reports yet. Be the first to report!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                            itemCount: _reports.length,
                            itemBuilder: (_, i) => _buildCard(_reports[i]),
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
              'No internet — road data unavailable offline',
              style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── SUMMARY BAR ──────────────────────────────────────────
  Widget _buildSummaryBar() {
    int clear = 0, slippery = 0, blocked = 0;
    for (final r in _reports) {
      switch ((r['condition'] as String? ?? '').toLowerCase()) {
        case 'clear':
          clear++;
          break;
        case 'slippery':
          slippery++;
          break;
        case 'blocked':
          blocked++;
          break;
      }
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryChip('🟢 Clear', clear, const Color(0xFF16A34A)),
          _summaryChip('🟡 Slippery', slippery, const Color(0xFFD97706)),
          _summaryChip('🔴 Blocked', blocked, const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // ── ROAD CARD ────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> r) {
    final id = r['id'];
    final road = r['highway_name'] as String? ?? '';
    final condition = r['condition'] as String? ?? 'clear';
    final severity = r['severity'] as String? ?? 'minor';
    final notes = r['notes'] as String? ?? '';
    final passableFor = r['passable_for'] as String? ?? '';
    final vOngoing = (r['votes_ongoing'] as num?)?.toInt() ?? 0;
    final vBetter = (r['votes_better'] as num?)?.toInt() ?? 0;
    final vCleared = (r['votes_cleared'] as num?)?.toInt() ?? 0;
    final myVote = _myVotes[id];

    final condConfig = _conditionConfig(condition);
    final sevConfig = _severityConfig(severity);

    final ts = DateTime.tryParse(r['reported_at']?.toString() ?? '');
    String timeLabel = '';
    if (ts != null) {
      final diff = DateTime.now().difference(ts);
      if (diff.inMinutes < 1) {
        timeLabel = 'just now';
      } else if (diff.inHours < 1)
        timeLabel = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24)
        timeLabel = '${diff.inHours}h ago';
      else
        timeLabel = DateFormat('MMM d').format(ts);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ROAD NAME (big) + time ago ─────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    road,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF1C3A28),
                    ),
                  ),
                ),
                Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── CONDITION + SEVERITY BADGES ────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: condConfig['color'] as Color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    condConfig['label'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (sevConfig['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sevConfig['color'] as Color,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    sevConfig['label'] as String,
                    style: TextStyle(
                      color: sevConfig['color'] as Color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // ── NOTES ──────────────────────────────────────
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],

            // ── PASSABLE FOR (shown when cleared votes lead) ─
            if (passableFor.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 14,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Passable for: $passableFor',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── STATUS VOTE SECTION ────────────────────────
            const Text(
              'Is this still accurate?',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _voteButton(
                  id: id,
                  report: r,
                  vote: 'ongoing',
                  label: '🚧 Ongoing',
                  count: vOngoing,
                  myVote: myVote,
                  activeColor: const Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                _voteButton(
                  id: id,
                  report: r,
                  vote: 'better',
                  label: '📈 Getting Better',
                  count: vBetter,
                  myVote: myVote,
                  activeColor: const Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                _voteButton(
                  id: id,
                  report: r,
                  vote: 'cleared',
                  label: '✅ Cleared',
                  count: vCleared,
                  myVote: myVote,
                  activeColor: const Color(0xFF16A34A),
                  onTap: () => _showPassableDialog(r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── INDIVIDUAL VOTE BUTTON ───────────────────────────────
  Widget _voteButton({
    required dynamic id,
    required Map<String, dynamic> report,
    required String vote,
    required String label,
    required int count,
    required String? myVote,
    required Color activeColor,
    VoidCallback? onTap,
  }) {
    final isSelected = myVote == vote;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            onTap();
          } else {
            _castVote(report, vote);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PASSABLE FOR DIALOG (shows when tapping Cleared) ────
  void _showPassableDialog(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ Road Cleared',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Who can pass through?',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...kPassableFor.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A28),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _castVote(report, 'cleared', passableFor: option);
                    },
                    child: Text(option, style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            ),
            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── CONDITION CONFIG ─────────────────────────────────────
  Map<String, dynamic> _conditionConfig(String condition) {
    switch (condition.toLowerCase()) {
      case 'blocked':
        return {'color': const Color(0xFFDC2626), 'label': '🔴 BLOCKED'};
      case 'slippery':
        return {'color': const Color(0xFFD97706), 'label': '🟡 SLIPPERY'};
      default:
        return {'color': const Color(0xFF16A34A), 'label': '🟢 CLEAR'};
    }
  }

  // ── SEVERITY CONFIG ──────────────────────────────────────
  Map<String, dynamic> _severityConfig(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return {'color': const Color(0xFFDC2626), 'label': '⚠️ Severe'};
      case 'moderate':
        return {'color': const Color(0xFFD97706), 'label': '〽️ Moderate'};
      default:
        return {'color': const Color(0xFF6B7280), 'label': '🔹 Minor'};
    }
  }

  // ── REPORT DIALOG ────────────────────────────────────────
  void _showReportDialog(BuildContext context) {
    String selectedRoad = kRoads[0];
    String selectedCondition = 'clear';
    String selectedSeverity = 'minor';
    final notesController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
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
                    'Report Road Condition',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C3A28),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Road dropdown
                  const Text(
                    'Road:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoad,
                    items: kRoads
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedRoad = v!),
                  ),
                  const SizedBox(height: 12),

                  // Condition buttons
                  const Text(
                    'Condition:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: kConditions.map((c) {
                      final cfg = _conditionConfig(c);
                      final selected = selectedCondition == c;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selected
                                  ? cfg['color'] as Color
                                  : Colors.grey.shade200,
                              foregroundColor: selected
                                  ? Colors.white
                                  : Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () =>
                                setModalState(() => selectedCondition = c),
                            child: Text(
                              cfg['label'] as String,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Severity buttons
                  const Text(
                    'Severity:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: kSeverities.map((s) {
                      final cfg = _severityConfig(s);
                      final selected = selectedSeverity == s;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selected
                                  ? cfg['color'] as Color
                                  : Colors.grey.shade200,
                              foregroundColor: selected
                                  ? Colors.white
                                  : Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () =>
                                setModalState(() => selectedSeverity = s),
                            child: Text(
                              cfg['label'] as String,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g. Landslide near km 52',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Cancel
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

                  // Submit
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
                                await Supabase.instance.client
                                    .from('road_reports')
                                    .insert({
                                      'highway_name': selectedRoad,
                                      'condition': selectedCondition,
                                      'severity': selectedSeverity,
                                      'notes': notesController.text.trim(),
                                    });
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadReports();
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
                          : const Text(
                              'Submit Report',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
