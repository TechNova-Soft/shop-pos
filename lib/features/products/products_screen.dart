import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_service.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await ProductService.instance.getProducts(
        search: _searchController.text,
      );

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('භාණ්ඩ ලබා ගැනීමට නොහැකි විය.');
    }
  }

  Future<void> _openAddProduct() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProductFormScreen()));

    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<void> _openEditProduct(Product product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('භාණ්ඩය ඉවත් කරන්නද?'),
          content: Text('${product.name} භාණ්ඩය ලැයිස්තුවෙන් ඉවත් කරන්නේද?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('අවලංගු කරන්න'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('ඉවත් කරන්න'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ProductService.instance.deleteProduct(product.id);

    await _loadProducts();

    if (!mounted) return;

    _showMessage('භාණ්ඩය ඉවත් කරන ලදී.');
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
      appBar: AppBar(title: const Text('භාණ්ඩ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('භාණ්ඩ එකතු කරන්න'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadProducts(),
              decoration: InputDecoration(
                labelText: 'භාණ්ඩ සොයන්න',
                hintText: 'නම හෝ තීරු කේතය',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                ? const Center(child: Text('තවම භාණ්ඩ එකතු කරලා නැහැ.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _products.length,
                    separatorBuilder: (_, _) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final product = _products[index];

                      final isLowStock =
                          product.stockQuantity <= product.lowStockLevel;

                      return Card(
                        child: ListTile(
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.categoryName != null)
                                Text(product.categoryName!),
                              const SizedBox(height: 4),
                              Text(
                                'විකුණුම් මිල: රු. ${product.sellingPrice.toStringAsFixed(2)}',
                              ),
                              Text(
                                'තොගය: ${_formatQuantity(product.stockQuantity)}',
                              ),
                              if (isLowStock)
                                const Text(
                                  '⚠ අඩු තොග',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              product.name.isEmpty
                                  ? '?'
                                  : product.name[0].toUpperCase(),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openEditProduct(product);
                              } else if (value == 'delete') {
                                _deleteProduct(product);
                              }
                            },
                            itemBuilder: (_) {
                              return const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('වෙනස් කරන්න'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('ඉවත් කරන්න'),
                                ),
                              ];
                            },
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
