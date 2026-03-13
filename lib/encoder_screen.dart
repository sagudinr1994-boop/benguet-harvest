import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'app_config.dart';

// All crops the encoder can price
const List<String> kAllCrops = [
  'Repolyo',
  'Karot',
  'Patatas',
  'Kamatis',
  'Baguio Beans',
  'Sayote',
  'Sitaw',
  'Petsay',
  'Lettuce',
  'Broccoli',
  'Pipino',
  'Sibuyas',
];

const List<String> kMarkets = [
  'BAPTC La Trinidad',
  'Baguio City Market',
  'Balintawak',
  'Kamuning',
  'Divisoria',
];

class EncoderScreen extends StatefulWidget {
  const EncoderScreen({super.key});
  @override
  State<EncoderScreen> createState() => _EncoderScreenState();
}

class _EncoderScreenState extends State<EncoderScreen> {
  final _priceCtrl = TextEditingController();
  String? _selectedCrop;
  String? _selectedMarket;
  bool _isSubmitting = false;
  String? _successMsg;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    AppConfig.instance.addListener(_onConfigChanged);
  }

  void _onConfigChanged() => setState(() {});

  @override
  void dispose() {
    AppConfig.instance.removeListener(_onConfigChanged);
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final priceText = _priceCtrl.text.trim();
    if (_selectedCrop == null) {
      setState(() => _errorMsg = 'Please select a crop.');
      return;
    }
    if (_selectedMarket == null) {
      setState(() => _errorMsg = 'Please select a market.');
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() => _errorMsg = 'Enter a valid price (e.g. 45.50).');
      return;
    }

    // Ask for confirmation before submitting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Price'),
        content: Text(
          'Submit $_selectedCrop at PHP ${price.toStringAsFixed(2)}/kg in $_selectedMarket?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C3A28),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
      _successMsg = null;
    });

    try {
      await AdminService.submitPrice(
        cropName: _selectedCrop!,
        pricePerKg: price,
        market: _selectedMarket!,
      );

      setState(() {
        _isSubmitting = false;
        _successMsg =
            'Submitted for review! Admin will approve $_selectedCrop @ P${price.toStringAsFixed(2)}/kg in $_selectedMarket.';
        _priceCtrl.clear();
        _selectedCrop = null;
        _selectedMarket = null;
      });
    } catch (e) {
      debugPrint('submitPrice error: $e');
      setState(() {
        _isSubmitting = false;
        _errorMsg = 'Failed to submit. Check connection and try again.';
      });
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
          'Submit Price',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.price_change_outlined,
              size: 56,
              color: Color(0xFF2D5A3D),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter Market Price',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const Text(
              'This price will appear on the Price Board.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),

            // Crop dropdown
            const Text(
              'Crop',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Select crop',
              ),
              items: AppConfig.instance.crops
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCrop = v),
            ),
            const SizedBox(height: 16),

            // Market dropdown
            const Text(
              'Market',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedMarket,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Select market',
              ),
              items: AppConfig.instance.markets
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMarket = v),
            ),
            const SizedBox(height: 16),

            // Price field
            const Text(
              'Price per kg (PHP)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C3A28),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: 'e.g.  45.50',
                prefixText: 'PHP  ',
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMsg != null) ...[
              Text(
                _errorMsg!,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Success message
            if (_successMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4A8C5C)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2D5A3D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMsg!,
                        style: const TextStyle(
                          color: Color(0xFF14532D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C3A28),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Price',
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
