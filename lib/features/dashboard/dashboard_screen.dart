import 'package:flutter/material.dart';

import '../products/products_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('මුල් පිටුව')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _DashboardCard(
              icon: Icons.inventory_2_outlined,
              title: 'භාණ්ඩ',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsScreen()),
                );
              },
            ),
            _DashboardCard(
              icon: Icons.warehouse_outlined,
              title: 'තොගය',
              onTap: () {},
            ),
            _DashboardCard(
              icon: Icons.point_of_sale_outlined,
              title: 'විකුණුම්',
              onTap: () {},
            ),
            _DashboardCard(
              icon: Icons.bar_chart_outlined,
              title: 'වාර්තා',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
