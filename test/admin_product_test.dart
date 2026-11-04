import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego_admin/models/admin_models.dart';

void main() {
  test('uses the listed price matching the product unit', () {
    final kiloProduct = AdminProduct.fromJson({
      'product_id': 'tomato-1',
      'product_name': 'Tomatoes',
      'unit': 'kg',
      'price_per_kg': 120,
      'price_per_piece': 15,
      'stock_quantity': 4.5,
      'is_in_stock': true,
    });
    final pieceProduct = AdminProduct.fromJson({
      'product_id': 'egg-1',
      'product_name': 'Egg',
      'unit': 'pc',
      'price_per_kg': 80,
      'price_per_piece': 12,
      'stock_quantity': 8,
      'is_in_stock': true,
    });

    expect(kiloProduct.listedPrice, 120);
    expect(kiloProduct.priceUnit, 'kg');
    expect(pieceProduct.listedPrice, 12);
    expect(pieceProduct.priceUnit, 'piece');
  });
}
