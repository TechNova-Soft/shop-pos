import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/inventory_service.dart';
import '../../services/product_service.dart';
import 'stock_history_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await ProductService.instance.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('තොග තොරතුරු ලබා ගැනීමට නොහැකි විය.');
    }
  }

  Future<void> _showStockDialog(Product product, {required bool add}) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();

    final quantity = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(add ? 'තොග එකතු කරන්න' : 'තොග අඩු කරන්න'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${product.name}\nවර්තමාන තොගය: ${_formatQuantity(product.stockQuantity)}',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ප්‍රමාණය',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'හේතුව / සටහන (අවශ්‍ය නම්)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('අවලංගු කරන්න'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(quantityController.text.trim());

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: Text(add ? 'එකතු කරන්න' : 'අඩු කරන්න'),
            ),
          ],
        );
      },
    );

    quantityController.dispose();
    noteController.dispose();

    if (quantity == null) {
      return;
    }

    try {
      if (add) {
        await InventoryService.instance.addStock(
          productId: product.id,
          quantity: quantity,
          note: noteController.text,
        );
      } else {
        await InventoryService.instance.removeStock(
          productId: product.id,
          quantity: quantity,
          note: noteController.text,
        );
      }

      await _loadProducts();

      if (!mounted) return;

      _showMessage(
        add ? 'තොගය සාර්ථකව එකතු කරන ලදී.' : 'තොගය සාර්ථකව අඩු කරන ලදී.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _adjustStock(Product product) async {
    final controller = TextEditingController(
      text: _formatQuantity(product.stockQuantity),
    );

    final newQuantity = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('තොගය සංශෝධනය කරන්න'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'නව තොග ප්‍රමාණය',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('අවලංගු කරන්න'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());

                if (value == null || value < 0) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('සුරකින්න'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newQuantity == null) {
      return;
    }

    try {
      await InventoryService.instance.adjustStock(
        productId: product.id,
        newQuantity: newQuantity,
      );

      await _loadProducts();

      if (!mounted) return;

      _showMessage('තොගය සාර්ථකව සංශෝධනය කරන ලදී.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openHistory(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockHistoryScreen(product: product)),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('තොගය')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(child: Text('තොග කළමනාකරණයට භාණ්ඩ නැහැ.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = _products[index];

                final isLowStock =
                    product.stockQuantity <= product.lowStockLevel;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isLowStock)
                              const Chip(
                                avatar: Icon(Icons.warning_amber, size: 18),
                                label: Text('අඩු තොග'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'වර්තමාන තොගය: '
                          '${_formatQuantity(product.stockQuantity)}',
                        ),
                        Text(
                          'අඩු තොග සීමාව: '
                          '${_formatQuantity(product.lowStockLevel)}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () {
                                _showStockDialog(product, add: true);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('තොග එකතු කරන්න'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _showStockDialog(product, add: false);
                              },
                              icon: const Icon(Icons.remove),
                              label: const Text('තොග අඩු කරන්න'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _adjustStock(product);
                              },
                              child: const Text('සංශෝධනය'),
                            ),
                            IconButton(
                              tooltip: 'තොග ඉතිහාසය',
                              onPressed: () {
                                _openHistory(product);
                              },
                              icon: const Icon(Icons.history),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
