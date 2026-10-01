class Product {
  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockLevel,
    this.categoryId,
    this.categoryName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? barcode;
  final double buyingPrice;
  final double sellingPrice;
  final double stockQuantity;
  final double lowStockLevel;
  final int? categoryId;
  final String? categoryName;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      buyingPrice: (map['buying_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      stockQuantity: (map['stock_quantity'] as num).toDouble(),
      lowStockLevel: (map['low_stock_level'] as num).toDouble(),
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
