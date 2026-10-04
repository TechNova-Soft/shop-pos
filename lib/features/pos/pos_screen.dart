import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../services/customer_service.dart';
import '../../services/pos_service.dart';
import '../../services/product_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  List<Product> _products = [];
  List<CartItem> _cart = [];

  Customer? _selectedCustomer;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('භාණ්ඩ ලබා ගැනීමට නොහැකි විය.');
    }
  }

  double get _subtotal {
    return _cart.fold(0, (total, item) => total + item.subtotal);
  }

  double get _discount {
    return double.tryParse(_discountController.text.trim()) ?? 0;
  }

  double get _total {
    final discount = _discount;

    if (discount < 0 || discount > _subtotal) {
      return _subtotal;
    }

    return _subtotal - discount;
  }

  Future<void> _selectProduct(Product product) async {
    final quickQuantities = await ProductService.instance.getQuickQuantities(
      product.id,
    );

    if (!mounted) return;

    final quantity = await _showQuantityDialog(product, quickQuantities);

    if (quantity == null) {
      return;
    }

    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );

    final existingQuantity = existingIndex == -1
        ? 0.0
        : _cart[existingIndex].quantity;

    if (existingQuantity + quantity > product.stockQuantity) {
      _showMessage(
        'ප්‍රමාණවත් තොගයක් නැහැ. '
        'ඉතිරි තොගය: ${_formatQuantity(product.stockQuantity - existingQuantity)}',
      );
      return;
    }

    setState(() {
      if (existingIndex == -1) {
        _cart.add(CartItem(product: product, quantity: quantity));
      } else {
        _cart[existingIndex] = _cart[existingIndex].copyWith(
          quantity: existingQuantity + quantity,
        );
      }
    });
  }

  Future<double?> _showQuantityDialog(
    Product product,
    List<double> quickQuantities,
  ) async {
    final controller = TextEditingController();

    final quantities = quickQuantities.isEmpty ? <double>[1] : quickQuantities;

    final selected = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ඉතිරි තොගය: '
                '${_formatQuantity(product.stockQuantity)}',
              ),
              const SizedBox(height: 16),
              const Text('ඉක්මන් ප්‍රමාණයක් තෝරන්න'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...quantities.map((quantity) {
                    return OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, quantity);
                      },
                      child: Text(_formatQuantity(quantity)),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: false,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'වෙනත් ප්‍රමාණයක්',
                  hintText: 'උදා: 3, 7.5',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('අවලංගු කරන්න'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('එකතු කරන්න'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return selected;
  }

  void _decreaseQuantity(int index) {
    final item = _cart[index];

    if (item.quantity <= 1) {
      setState(() {
        _cart.removeAt(index);
      });
      return;
    }

    setState(() {
      _cart[index] = item.copyWith(quantity: item.quantity - 1);
    });
  }

  void _increaseQuantity(int index) {
    final item = _cart[index];

    if (item.quantity + 1 > item.product.stockQuantity) {
      _showMessage('ප්‍රමාණවත් තොගයක් නැහැ.');
      return;
    }

    setState(() {
      _cart[index] = item.copyWith(quantity: item.quantity + 1);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  Future<Customer?> _selectCustomer() async {
    final customers = await CustomerService.instance.getCustomers();

    if (!mounted) return null;

    return showDialog<Customer>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('පාරිභෝගිකයා තෝරන්න'),
          content: SizedBox(
            width: 450,
            height: 450,
            child: customers.isEmpty
                ? const Center(child: Text('තවම පාරිභෝගිකයින් නැහැ.'))
                : ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = customers[index];

                      return ListTile(
                        onTap: () {
                          Navigator.pop(context, customer);
                        },
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(customer.name),
                        subtitle: customer.phone == null
                            ? null
                            : Text(customer.phone!),
                        trailing: customer.outstandingAmount > 0
                            ? Text(
                                'නය: රු. ${customer.outstandingAmount.toStringAsFixed(2)}',
                              )
                            : null,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('අවලංගු කරන්න'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      _showMessage('කරත්තයට භාණ්ඩ එකතු කරන්න.');
      return;
    }

    final total = _total;

    if (_discount < 0 || _discount > _subtotal) {
      _showMessage('වට්ටම නිවැරදිව ඇතුළත් කරන්න.');
      return;
    }

    String paymentMethod = 'cash';
    double paidAmount = total;
    Customer? customer = _selectedCustomer;

    final paidController = TextEditingController(
      text: total.toStringAsFixed(2),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final due = paymentMethod == 'cash'
                ? 0.0
                : paymentMethod == 'credit'
                ? total
                : (total - (double.tryParse(paidController.text.trim()) ?? 0))
                      .clamp(0, total);

            return AlertDialog(
              title: const Text('විකුණුම අවසන් කරන්න'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'මුළු එකතුව: '
                        'රු. ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'ගෙවීම් ක්‍රමය',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('මුදලින්'),
                          ),
                          DropdownMenuItem(value: 'credit', child: Text('ණයට')),
                          DropdownMenuItem(
                            value: 'partial',
                            child: Text('කොටසක් ගෙවා'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            paymentMethod = value;

                            if (value == 'cash') {
                              paidAmount = total;
                              paidController.text = total.toStringAsFixed(2);
                            } else if (value == 'credit') {
                              paidAmount = 0;
                              paidController.text = '0';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (paymentMethod == 'partial') ...[
                        TextField(
                          controller: paidController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            setDialogState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: 'දැනට ගෙවන මුදල',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'තව ගෙවීමට ඇති මුදල: '
                          'රු. ${due.toStringAsFixed(2)}',
                        ),
                      ],
                      if (paymentMethod != 'cash') ...[
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            customer == null
                                ? 'පාරිභෝගිකයෙකු තෝරා නැහැ'
                                : customer!.name,
                          ),
                          subtitle: Text(
                            customer == null
                                ? 'නයට විකිණීම සඳහා පාරිභෝගිකයෙකු අවශ්‍යයි.'
                                : customer!.phone ?? '',
                          ),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final selected = await _selectCustomer();

                              if (selected == null) {
                                return;
                              }

                              setDialogState(() {
                                customer = selected;
                              });
                            },
                            child: Text(
                              customer == null ? 'තෝරන්න' : 'වෙනස් කරන්න',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('අවලංගු කරන්න'),
                ),
                FilledButton(
                  onPressed: () {
                    paidAmount = paymentMethod == 'cash'
                        ? total
                        : paymentMethod == 'credit'
                        ? 0
                        : double.tryParse(paidController.text.trim()) ?? 0;

                    if (paymentMethod != 'cash' && customer == null) {
                      _showMessage('පාරිභෝගිකයෙකු තෝරන්න.');
                      return;
                    }

                    Navigator.pop(context, true);
                  },
                  child: const Text('විකුණුම තහවුරු කරන්න'),
                ),
              ],
            );
          },
        );
      },
    );

    final selectedCustomer = customer;

    paidController.dispose();

    if (result != true) {
      return;
    }

    try {
      final invoiceNo = await PosService.instance.completeSale(
        items: _cart,
        discount: _discount,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        customerId: selectedCustomer?.id,
      );

      if (!mounted) return;

      setState(() {
        _cart = [];
        _selectedCustomer = null;
        _discountController.text = '0';
      });

      _showMessage('විකුණුම සාර්ථකයි. බිල් අංකය: $invoiceNo');

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
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

  Widget _buildProductList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return const Center(child: Text('භාණ්ඩ හමු නොවීය.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = _products[index];

        return Card(
          child: ListTile(
            onTap: () => _selectProduct(product),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'රු. ${product.sellingPrice.toStringAsFixed(2)}'
              '   |   තොගය: ${_formatQuantity(product.stockQuantity)}',
            ),
            trailing: const Icon(Icons.add_circle_outline),
          ),
        );
      },
    );
  }

  Widget _buildCart() {
    return Column(
      children: [
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Text(
                    'කරත්තයට තවම භාණ්ඩ එකතු කරලා නැහැ.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cart.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _cart[index];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _removeItem(index);
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    _decreaseQuantity(index);
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  _formatQuantity(item.quantity),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _increaseQuantity(index);
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                const Spacer(),
                                Text(
                                  'රු. ${item.subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('මුළු එකතුව')),
                  Text('රු. ${_subtotal.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'වට්ටම',
                  border: OutlineInputBorder(),
                  prefixText: 'රු. ',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ගෙවිය යුතු මුළු මුදල',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'රු. ${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _cart.isEmpty ? null : _checkout,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('විකුණුම අවසන් කරන්න'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('විකුණුම්')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadProducts(),
              decoration: InputDecoration(
                labelText: 'භාණ්ඩ සොයන්න',
                hintText: 'භාණ්ඩයේ නම හෝ තීරු කේතය',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      Expanded(flex: 5, child: _buildProductList()),
                      const Divider(height: 1),
                      Expanded(flex: 5, child: _buildCart()),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 6, child: _buildProductList()),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 5, child: _buildCart()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
