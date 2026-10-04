import 'package:flutter/material.dart';

import '../../models/sale_record.dart';
import '../../models/sales_summary.dart';
import '../../services/reports_service.dart';

enum ReportPeriod { today, thisWeek, thisMonth, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  DateTimeRange? _customRange;

  SalesSummary? _summary;
  List<SaleRecord> _sales = [];

  bool _isLoading = true;

  DateTimeRange _todayRange() {
    final now = DateTime.now();

    final start = DateTime(now.year, now.month, now.day);

    return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
  }

  DateTimeRange _thisWeekRange() {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final daysFromMonday = today.weekday - DateTime.monday;

    final start = today.subtract(Duration(days: daysFromMonday));

    return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
  }

  DateTimeRange _thisMonthRange() {
    final now = DateTime.now();

    final start = DateTime(now.year, now.month);

    final end = now.month == 12
        ? DateTime(now.year + 1)
        : DateTime(now.year, now.month + 1);

    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange get _currentRange {
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        return _todayRange();

      case ReportPeriod.thisWeek:
        return _thisWeekRange();

      case ReportPeriod.thisMonth:
        return _thisMonthRange();

      case ReportPeriod.custom:
        return _customRange ?? _todayRange();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final range = _currentRange;

      final summary = await ReportsService.instance.getSummary(
        start: range.start,
        end: range.end,
      );

      final sales = await ReportsService.instance.getSales(
        start: range.start,
        end: range.end,
      );

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _sales = sales;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('වාර්තා ලබා ගැනීමට නොහැකි විය.');
    }
  }

  Future<void> _selectPeriod(ReportPeriod? period) async {
    if (period == null) {
      return;
    }

    if (period == ReportPeriod.custom) {
      final selectedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customRange,
      );

      if (selectedRange == null) {
        return;
      }

      final endExclusive = DateTime(
        selectedRange.end.year,
        selectedRange.end.month,
        selectedRange.end.day + 1,
      );

      setState(() {
        _selectedPeriod = period;
        _customRange = DateTimeRange(
          start: selectedRange.start,
          end: endExclusive,
        );
      });
    } else {
      setState(() {
        _selectedPeriod = period;
      });
    }

    await _loadReport();
  }

  String _periodLabel() {
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        return 'අද';

      case ReportPeriod.thisWeek:
        return 'මෙම සතිය';

      case ReportPeriod.thisMonth:
        return 'මෙම මාසය';

      case ReportPeriod.custom:
        final range = _currentRange;

        final end = range.end.subtract(const Duration(days: 1));

        return '${_formatDate(range.start)} - '
            '${_formatDate(end)}';
    }
  }

  Future<void> _openSale(SaleRecord sale) async {
    final items = await ReportsService.instance.getSaleItems(sale.id);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('බිල් අංකය: ${sale.invoiceNo}'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sale.customerName == null
                        ? 'පාරිභෝගිකයා: නැහැ'
                        : 'පාරිභෝගිකයා: '
                              '${sale.customerName}',
                  ),
                  const SizedBox(height: 8),
                  Text('දිනය: ${_formatDateTime(sale.createdAt)}'),
                  const Divider(height: 24),
                  ...items.map((item) {
                    final quantity = (item['quantity'] as num).toDouble();

                    final subtotal = (item['subtotal'] as num).toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['product_name']} '
                              '× ${_formatQuantity(quantity)}',
                            ),
                          ),
                          Text(
                            'රු. '
                            '${subtotal.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  _summaryRow('මුළු එකතුව', _money(sale.total)),
                  _summaryRow('ගෙවා ඇති මුදල', _money(sale.paidAmount)),
                  if (sale.dueAmount > 0)
                    _summaryRow('තව ගෙවීමට ඇති මුදල', _money(sale.dueAmount)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('වසන්න'),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _paymentLabel(String value) {
    switch (value) {
      case 'cash':
        return 'මුදලින්';

      case 'credit':
        return 'ණයට';

      case 'partial':
        return 'කොටසක් ගෙවා';

      default:
        return value;
    }
  }

  String _money(double value) {
    return 'රු. ${value.toStringAsFixed(2)}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _reportCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 30),
              const SizedBox(width: 14),
            ],
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReports() {
    final summary = _summary;

    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _reportCard(
          title: 'මුළු විකුණුම්',
          value: _money(summary.totalSales),
          icon: Icons.point_of_sale_outlined,
        ),
        _reportCard(
          title: 'ලැබුණු මුදල',
          value: _money(summary.totalPaid),
          icon: Icons.payments_outlined,
        ),
        _reportCard(
          title: 'නයට දුන් මුදල',
          value: _money(summary.totalDue),
          icon: Icons.credit_card_outlined,
        ),
        _reportCard(
          title: 'ඇස්තමේන්තුගත ලාභය',
          value: _money(summary.totalProfit),
          icon: Icons.trending_up,
        ),
        _reportCard(
          title: 'වට්ටම්',
          value: _money(summary.totalDiscount),
          icon: Icons.discount_outlined,
        ),
        _reportCard(
          title: 'විකුණුම් ගණන',
          value: summary.transactionCount.toString(),
          icon: Icons.receipt_long_outlined,
        ),
        _reportCard(
          title: 'විකුණු භාණ්ඩ ප්‍රමාණය',
          value: _formatQuantity(summary.itemsSold),
          icon: Icons.inventory_2_outlined,
        ),
        _reportCard(
          title: 'දැනට ලැබිය යුතු මුළු නය',
          value: _money(summary.outstandingCredit),
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _buildSalesHistory() {
    if (_sales.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('මෙම කාලයට විකුණුම් නැහැ.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Text(
          'විකුණුම් ඉතිහාසය',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._sales.map((sale) {
          return Card(
            child: ListTile(
              onTap: () => _openSale(sale),
              title: Text(
                sale.invoiceNo,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${sale.customerName ?? 'පාරිභෝගිකයෙකු නැහැ'}\n'
                '${_formatDateTime(sale.createdAt)}'
                '  •  '
                '${_paymentLabel(sale.paymentMethod)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (sale.dueAmount > 0)
                    Text(
                      'තව: ${_money(sale.dueAmount)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('වාර්තා')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<ReportPeriod>(
                    initialValue: _selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'වාර්තා කාලය',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ReportPeriod.today,
                        child: Text('අද'),
                      ),
                      DropdownMenuItem(
                        value: ReportPeriod.thisWeek,
                        child: Text('මෙම සතිය'),
                      ),
                      DropdownMenuItem(
                        value: ReportPeriod.thisMonth,
                        child: Text('මෙම මාසය'),
                      ),
                      DropdownMenuItem(
                        value: ReportPeriod.custom,
                        child: Text('වෙනත් දින'),
                      ),
                    ],
                    onChanged: _selectPeriod,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _periodLabel(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReports(),
                  _buildSalesHistory(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
