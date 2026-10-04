import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/inventory_service.dart';

class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({super.key, required this.product});

  final Product product;

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await InventoryService.instance.getStockHistory(
        widget.product.id,
      );

      if (!mounted) return;

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  String _movementLabel(String type) {
    switch (type) {
      case 'initial':
        return 'ආරම්භක තොගය';
      case 'add':
        return 'තොග එකතු කිරීම';
      case 'remove':
        return 'තොග අඩු කිරීම';
      case 'adjust':
        return 'තොග සංශෝධනය';
      case 'sale':
        return 'විකුණුම';
      default:
        return 'තොග වෙනස්වීම';
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('තොග ඉතිහාසය')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text('තොග වෙනස්වීම් තවම නැහැ.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _history.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = _history[index];

                            final change = (item['quantity_change'] as num)
                                .toDouble();

                            final before = (item['stock_before'] as num)
                                .toDouble();

                            final after = (item['stock_after'] as num)
                                .toDouble();

                            return ListTile(
                              title: Text(
                                _movementLabel(item['movement_type'] as String),
                              ),
                              subtitle: Text(
                                '${_formatDate(item['created_at'] as String)}\n'
                                'පෙර: ${_formatNumber(before)}  →  '
                                'පසු: ${_formatNumber(after)}',
                              ),
                              trailing: Text(
                                '${change >= 0 ? '+' : ''}'
                                '${_formatNumber(change)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: change >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
