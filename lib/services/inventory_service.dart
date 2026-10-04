import '../database/database_service.dart';

class InventoryService {
  InventoryService._();

  static final InventoryService instance = InventoryService._();

  Future<void> addStock({
    required int productId,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw Exception('එකතු කරන තොග ප්‍රමාණය 0 ට වඩා වැඩි විය යුතුයි.');
    }

    await _changeStock(
      productId: productId,
      quantityChange: quantity,
      movementType: 'add',
      note: note,
    );
  }

  Future<void> removeStock({
    required int productId,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw Exception('අඩු කරන තොග ප්‍රමාණය 0 ට වඩා වැඩි විය යුතුයි.');
    }

    await _changeStock(
      productId: productId,
      quantityChange: -quantity,
      movementType: 'remove',
      note: note,
    );
  }

  Future<void> adjustStock({
    required int productId,
    required double newQuantity,
    String? note,
  }) async {
    if (newQuantity < 0) {
      throw Exception('තොගය 0 ට වඩා අඩු විය නොහැක.');
    }

    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['stock_quantity'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [productId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw Exception('භාණ්ඩය හමු නොවීය.');
      }

      final currentStock = (rows.first['stock_quantity'] as num).toDouble();

      final difference = newQuantity - currentStock;

      if (difference == 0) {
        return;
      }

      final now = DateTime.now().toIso8601String();

      await txn.update(
        'products',
        {'stock_quantity': newQuantity, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await txn.insert('stock_movements', {
        'product_id': productId,
        'movement_type': 'adjust',
        'quantity_change': difference,
        'stock_before': currentStock,
        'stock_after': newQuantity,
        'reference_type': 'manual',
        'reference_id': null,
        'note': note?.trim(),
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, dynamic>>> getStockHistory(int productId) async {
    final db = await DatabaseService.instance.database;

    return db.rawQuery(
      '''
      SELECT
        sm.id,
        sm.product_id,
        sm.movement_type,
        sm.quantity_change,
        sm.stock_before,
        sm.stock_after,
        sm.reference_type,
        sm.reference_id,
        sm.note,
        sm.created_at,
        p.name AS product_name
      FROM stock_movements sm
      INNER JOIN products p
        ON p.id = sm.product_id
      WHERE sm.product_id = ?
      ORDER BY sm.created_at DESC, sm.id DESC
      ''',
      [productId],
    );
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await DatabaseService.instance.database;

    return db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.stock_quantity,
        p.low_stock_level,
        c.name AS category_name
      FROM products p
      LEFT JOIN categories c
        ON c.id = p.category_id
      WHERE p.is_active = 1
        AND p.stock_quantity <= p.low_stock_level
      ORDER BY p.stock_quantity ASC, p.name COLLATE NOCASE ASC
      ''');
  }

  Future<void> _changeStock({
    required int productId,
    required double quantityChange,
    required String movementType,
    String? note,
  }) async {
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['stock_quantity'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [productId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw Exception('භාණ්ඩය හමු නොවීය.');
      }

      final currentStock = (rows.first['stock_quantity'] as num).toDouble();

      final newStock = currentStock + quantityChange;

      if (newStock < 0) {
        throw Exception(
          'ප්‍රමාණවත් තොගයක් නැහැ. වර්තමාන තොගය: '
          '${_formatQuantity(currentStock)}',
        );
      }

      final now = DateTime.now().toIso8601String();

      await txn.update(
        'products',
        {'stock_quantity': newStock, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await txn.insert('stock_movements', {
        'product_id': productId,
        'movement_type': movementType,
        'quantity_change': quantityChange,
        'stock_before': currentStock,
        'stock_after': newStock,
        'reference_type': 'manual',
        'reference_id': null,
        'note': note?.trim(),
        'created_at': now,
      });
    });
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}
