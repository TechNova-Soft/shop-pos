import '../database/database_service.dart';
import '../models/customer.dart';

class CustomerService {
  CustomerService._();

  static final CustomerService instance = CustomerService._();

  Future<List<Customer>> getCustomers({String search = ''}) async {
    final db = await DatabaseService.instance.database;

    final cleanSearch = search.trim();

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (cleanSearch.isNotEmpty) {
      whereParts.add('(c.name LIKE ? OR c.phone LIKE ?)');

      final searchValue = '%$cleanSearch%';

      whereArgs
        ..add(searchValue)
        ..add(searchValue);
    }

    final whereClause = whereParts.isEmpty
        ? ''
        : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.phone,
        c.address,
        c.note,
        c.created_at,
        c.updated_at,
        COALESCE(
          (
            SELECT SUM(s.due_amount)
            FROM sales s
            WHERE s.customer_id = c.id
          ),
          0
        )
        -
        COALESCE(
          (
            SELECT SUM(cp.amount)
            FROM credit_payments cp
            WHERE cp.customer_id = c.id
          ),
          0
        ) AS outstanding_amount
      FROM customers c
      $whereClause
      ORDER BY c.name COLLATE NOCASE ASC
      ''', whereArgs);

    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await DatabaseService.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id,
        c.name,
        c.phone,
        c.address,
        c.note,
        c.created_at,
        c.updated_at,
        COALESCE(
          (
            SELECT SUM(s.due_amount)
            FROM sales s
            WHERE s.customer_id = c.id
          ),
          0
        )
        -
        COALESCE(
          (
            SELECT SUM(cp.amount)
            FROM credit_payments cp
            WHERE cp.customer_id = c.id
          ),
          0
        ) AS outstanding_amount
      FROM customers c
      WHERE c.id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (rows.isEmpty) {
      return null;
    }

    return Customer.fromMap(rows.first);
  }

  Future<int> addCustomer({
    required String name,
    String? phone,
    String? address,
    String? note,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception('පාරිභෝගිකයාගේ නම ඇතුළත් කරන්න.');
    }

    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    return db.insert('customers', {
      'name': cleanName,
      'phone': _nullable(phone),
      'address': _nullable(address),
      'note': _nullable(note),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateCustomer({
    required int id,
    required String name,
    String? phone,
    String? address,
    String? note,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception('පාරිභෝගිකයාගේ නම ඇතුළත් කරන්න.');
    }

    final db = await DatabaseService.instance.database;

    await db.update(
      'customers',
      {
        'name': cleanName,
        'phone': _nullable(phone),
        'address': _nullable(address),
        'note': _nullable(note),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addPayment({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) {
      throw Exception('ගෙවන මුදල 0 ට වඩා වැඩි විය යුතුයි.');
    }

    final customer = await getCustomerById(customerId);

    if (customer == null) {
      throw Exception('පාරිභෝගිකයා හමු නොවීය.');
    }

    if (customer.outstandingAmount <= 0) {
      throw Exception('මෙම පාරිභෝගිකයාගෙන් තව මුදලක් ලැබීමට නැහැ.');
    }

    if (amount > customer.outstandingAmount) {
      throw Exception(
        'ගෙවීම ලැබිය යුතු මුදලට වඩා වැඩියි. '
        'ලැබිය යුතු මුදල: '
        'රු. ${customer.outstandingAmount.toStringAsFixed(2)}',
      );
    }

    final db = await DatabaseService.instance.database;

    await db.insert('credit_payments', {
      'customer_id': customerId,
      'sale_id': null,
      'amount': amount,
      'payment_method': 'cash',
      'note': _nullable(note),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getCreditSales(int customerId) async {
    final db = await DatabaseService.instance.database;

    return db.query(
      'sales',
      columns: [
        'id',
        'invoice_no',
        'total',
        'paid_amount',
        'due_amount',
        'payment_method',
        'payment_status',
        'created_at',
      ],
      where: 'customer_id = ? AND due_amount > 0',
      whereArgs: [customerId],
      orderBy: 'created_at DESC, id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPayments(int customerId) async {
    final db = await DatabaseService.instance.database;

    return db.query(
      'credit_payments',
      columns: [
        'id',
        'sale_id',
        'amount',
        'payment_method',
        'note',
        'created_at',
      ],
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC, id DESC',
    );
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
