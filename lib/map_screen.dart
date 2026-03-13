import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

const LatLng kBenguetCenter = LatLng(16.4023, 120.5960);
const double kInitialZoom = 10.0;

// ── CROP COLOURS ─────────────────────────────────────────
const Map<String, Color> kCropColors = {
  'Repolyo': Color(0xFF7C3AED),
  'Karot': Color(0xFFEA580C),
  'Patatas': Color(0xFFCA8A04),
  'Kamatis': Color(0xFFDC2626),
  'Baguio Beans': Color(0xFF16A34A),
  'Sayote': Color(0xFF0891B2),
  'Sitaw': Color(0xFF65A30D),
  'Petsay': Color(0xFF0284C7),
  'Lettuce': Color(0xFF4ADE80),
  'Broccoli': Color(0xFF166534),
  'Pipino': Color(0xFF84CC16),
  'Sibuyas': Color(0xFFDB2777),
};

Color _cropColor(String crop) => kCropColors[crop] ?? const Color(0xFF6B7280);

// ── MARKET ZONES ─────────────────────────────────────────
const List<Map<String, dynamic>> kMarketZones = [
  {
    'name': 'BAPTC',
    'lat': 16.4631,
    'lng': 120.5918,
    'radius': 8000.0,
    'color': Color(0x221C3A28),
  },
  {
    'name': 'Baguio City',
    'lat': 16.4023,
    'lng': 120.5960,
    'radius': 6000.0,
    'color': Color(0x221D4ED8),
  },
  {
    'name': 'Balintawak',
    'lat': 14.6574,
    'lng': 121.0087,
    'radius': 5000.0,
    'color': Color(0x22DC2626),
  },
  {
    'name': 'Kamuning',
    'lat': 14.6320,
    'lng': 121.0320,
    'radius': 4000.0,
    'color': Color(0x22EA580C),
  },
  {
    'name': 'Divisoria',
    'lat': 14.5995,
    'lng': 120.9725,
    'radius': 4500.0,
    'color': Color(0x22CA8A04),
  },
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _supplyReports = [];
  Map<String, dynamic>? _myFarmer;
  bool _loading = true;
  bool _showFarms = true;
  bool _showSupply = true;
  bool _showLegend = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final farmersData = await Supabase.instance.client
          .from('farmers')
          .select('id, name, barangay, crops_grown, latitude, longitude')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final dateFrom = today.toIso8601String().substring(0, 10);
      final dateTo = tomorrow.toIso8601String().substring(0, 10);

      final supplyData = await Supabase.instance.client
          .from('supply_reports')
          .select('''
            id, crop_name, quantity, unit, market_name,
            planned_for,
            farmers(id, name, barangay, latitude, longitude)
          ''')
          .gte('planned_for', dateFrom)
          .lte('planned_for', dateTo);

      final myFarmer = await AuthService.getLocalFarmer();

      setState(() {
        _farmers = List<Map<String, dynamic>>.from(farmersData);
        _supplyReports = List<Map<String, dynamic>>.from(supplyData);
        _myFarmer = myFarmer;
        _loading = false;
      });
    } catch (e) {
      print('Map load error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmCount = _farmers.length;
    final supplyCount = _supplyReports.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: Text(
          _loading
              ? '🗺️ Farm Map'
              : '🗺️  $farmCount farms  ·  $supplyCount deliveries',
          style: const TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle farms',
            icon: Icon(
              Icons.location_pin,
              color: _showFarms ? const Color(0xFFE8C96A) : Colors.grey,
            ),
            onPressed: () => setState(() => _showFarms = !_showFarms),
          ),
          IconButton(
            tooltip: 'Toggle supply',
            icon: Icon(
              Icons.circle,
              color: _showSupply ? const Color(0xFFE8C96A) : Colors.grey,
            ),
            onPressed: () => setState(() => _showSupply = !_showSupply),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFE8B84B)),
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: _myFarmer != null && _myFarmer!['latitude'] != null
          ? FloatingActionButton.extended(
              heroTag: 'map_fab',
              backgroundColor: const Color(0xFF1C3A28),
              icon: const Icon(Icons.my_location, color: Color(0xFFE8C96A)),
              label: const Text(
                'My Farm',
                style: TextStyle(color: Color(0xFFE8C96A)),
              ),
              onPressed: _jumpToMyFarm,
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : Stack(
              children: [
                _buildMap(),
                _buildLegend(), // always present — shows icon or full card
              ],
            ),
    );
  }

  void _jumpToMyFarm() {
    final lat = (_myFarmer!['latitude'] as num).toDouble();
    final lng = (_myFarmer!['longitude'] as num).toDouble();
    _mapController.move(LatLng(lat, lng), 14.0);
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: kBenguetCenter,
        initialZoom: kInitialZoom,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.benguet_harvest',
          maxZoom: 19,
        ),
        CircleLayer(
          circles: kMarketZones
              .map(
                (zone) => CircleMarker(
                  point: LatLng(zone['lat'] as double, zone['lng'] as double),
                  radius: zone['radius'] as double,
                  useRadiusInMeter: true,
                  color: (zone['color'] as Color).withOpacity(0.15),
                  borderColor: zone['color'] as Color,
                  borderStrokeWidth: 2,
                ),
              )
              .toList(),
        ),
        if (_showSupply)
          MarkerLayer(
            markers: _supplyReports
                .where(
                  (r) =>
                      r['farmers'] != null && r['farmers']['latitude'] != null,
                )
                .map(_buildSupplyMarker)
                .toList(),
          ),
        if (_showFarms)
          MarkerLayer(markers: _farmers.map(_buildFarmMarker).toList()),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  // ── FARM MARKER ───────────────────────────────────────────

  Marker _buildFarmMarker(Map<String, dynamic> farmer) {
    final lat = (farmer['latitude'] as num).toDouble();
    final lng = (farmer['longitude'] as num).toDouble();
    final isMe = farmer['id'] == _myFarmer?['id'];
    return Marker(
      point: LatLng(lat, lng),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showFarmerSheet(farmer),
        child: Icon(
          Icons.location_pin,
          size: 36,
          color: isMe ? const Color(0xFFE8C96A) : const Color(0xFF2D5A3D),
        ),
      ),
    );
  }

  // ── SUPPLY MARKER ─────────────────────────────────────────

  Marker _buildSupplyMarker(Map<String, dynamic> report) {
    final farmer = report['farmers'] as Map<String, dynamic>;
    final lat = (farmer['latitude'] as num).toDouble();
    final lng = (farmer['longitude'] as num).toDouble();
    final crop = report['crop_name'] as String? ?? '?';
    final color = _cropColor(crop);
    final offsetLat = lat + 0.004;

    return Marker(
      point: LatLng(offsetLat, lng),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => _showSupplySheet(report),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              crop[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── FARM DETAIL SHEET ─────────────────────────────────────

  void _showFarmerSheet(Map<String, dynamic> farmer) {
    final name = farmer['name'] as String? ?? 'Unknown';
    final barangay = farmer['barangay'] as String? ?? '';
    final crops = (farmer['crops_grown'] as List?)?.cast<String>() ?? [];
    final isMe = farmer['id'] == _myFarmer?['id'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isMe
                      ? const Color(0xFFE8C96A)
                      : const Color(0xFF2D5A3D),
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: isMe ? const Color(0xFF1C3A28) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C3A28),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8C96A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C3A28),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (barangay.isNotEmpty)
                        Text(
                          barangay,
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (crops.isNotEmpty) ...[
              const Text(
                'Crops grown:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C3A28),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: crops
                    .map(
                      (c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(
                          0xFF2D5A3D,
                        ).withOpacity(0.12),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (crops.isEmpty)
              const Text(
                'No crops listed.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // ── SUPPLY DETAIL SHEET ───────────────────────────────────

  void _showSupplySheet(Map<String, dynamic> report) {
    final crop = report['crop_name'] as String? ?? '?';
    final qty = report['quantity'];
    final unit = report['unit'] as String? ?? 'kg';
    final market = report['market_name'] as String? ?? '?';
    final date = report['planned_for'] as String? ?? '';
    final farmer = report['farmers'] as Map<String, dynamic>? ?? {};
    final fName = farmer['name'] as String? ?? 'Unknown';
    final color = _cropColor(crop);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    radius: 20,
                    child: Text(
                      crop[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '${qty ?? '-'} $unit  →  $market',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.person_outline, 'Farmer', fName),
            _infoRow(Icons.storefront, 'Market', market),
            _infoRow(Icons.calendar_today, 'Delivery', date),
            _infoRow(Icons.scale, 'Quantity', '${qty ?? '-'} $unit'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2D5A3D)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.black87)),
        ),
      ],
    ),
  );

  // ── LEGEND ────────────────────────────────────────────────

  Widget _buildLegend() {
    // Collapsed — small icon button to bring legend back
    if (!_showLegend) {
      return Positioned(
        top: 12,
        right: 12,
        child: GestureDetector(
          onTap: () => setState(() => _showLegend = true),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
              ],
            ),
            child: const Icon(
              Icons.legend_toggle,
              size: 20,
              color: Color(0xFF1C3A28),
            ),
          ),
        ),
      );
    }

    // Expanded — full legend card
    return Positioned(
      top: 12,
      right: 12,
      child: GestureDetector(
        onTap: () => setState(() => _showLegend = false),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Legend',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF1C3A28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_less, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 6),
              _legendItem(
                Icons.location_pin,
                const Color(0xFF2D5A3D),
                'Farm location',
              ),
              _legendItem(
                Icons.location_pin,
                const Color(0xFFE8C96A),
                'Your farm',
              ),
              const Divider(height: 10),
              const Text(
                'Supply pins:',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              ...kCropColors.entries.map((e) => _legendDot(e.value, e.key)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _legendDot(Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
