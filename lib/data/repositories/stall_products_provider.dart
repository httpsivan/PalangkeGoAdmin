import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stall_product.dart';
import '../mock/stall_products_mock_data.dart';

class StallProductsState {
  const StallProductsState({
    required this.products,
  });

  final List<StallProduct> products;

  List<StallProduct> forVendor(String vendorId, {String? vendorCategory}) {
    final direct = products.where((p) => p.vendorId == vendorId).toList();
    if (direct.isNotEmpty) return direct;

    if (vendorCategory != null && vendorCategory.trim().isNotEmpty) {
      final vCat = vendorCategory.trim().toLowerCase();
      final matched = products.where((p) {
        final pCat = p.category.toLowerCase();
        return pCat.contains(vCat) || vCat.contains(pCat);
      }).toList();
      if (matched.isNotEmpty) {
        return matched.map((p) => p.copyWith(vendorId: vendorId)).toList();
      }
    }

    // Fallback: Return sample subset mapped to this vendor
    return products.take(8).map((p) => p.copyWith(vendorId: vendorId)).toList();
  }

  StallProductsState copyWith({
    List<StallProduct>? products,
  }) {
    return StallProductsState(
      products: products ?? this.products,
    );
  }
}

class StallProductsController extends StateNotifier<StallProductsState> {
  StallProductsController() : super(StallProductsState(products: seedStallProducts()));

  void updateProductStockAndPrice(String productId, double stock, double price) {
    state = state.copyWith(
      products: state.products.map((p) {
        if (p.id == productId) {
          return p.copyWith(
            stockQuantity: stock,
            price: price,
          );
        }
        return p;
      }).toList(),
    );
  }

  void deleteProduct(String productId) {
    state = state.copyWith(
      products: state.products.where((p) => p.id != productId).toList(),
    );
  }

  void restoreProduct(StallProduct product, int? index) {
    final updated = List<StallProduct>.from(state.products);
    if (index != null && index >= 0 && index <= updated.length) {
      updated.insert(index, product);
    } else {
      updated.add(product);
    }
    state = state.copyWith(products: updated);
  }
}

final stallProductsProvider =
    StateNotifierProvider<StallProductsController, StallProductsState>((ref) {
  return StallProductsController();
});
