import 'package:sqflite_common/sqlite_api.dart';

import '../database/database_service.dart';
import '../models/product.dart';

class ProductService {
  ProductService._();

  static final ProductService instance = ProductService._();

  Future<List<Product>> getProducts({String search = ''}) async {
    final db = await DatabaseService.instance.database;

    final cleanSearch = search.trim();

    final whereParts = <String>['p.is_active = 1'];

    final whereArgs = <Object?>[];

    if (cleanSearch.isNotEmpty) {
      whereParts.add('(p.name LIKE ? OR p.barcode LIKE ?)');

      final searchValue = '%$cleanSearch%';

      whereArgs
        ..add(searchValue)
        ..add(searchValue);
    }

    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.barcode,
        p.buying_price,
        p.selling_price,
        p.stock_quantity,
        p.low_stock_level,
        p.category_id,
        c.name AS category_name,
        p.is_active,
        p.created_at,
        p.updated_at
      FROM products p
      LEFT JOIN categories c
        ON c.id = p.category_id
      WHERE ${whereParts.join(' AND ')}
      ORDER BY p.name COLLATE NOCASE ASC
      ''', whereArgs);

    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await DatabaseService.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        p.id,
        p.name,
        p.barcode,
        p.buying_price,
        p.selling_price,
        p.stock_quantity,
        p.low_stock_level,
        p.category_id,
        c.name AS category_name,
        p.is_active,
        p.created_at,
        p.updated_at
      FROM products p
      LEFT JOIN categories c
        ON c.id = p.category_id
      WHERE p.id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (rows.isEmpty) {
      return null;
    }

    return Product.fromMap(rows.first);
  }

  Future<int> addProduct({
    required String name,
    String? barcode,
    required double buyingPrice,
    required double sellingPrice,
    required double initialStock,
    required double lowStockLevel,
    int? categoryId,
    required List<double> quickQuantities,
  }) async {
    final db = await DatabaseService.instance.database;

    return db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();

      final productId = await txn.insert('products', {
        'name': name.trim(),
        'barcode': _nullable(barcode),
        'buying_price': buyingPrice,
        'selling_price': sellingPrice,
        'stock_quantity': initialStock,
        'low_stock_level': lowStockLevel,
        'category_id': categoryId,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      if (initialStock > 0) {
        await txn.insert('stock_movements', {
          'product_id': productId,
          'movement_type': 'initial',
          'quantity_change': initialStock,
          'stock_before': 0,
          'stock_after': initialStock,
          'reference_type': 'product',
          'reference_id': productId,
          'note': 'ආරම්භක තොගය',
          'created_at': now,
        });
      }

      await _saveQuickQuantities(txn, productId, quickQuantities);

      return productId;
    });
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    String? barcode,
    required double buyingPrice,
    required double sellingPrice,
    required double lowStockLevel,
    int? categoryId,
    required List<double> quickQuantities,
  }) async {
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      await txn.update(
        'products',
        {
          'name': name.trim(),
          'barcode': _nullable(barcode),
          'buying_price': buyingPrice,
          'selling_price': sellingPrice,
          'low_stock_level': lowStockLevel,
          'category_id': categoryId,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'quick_quantities',
        where: 'product_id = ?',
        whereArgs: [id],
      );

      await _saveQuickQuantities(txn, id, quickQuantities);
    });
  }

  Future<void> deleteProduct(int id) async {
    final db = await DatabaseService.instance.database;

    await db.update(
      'products',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<double>> getQuickQuantities(int productId) async {
    final db = await DatabaseService.instance.database;

    final rows = await db.query(
      'quick_quantities',
      columns: ['quantity'],
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'sort_order ASC',
    );

    return rows.map((row) => (row['quantity'] as num).toDouble()).toList();
  }

  Future<void> _saveQuickQuantities(
    DatabaseExecutor txn,
    int productId,
    List<double> quantities,
  ) async {
    for (var index = 0; index < quantities.length; index++) {
      await txn.insert('quick_quantities', {
        'product_id': productId,
        'quantity': quantities[index],
        'sort_order': index,
      });
    }
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
