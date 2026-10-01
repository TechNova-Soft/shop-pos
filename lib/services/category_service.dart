import '../database/database_service.dart';
import '../models/category.dart';

class CategoryService {
  CategoryService._();

  static final CategoryService instance = CategoryService._();

  Future<List<Category>> getCategories() async {
    final db = await DatabaseService.instance.database;

    final rows = await db.query(
      'categories',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Category.fromMap).toList();
  }

  Future<int> addCategory(String name) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception('වර්ගයේ නම ඇතුළත් කරන්න.');
    }

    final db = await DatabaseService.instance.database;

    try {
      return await db.insert('categories', {
        'name': cleanName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      throw Exception('මෙම වර්ගය දැනටමත් තිබේ.');
    }
  }
}
