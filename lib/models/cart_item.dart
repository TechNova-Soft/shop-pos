import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final double quantity;

  double get subtotal => product.sellingPrice * quantity;

  CartItem copyWith({Product? product, double? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
