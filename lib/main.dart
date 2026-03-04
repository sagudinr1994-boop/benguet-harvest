import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

final supabaseUrl = Env.supabaseUrl;
final supabaseKey = Env.supabaseKey;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const BenguetHarvestApp());
}

class BenguetHarvestApp extends StatelessWidget {
  const BenguetHarvestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Benguet Harvest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C3A28)),
        useMaterial3: true,
      ),
      home: const PriceBoard(),
    );
  }
}

class PriceBoard extends StatefulWidget {
  const PriceBoard({super.key});

  @override
  State<PriceBoard> createState() => _PriceBoardState();
}

class _PriceBoardState extends State<PriceBoard> {
  List<Map<String, dynamic>> prices = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadPrices();
  }

  Future<void> loadPrices() async {
    try {
      final data = await Supabase.instance.client
          .from('prices')
          .select()
          .order('crop_name');
      setState(() {
        prices = List<Map<String, dynamic>>.from(data);
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load prices. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 19, 58, 35),
        title: const Text(
          '■ Benguet Harvest',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF2EDE6),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C3A28)),
            )
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => isLoading = true);
                      loadPrices();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : prices.isEmpty
          ? const Center(
              child: Text(
                'No prices listed for today.',
                style: TextStyle(color: Color(0xFF1C3A28), fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prices.length,
              itemBuilder: (context, index) {
                final price = prices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    title: Text(
                      price['crop_name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Color(0xFF1C3A28),
                      ),
                    ),
                    subtitle: Text(
                      '${price['market_name'] ?? ''}  ·  Source: ${price['source'] ?? ''}',
                    ),
                    trailing: Text(
                      '₱${price["price_per_kilo"]}/kg',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D5A3D),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
