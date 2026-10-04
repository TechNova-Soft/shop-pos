import '../database/database_service.dart';
import '../models/cart_item.dart';

class PosService {
  PosService._();

  static final PosService instance = PosService._();

  Future<String> completeSale({
    required List<CartItem> items,
    required double discount,
    required String paymentMethod,
    required double paidAmount,
    int? customerId,
  }) async {
    if (items.isEmpty) {
      throw Exception('කරත්තයට භාණ්ඩ එකතු කරන්න.');
    }

    final db = await DatabaseService.instance.database;

    return db.transaction<String>((txn) async {
      double subtotal = 0;

      for (final cartItem in items) {
        if (cartItem.quantity <= 0) {
          throw Exception('නිවැරදි භාණ්ඩ ප්‍රමාණයක් ඇතුළත් කරන්න.');
        }

        final rows = await txn.query(
          'products',
          columns: [
            'id',
            'name',
            'buying_price',
            'selling_price',
            'stock_quantity',
            'is_active',
          ],
          where: 'id = ?',
          whereArgs: [cartItem.product.id],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw Exception('${cartItem.product.name} භාණ්ඩය හමු නොවීය.');
        }

        final product = rows.first;

        if ((product['is_active'] as int) != 1) {
          throw Exception('${cartItem.product.name} භාණ්ඩය විකිණීමට නොහැක.');
        }

        final stock = (product['stock_quantity'] as num).toDouble();

        if (cartItem.quantity > stock) {
          throw Exception(
            '${cartItem.product.name} සඳහා ප්‍රමාණවත් තොගයක් නැහැ. '
            'වර්තමාන තොගය: ${_formatQuantity(stock)}',
          );
        }

        final sellingPrice = (product['selling_price'] as num).toDouble();

        subtotal += sellingPrice * cartItem.quantity;
      }

      if (discount < 0 || discount > subtotal) {
        throw Exception('වට්ටම නිවැරදිව ඇතුළත් කරන්න.');
      }

      final total = subtotal - discount;

      if (total <= 0) {
        throw Exception('විකුණුම් මුදල 0 ට වඩා වැඩි විය යුතුයි.');
      }

      double finalPaidAmount;
      double dueAmount;
      String paymentStatus;

      switch (paymentMethod) {
        case 'cash':
          finalPaidAmount = total;
          dueAmount = 0;
          paymentStatus = 'paid';
          break;

        case 'credit':
          finalPaidAmount = 0;
          dueAmount = total;
          paymentStatus = 'unpaid';
          break;

        case 'partial':
          if (paidAmount <= 0 || paidAmount >= total) {
            throw Exception(
              'කොටසක් ගෙවීම සඳහා මුළු මුදලට වඩා අඩු මුදලක් ඇතුළත් කරන්න.',
            );
          }

          finalPaidAmount = paidAmount;
          dueAmount = total - paidAmount;
          paymentStatus = 'partial';
          break;

        default:
          throw Exception('ගෙවීම් ක්‍රමය නිවැරදි නැහැ.');
      }

      if (dueAmount > 0 && customerId == null) {
        throw Exception(
          'ණයට හෝ කොටසක් ගෙවා විකිණීමක් සඳහා පාරිභෝගිකයෙකු තෝරන්න.',
        );
      }

      if (customerId != null) {
        final customerRows = await txn.query(
          'customers',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );

        if (customerRows.isEmpty) {
          throw Exception('තෝරාගත් පාරිභෝගිකයා හමු නොවීය.');
        }
      }

      final invoiceNo = _generateInvoiceNumber();
      final now = DateTime.now().toIso8601String();

      final saleId = await txn.insert('sales', {
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paid_amount': finalPaidAmount,
        'due_amount': dueAmount,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'created_at': now,
      });

      for (final cartItem in items) {
        final rows = await txn.query(
          'products',
          columns: ['name', 'buying_price', 'selling_price', 'stock_quantity'],
          where: 'id = ?',
          whereArgs: [cartItem.product.id],
          limit: 1,
        );

        final product = rows.first;

        final currentStock = (product['stock_quantity'] as num).toDouble();

        final buyingPrice = (product['buying_price'] as num).toDouble();

        final sellingPrice = (product['selling_price'] as num).toDouble();

        final quantity = cartItem.quantity;
        final itemSubtotal = sellingPrice * quantity;
        final itemProfit = (sellingPrice - buyingPrice) * quantity;

        final newStock = currentStock - quantity;

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': cartItem.product.id,
          'product_name': product['name'],
          'quantity': quantity,
          'unit_cost': buyingPrice,
          'unit_price': sellingPrice,
          'subtotal': itemSubtotal,
          'profit': itemProfit,
        });

        await txn.update(
          'products',
          {'stock_quantity': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [cartItem.product.id],
        );

        await txn.insert('stock_movements', {
          'product_id': cartItem.product.id,
          'movement_type': 'sale',
          'quantity_change': -quantity,
          'stock_before': currentStock,
          'stock_after': newStock,
          'reference_type': 'sale',
          'reference_id': saleId,
          'note': 'විකුණුම - $invoiceNo',
          'created_at': now,
        });
      }

      return invoiceNo;
    });
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();

    return 'INV-${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}
