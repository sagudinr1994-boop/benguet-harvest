import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

// Typical yield in kg per sqm for Benguet highland crops
const Map<String, double> kYieldPerSqm = {
  'Repolyo': 3.5,
  'Karot': 2.8,
  'Patatas': 2.0,
  'Kamatis': 4.5,
  'Baguio Beans': 1.2,
  'Sayote': 5.0,
  'Sitaw': 1.0,
  'Petsay': 2.5,
  'Lettuce': 3.0,
  'Broccoli': 1.8,
  'Pipino': 3.5,
  'Sibuyas': 2.0,
};

class CropCalculatorScreen extends StatefulWidget {
  const CropCalculatorScreen({super.key});
  @override
  State<CropCalculatorScreen> createState() => _CropCalculatorState();
}

class _CropCalculatorState extends State<CropCalculatorScreen> {
  final _areaCtrl = TextEditingController();
  String _selectedCrop = kYieldPerSqm.keys.first;
  String _selectedMarket = AppConfig.instance.markets.first;
  double? _livePrice;
  bool _loadingPrice = false;

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPrice() async {
    setState(() {
      _loadingPrice = true;
      _livePrice = null;
    });
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final data = await Supabase.instance.client
          .from('prices')
          .select('price_per_kilo')
          .eq('crop_name', _selectedCrop)
          .eq('market_name', _selectedMarket)
          .eq('date_for', today)
          .order('date_for', ascending: false)
          .limit(1)
          .maybeSingle();
      setState(() {
        _livePrice = data != null
            ? (data['price_per_kilo'] as num).toDouble()
            : null;
        _loadingPrice = false;
      });
    } catch (_) {
      setState(() => _loadingPrice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final area = double.tryParse(_areaCtrl.text.trim()) ?? 0;
    final yield_ = kYieldPerSqm[_selectedCrop] ?? 2.0;
    final estKg = area * yield_;
    final estRevenue = _livePrice != null ? estKg * _livePrice! : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: const Text(
          'Crop Calculator',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estimate your harvest revenue based on farm area and current market prices.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Crop
            _label('Crop'),
            DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              decoration: _inputDec('Select crop'),
              items: kYieldPerSqm.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCrop = v!;
                  _livePrice = null;
                });
              },
            ),
            const SizedBox(height: 14),

            // Market
            _label('Market'),
            DropdownButtonFormField<String>(
              initialValue: _selectedMarket,
              decoration: _inputDec('Select market'),
              items: AppConfig.instance.markets
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedMarket = v!;
                  _livePrice = null;
                });
              },
            ),
            const SizedBox(height: 14),

            // Area
            _label('Farm Area (sqm)'),
            TextField(
              controller: _areaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDec('e.g. 1000'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Fetch price button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2D5A3D)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _loadingPrice
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2D5A3D),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Color(0xFF2D5A3D)),
                label: Text(
                  _livePrice != null
                      ? 'Live price: ₱${_livePrice!.toStringAsFixed(0)}/kg  (tap to refresh)'
                      : 'Fetch today\'s market price',
                  style: const TextStyle(color: Color(0xFF2D5A3D)),
                ),
                onPressed: _loadingPrice ? null : _fetchPrice,
              ),
            ),
            const SizedBox(height: 24),

            // Results
            if (area > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C3A28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimate',
                      style: TextStyle(
                        color: Color(0xFFE8B84B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _resultRow(
                      'Area',
                      '${area.toStringAsFixed(0)} sqm',
                    ),
                    _resultRow(
                      'Yield rate',
                      '${yield_.toStringAsFixed(1)} kg/sqm',
                    ),
                    _resultRow(
                      'Est. harvest',
                      '${estKg.toStringAsFixed(0)} kg',
                    ),
                    if (_livePrice != null) ...[
                      const Divider(color: Colors.white24, height: 20),
                      _resultRow(
                        'Price at $_selectedMarket',
                        '₱${_livePrice!.toStringAsFixed(0)}/kg',
                      ),
                      _resultRow(
                        'Est. revenue',
                        '₱${estRevenue!.toStringAsFixed(0)}',
                        highlight: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yield rates are typical Benguet highland averages. Actual results vary by variety, soil, and season.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _resultRow(String label, String value, {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(
              value,
              style: TextStyle(
                color: highlight ? const Color(0xFFE8B84B) : Colors.white,
                fontWeight:
                    highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 18 : 14,
              ),
            ),
          ],
        ),
      );
}
