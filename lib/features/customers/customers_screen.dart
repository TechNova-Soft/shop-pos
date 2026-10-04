import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_service.dart';
import 'customer_details_screen.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();

  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customers = await CustomerService.instance.getCustomers(
        search: _searchController.text,
      );

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('පාරිභෝගික තොරතුරු ලබා ගැනීමට නොහැකි විය.');
    }
  }

  Future<void> _addCustomer() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CustomerFormScreen()));

    if (saved == true) {
      await _loadCustomers();
    }
  }

  Future<void> _openCustomer(Customer customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailsScreen(customerId: customer.id),
      ),
    );

    await _loadCustomers();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) {
    return 'රු. ${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('පාරිභෝගිකයින්')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('පාරිභෝගිකයෙකු එකතු කරන්න'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadCustomers(),
              decoration: InputDecoration(
                labelText: 'පාරිභෝගිකයෙකු සොයන්න',
                hintText: 'නම හෝ දුරකථන අංකය',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _loadCustomers();
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
                : _customers.isEmpty
                ? const Center(child: Text('තවම පාරිභෝගිකයින් එකතු කරලා නැහැ.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = _customers[index];

                      return Card(
                        child: ListTile(
                          onTap: () {
                            _openCustomer(customer);
                          },
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.phone != null) Text(customer.phone!),
                              const SizedBox(height: 4),
                              Text(
                                customer.outstandingAmount > 0
                                    ? 'තව ලැබිය යුතු: ${_money(customer.outstandingAmount)}'
                                    : 'ලැබිය යුතු මුදලක් නැහැ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: customer.outstandingAmount > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
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
