import '../models/cart_model.dart';
import 'dio_client.dart';

final class CartApi {
  const CartApi({required this.client});

  final DioClient client;

  Future<List<CartItemModel>> getCart(String userId) async {
    final response = await client.get<Map<String, dynamic>>('/cart/$userId');
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = (data['list'] as List<dynamic>?)
        ?.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [];
    return list;
  }

  Future<void> addToCart({
    required String userId,
    required String productId,
    String spec = '',
    int quantity = 1,
  }) async {
    await client.post<Map<String, dynamic>>(
      '/cart',
      data: <String, dynamic>{
        'user_id': userId,
        'product_id': productId,
        'spec': spec,
        'quantity': quantity,
      },
    );
  }

  Future<void> updateCartItem(
    String itemId, {
    int? quantity,
    int? selected,
  }) async {
    await client.put<Map<String, dynamic>>(
      '/cart/$itemId',
      data: <String, dynamic>{
        if (quantity != null) 'quantity': quantity,
        if (selected != null) 'selected': selected,
      },
    );
  }

  Future<void> deleteCartItem(String itemId) async {
    await client.delete<Map<String, dynamic>>('/cart/$itemId');
  }
}
