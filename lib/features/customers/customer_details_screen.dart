import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_service.dart';
import 'customer_form_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});

  final int customerId;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  Customer? _customer;

  List<Map<String, dynamic>> _creditSales = [];
  List<Map<String, dynamic>> _payments = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final customer = await CustomerService.instance.getCustomerById(
        widget.customerId,
      );

      if (customer == null) {
        return;
      }

      final creditSales = await CustomerService.instance.getCreditSales(
        customer.id,
      );

      final payments = await CustomerService.instance.getPayments(customer.id);

      if (!mounted) return;

      setState(() {
        _customer = customer;
        _creditSales = creditSales;
        _payments = payments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editCustomer() async {
    final customer = _customer;

    if (customer == null) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: customer)),
    );

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _addPayment() async {
    final customer = _customer;

    if (customer == null || customer.outstandingAmount <= 0) {
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('නයට ගෙවීමක් සටහන් කරන්න'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'තව ලැබිය යුතු: '
                  'රු. ${customer.outstandingAmount.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ගෙවූ මුදල',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'සටහන (අවශ්‍ය නම්)',
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
                final value = double.tryParse(amountController.text.trim());

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('ගෙවීම සුරකින්න'),
            ),
          ],
        );
      },
    );

    final note = noteController.text;

    amountController.dispose();
    noteController.dispose();

    if (amount == null) {
      return;
    }

    try {
      await CustomerService.instance.addPayment(
        customerId: customer.id,
        amount: amount,
        note: note,
      );

      await _loadData();

      if (!mounted) return;

      _showMessage('ගෙවීම සාර්ථකව සටහන් කරන ලදී.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(dynamic value) {
    final amount = (value as num).toDouble();
    return 'රු. ${amount.toStringAsFixed(2)}';
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final customer = _customer;

    if (customer == null) {
      return const Scaffold(
        body: Center(child: Text('පාරිභෝගිකයා හමු නොවීය.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            tooltip: 'වෙනස් කරන්න',
            onPressed: _editCustomer,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      floatingActionButton: customer.outstandingAmount > 0
          ? FloatingActionButton.extended(
              onPressed: _addPayment,
              icon: const Icon(Icons.payments),
              label: const Text('ගෙවීමක් සටහන් කරන්න'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: 8),
                    Text('දුරකථන අංකය: ${customer.phone}'),
                  ],
                  if (customer.address != null) ...[
                    const SizedBox(height: 8),
                    Text('ලිපිනය: ${customer.address}'),
                  ],
                  if (customer.note != null) ...[
                    const SizedBox(height: 8),
                    Text('සටහන: ${customer.note}'),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'තව ලැබිය යුතු මුදල',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(customer.outstandingAmount),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: customer.outstandingAmount > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'නයට දුන් විකුණුම්',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_creditSales.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('නයට දුන් විකුණුම් තවම නැහැ.'),
              ),
            )
          else
            ..._creditSales.map((sale) {
              return Card(
                child: ListTile(
                  title: Text('බිල් අංකය: ${sale['invoice_no']}'),
                  subtitle: Text(
                    '${_date(sale['created_at'] as String)}\n'
                    'මුළු මුදල: ${_money(sale['total'])}\n'
                    'ගෙවා ඇති මුදල: ${_money(sale['paid_amount'])}',
                  ),
                  trailing: Text(
                    'තව: ${_money(sale['due_amount'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          const Text(
            'නය ගෙවීම්',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ගෙවීම් තවම සටහන් කරලා නැහැ.'),
              ),
            )
          else
            ..._payments.map((payment) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(_money(payment['amount'])),
                  subtitle: Text(
                    '${_date(payment['created_at'] as String)}'
                    '${payment['note'] != null ? '\n${payment['note']}' : ''}',
                  ),
                ),
              );
            }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
