import 'package:flutter/material.dart';
import 'harvest_calendar_screen.dart';
import 'trader_directory_screen.dart';
import 'cargo_screen.dart';
import 'buyer_board_screen.dart';
import 'map_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        title: const Text(
          '🧰 Tools',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── MAIN TOOL GRID ─────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _toolCard(
                context,
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF16A34A),
                title: 'Harvest\nCalendar',
                subtitle: 'Track harvest dates',
                screen: const HarvestCalendarScreen(),
              ),
              _toolCard(
                context,
                icon: Icons.people_outline,
                color: const Color(0xFF7C3AED),
                title: 'Trader\nDirectory',
                subtitle: 'Find crop buyers',
                screen: const TraderDirectoryScreen(),
              ),
              _toolCard(
                context,
                icon: Icons.local_shipping_outlined,
                color: const Color(0xFFEA580C),
                title: 'Cargo\nSharing',
                subtitle: 'Share truck space',
                screen: const CargoScreen(),
              ),
              _toolCard(
                context,
                icon: Icons.storefront_outlined,
                color: const Color(0xFFDC2626),
                title: 'Buyer\nBoard',
                subtitle: 'Restaurant & canteen orders',
                screen: const BuyerBoardScreen(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── MAP (full width) ───────────────────────────
          _mapCard(context),
        ],
      ),
    );
  }

  Widget _toolCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1C3A28),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const MapScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C3A28),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.map_outlined,
                  color: Color(0xFFE8C96A), size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farm Map',
                    style: TextStyle(
                      color: Color(0xFFE8B84B),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'See farms, supply pins and market zones',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
