import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();
  final _quickQuantitiesController = TextEditingController(text: '1, 2, 5, 10');

  List<Category> _categories = [];
  int? _selectedCategoryId;

  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final categories = await CategoryService.instance.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
      });

      final product = widget.product;

      if (product != null) {
        _nameController.text = product.name;
        _barcodeController.text = product.barcode ?? '';
        _buyingPriceController.text = product.buyingPrice.toString();
        _sellingPriceController.text = product.sellingPrice.toString();
        _lowStockController.text = product.lowStockLevel.toString();
        _selectedCategoryId = product.categoryId;

        final quantities = await ProductService.instance.getQuickQuantities(
          product.id,
        );

        if (!mounted) return;

        if (quantities.isNotEmpty) {
          _quickQuantitiesController.text = quantities
              .map((quantity) {
                if (quantity == quantity.roundToDouble()) {
                  return quantity.toInt().toString();
                }

                return quantity.toString();
              })
              .join(', ');
        }
      } else {
        _stockController.text = '0';
        _lowStockController.text = '5';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _quickQuantitiesController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('අලුත් වර්ගයක්'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'වර්ගයේ නම',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(context, value);
            },
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
                Navigator.pop(context, controller.text);
              },
              child: const Text('එකතු කරන්න'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty) {
      return;
    }

    try {
      final id = await CategoryService.instance.addCategory(name);

      final categories = await CategoryService.instance.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _selectedCategoryId = id;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<double> _parseQuickQuantities() {
    final values = <double>[];

    final parts = _quickQuantitiesController.text.split(',');

    for (final part in parts) {
      final value = double.tryParse(part.trim());

      if (value == null || value <= 0) {
        continue;
      }

      if (!values.contains(value)) {
        values.add(value);
      }
    }

    return values;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final buyingPrice = double.parse(_buyingPriceController.text.trim());

    final sellingPrice = double.parse(_sellingPriceController.text.trim());

    final lowStockLevel = double.parse(_lowStockController.text.trim());

    final initialStock = widget.isEditing
        ? 0.0
        : double.parse(_stockController.text.trim());

    final quickQuantities = _parseQuickQuantities();

    if (quickQuantities.isEmpty) {
      _showMessage('අවම වශයෙන් එක් ඉක්මන් ප්‍රමාණයක් ඇතුළත් කරන්න.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.product == null) {
        await ProductService.instance.addProduct(
          name: _nameController.text,
          barcode: _barcodeController.text,
          buyingPrice: buyingPrice,
          sellingPrice: sellingPrice,
          initialStock: initialStock,
          lowStockLevel: lowStockLevel,
          categoryId: _selectedCategoryId,
          quickQuantities: quickQuantities,
        );
      } else {
        await ProductService.instance.updateProduct(
          id: widget.product!.id,
          name: _nameController.text,
          barcode: _barcodeController.text,
          buyingPrice: buyingPrice,
          sellingPrice: sellingPrice,
          lowStockLevel: lowStockLevel,
          categoryId: _selectedCategoryId,
          quickQuantities: quickQuantities,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  String? _positiveNumber(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    final number = double.tryParse(value.trim());

    if (number == null || number <= 0) {
      return message;
    }

    return null;
  }

  String? _nonNegativeNumber(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    final number = double.tryParse(value.trim());

    if (number == null || number < 0) {
      return message;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'භාණ්ඩය වෙනස් කරන්න' : 'භාණ්ඩයක් එකතු කරන්න',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _decoration('භාණ්ඩයේ නම'),
                    validator: (value) {
                      return _requiredText(value, 'භාණ්ඩයේ නම ඇතුළත් කරන්න');
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedCategoryId,
                    decoration: _decoration('වර්ගය'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('වර්ගයක් නැහැ'),
                      ),
                      ..._categories.map((category) {
                        return DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('අලුත් වර්ගයක් එකතු කරන්න'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: _decoration('තීරු කේතය (අවශ්‍ය නම්)'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('මිලදී ගත් මිල'),
                    validator: (value) {
                      return _nonNegativeNumber(
                        value,
                        'නිවැරදි මිලක් ඇතුළත් කරන්න',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('විකුණුම් මිල'),
                    validator: (value) {
                      return _positiveNumber(
                        value,
                        'විකුණුම් මිල 0 ට වඩා වැඩි විය යුතුයි',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!widget.isEditing) ...[
                    TextFormField(
                      controller: _stockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decoration('ආරම්භක තොගය'),
                      validator: (value) {
                        return _nonNegativeNumber(
                          value,
                          'නිවැරදි තොග ප්‍රමාණයක් ඇතුළත් කරන්න',
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _lowStockController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('අඩු තොග සීමාව'),
                    validator: (value) {
                      return _nonNegativeNumber(
                        value,
                        'නිවැරදි අඩු තොග සීමාවක් ඇතුළත් කරන්න',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quickQuantitiesController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('ඉක්මන් ප්‍රමාණ')
                        .copyWith(helperText: 'උදා: 1, 2, 5, 10'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'වෙනස්කම් සුරකින්න'
                                  : 'භාණ්ඩය සුරකින්න',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
