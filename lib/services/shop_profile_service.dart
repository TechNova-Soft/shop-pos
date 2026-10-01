import '../database/database_service.dart';

class ShopProfileService {
  ShopProfileService._();

  static final ShopProfileService instance = ShopProfileService._();

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await DatabaseService.instance.database;

    final result = await db.query(
      'shop_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<bool> hasProfile() async {
    final profile = await getProfile();
    return profile != null;
  }

  Future<void> saveProfile({
    required String shopName,
    String? phone,
    String? address,
    String? receiptFooter,
  }) async {
    final db = await DatabaseService.instance.database;

    final existing = await getProfile();
    final now = DateTime.now().toIso8601String();

    final data = <String, Object?>{
      'shop_name': shopName.trim(),
      'phone': _nullableValue(phone),
      'address': _nullableValue(address),
      'receipt_footer': _nullableValue(receiptFooter),
      'updated_at': now,
    };

    if (existing == null) {
      await db.insert('shop_profile', {'id': 1, ...data, 'created_at': now});
    } else {
      await db.update('shop_profile', data, where: 'id = ?', whereArgs: [1]);
    }
  }

  String? _nullableValue(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
