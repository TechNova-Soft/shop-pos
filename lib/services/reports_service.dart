import '../database/database_service.dart';
import '../models/sale_record.dart';
import '../models/sales_summary.dart';

class ReportsService {
  ReportsService._();

  static final ReportsService instance = ReportsService._();

  Future<SalesSummary> getSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await DatabaseService.instance.database;

    final startValue = start.toIso8601String();
    final endValue = end.toIso8601String();

    final saleSummary = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0) AS total_sales,
        COALESCE(SUM(paid_amount), 0) AS total_paid,
        COALESCE(SUM(due_amount), 0) AS total_due,
        COALESCE(SUM(discount), 0) AS total_discount,
        COUNT(*) AS transaction_count
      FROM sales
      WHERE created_at >= ?
        AND created_at < ?
      ''',
      [startValue, endValue],
    );

    final itemSummary = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(si.quantity), 0) AS items_sold,
        COALESCE(SUM(si.profit), 0) AS total_profit
      FROM sale_items si
      INNER JOIN sales s
        ON s.id = si.sale_id
      WHERE s.created_at >= ?
        AND s.created_at < ?
      ''',
      [startValue, endValue],
    );

    final outstandingResult = await db.rawQuery('''
      SELECT
        COALESCE(
          (
            SELECT SUM(due_amount)
            FROM sales
            WHERE due_amount > 0
          ),
          0
        )
        -
        COALESCE(
          (
            SELECT SUM(amount)
            FROM credit_payments
          ),
          0
        ) AS outstanding_credit
      ''');

    final sale = saleSummary.first;
    final item = itemSummary.first;

    return SalesSummary(
      totalSales: (sale['total_sales'] as num).toDouble(),
      totalPaid: (sale['total_paid'] as num).toDouble(),
      totalDue: (sale['total_due'] as num).toDouble(),
      totalDiscount: (sale['total_discount'] as num).toDouble(),
      transactionCount: (sale['transaction_count'] as num).toInt(),
      itemsSold: (item['items_sold'] as num).toDouble(),
      totalProfit: (item['total_profit'] as num).toDouble(),
      outstandingCredit: (outstandingResult.first['outstanding_credit'] as num)
          .toDouble(),
    );
  }

  Future<List<SaleRecord>> getSales({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await DatabaseService.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        s.id,
        s.invoice_no,
        c.name AS customer_name,
        s.total,
        s.paid_amount,
        s.due_amount,
        s.payment_method,
        s.payment_status,
        s.created_at
      FROM sales s
      LEFT JOIN customers c
        ON c.id = s.customer_id
      WHERE s.created_at >= ?
        AND s.created_at < ?
      ORDER BY s.created_at DESC, s.id DESC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return rows.map(SaleRecord.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await DatabaseService.instance.database;

    return db.query(
      'sale_items',
      columns: [
        'id',
        'product_id',
        'product_name',
        'quantity',
        'unit_cost',
        'unit_price',
        'subtotal',
        'profit',
      ],
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
  }
}
