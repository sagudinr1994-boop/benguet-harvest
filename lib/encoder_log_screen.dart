import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EncoderLogScreen extends StatefulWidget {
  const EncoderLogScreen({super.key});
  @override
  State<EncoderLogScreen> createState() => _EncoderLogState();
}

class _EncoderLogState extends State<EncoderLogScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String()
          .substring(0, 10);
      final data = await Supabase.instance.client
          .from('prices')
          .select('crop_name, market_name, price_per_kilo, date_for, date_updated, status')
          .gte('date_for', cutoff)
          .order('date_updated', ascending: false)
          .limit(100);
      setState(() {
        _entries = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
          'Price Activity Log',
          style: TextStyle(
              color: Color(0xFFE8B84B), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)))
          : _entries.isEmpty
              ? const Center(
                  child: Text('No price entries in the last 30 days.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  itemBuilder: (_, i) => _buildRow(_entries[i]),
                ),
    );
  }

  Widget _buildRow(Map<String, dynamic> e) {
    final crop = e['crop_name'] as String? ?? '';
    final market = e['market_name'] as String? ?? '';
    final price = (e['price_per_kilo'] as num?)?.toDouble() ?? 0;
    final dateFor = e['date_for'] as String? ?? '';
    final updated = DateTime.tryParse(
        e['date_updated']?.toString() ?? '');
    final status = e['status'] as String? ?? 'published';

    final isPending = status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isPending
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFDCFCE7),
          child: Icon(
            isPending ? Icons.hourglass_top : Icons.check,
            size: 16,
            color: isPending
                ? const Color(0xFFD97706)
                : const Color(0xFF16A34A),
          ),
        ),
        title: Text(
          '$crop  ·  ₱${price.toStringAsFixed(0)}/kg',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1C3A28)),
        ),
        subtitle: Text(
          '$market  ·  $dateFor',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: updated != null
            ? Text(
                DateFormat('MMM d, h:mm a').format(updated),
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey),
              )
            : null,
      ),
    );
  }
}
