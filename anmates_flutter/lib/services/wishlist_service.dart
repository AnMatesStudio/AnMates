import 'api_client.dart';

/// One saved food in the user's wishlist. [category] is one of the backend
/// AllowedCategories: bun, pho, com, lau, bbq, cafe, trang_mieng, other.
class WishlistItem {
  final String id;
  final String foodName;
  final String foodCategory;

  WishlistItem({
    required this.id,
    required this.foodName,
    required this.foodCategory,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> j) => WishlistItem(
    id: j['id'] as String,
    foodName: j['food_name'] as String,
    foodCategory: j['food_category'] as String? ?? 'other',
  );
}

class WishlistService {
  static final WishlistService _instance = WishlistService._();
  WishlistService._();
  factory WishlistService() => _instance;

  final _api = ApiClient();

  Future<List<WishlistItem>> list() async {
    final data = await _api.get('/api/v1/wishlist') as List;
    return data
        .map((e) => WishlistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishlistItem> add(String foodName, String category) async {
    final data =
        await _api.post(
              '/api/v1/wishlist',
              body: {'food_name': foodName, 'food_category': category},
            )
            as Map<String, dynamic>;
    return WishlistItem.fromJson(data);
  }

  Future<void> remove(String id) async {
    await _api.delete('/api/v1/wishlist/$id');
  }
}
