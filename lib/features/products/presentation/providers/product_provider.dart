
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';

// ─────────────────────────────────────────────────────────────
// State class สำหรับ pagination
// ─────────────────────────────────────────────────────────────
class ProductListState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
  // Pagination
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  const ProductListState({
    required this.products,
    required this.isLoading,
    this.error,
    this.total = 0,
    this.limit = 500,
    this.offset = 0,
    this.hasMore = false,
  });

  ProductListState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? error,
    int? total,
    int? limit,
    int? offset,
    bool? hasMore,
  }) {
    return ProductListState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────
final productListProvider =
    AsyncNotifierProvider<ProductListNotifier, List<ProductModel>>(
      ProductListNotifier.new,
    );

class ProductListNotifier extends AsyncNotifier<List<ProductModel>> {
  // เก็บ pagination state แยกต่างหาก
  int _total = 0;
  int _limit = 500;
  int _offset = 0;
  bool _hasMore = false;

  int get total => _total;
  int get limit => _limit;
  bool get hasMore => _hasMore;

  @override
  Future<List<ProductModel>> build() async {
    // ✅ รอจนกว่า token restore เสร็จก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) {
      return []; // คืน list ว่าง รอ rebuild เมื่อ auth พร้อม
    }
    return await loadProducts();
  }

  /// โหลดรายการสินค้า (รองรับ pagination + server-side search)
  Future<List<ProductModel>> loadProducts({
    int limit = 500,
    int offset = 0,
    String search = '',
    bool activeOnly = false,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading products (limit=$limit offset=$offset search="$search")...');
      }

      final apiClient = ref.read(apiClientProvider);

      // ✅ ส่ง params ไปให้ server filter — ไม่โหลดทั้งหมดมา filter ใน Dart
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (search.isNotEmpty) 'search': search,
        if (activeOnly) 'active_only': 'true',
      };

      // ✅ สร้าง URL พร้อม query string เอง เพราะ ApiClient.get() ไม่รับ queryParameters
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final path = queryString.isEmpty
          ? '/api/products'
          : '/api/products?$queryString';

      final response = await apiClient.get(path);

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final products = data
            .map((json) => ProductModel.fromJson(json))
            .toList();

        // บันทึก pagination info
        final pagination =
            response.data['pagination'] as Map<String, dynamic>? ?? {};
        _total = pagination['total'] as int? ?? products.length;
        _limit = limit;
        _offset = offset;
        _hasMore = pagination['has_more'] as bool? ?? false;

        if (kDebugMode) {
          debugPrint('✅ Loaded ${products.length} / $_total products');
        }
        return products;
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading products: $e');
      }
      rethrow;
    }
  }

  /// Refresh — โหลดใหม่จากต้น
  Future<void> refresh({String search = '', bool activeOnly = false}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => loadProducts(
        limit: _limit,
        offset: 0,
        search: search,
        activeOnly: activeOnly,
      ),
    );
  }

  /// โหลดหน้าถัดไป (infinite scroll)
  Future<void> loadMore({String search = '', bool activeOnly = false}) async {
    if (!_hasMore) return;
    final current = state.value ?? [];
    final next = await loadProducts(
      limit: _limit,
      offset: _offset + _limit,
      search: search,
      activeOnly: activeOnly,
    );
    state = AsyncValue.data([...current, ...next]);
  }

  /// เพิ่มสินค้า
  Future<bool> addProduct(Map<String, dynamic> productData) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/products', data: productData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await refresh();
        ref.invalidate(stockBalanceProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error adding product: $e');
      }
      return false;
    }
  }

  /// แก้ไขสินค้า
  Future<bool> updateProduct(
    String productId,
    Map<String, dynamic> productData,
  ) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/products/$productId',
        data: productData,
      );

      if (response.statusCode == 200) {
        await refresh();
        ref.invalidate(stockBalanceProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating product: $e');
      }
      return false;
    }
  }

  /// ตรวจก่อนลบ — คืน {has_history, has_sales, sales_count, has_movements, movement_count}
  Future<Map<String, dynamic>> checkDeleteProduct(String productId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/products/$productId/check-delete');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking product delete: $e');
      }
      return {'success': false, 'message': '$e'};
    }
  }

  /// ลบสินค้า (Soft Delete) — คืนค่า message จาก server หรือ null ถ้าเกิดข้อผิดพลาด
  Future<String?> deleteProduct(String productId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/products/$productId');

      if (response.statusCode == 200) {
        await refresh();
        final data = response.data is Map ? response.data as Map : {};
        return data['message'] as String? ?? 'ดำเนินการสำเร็จ';
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting product: $e');
      }
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// ProductGroupModel
// ─────────────────────────────────────────────────────────────
class ProductGroupModel {
  final String groupId;
  final String groupCode;
  final String groupName;
  final String? groupType;
  final String? imageUrl;
  final String? mobileColor;
  final String? mobileIcon;
  final bool showInPos;
  final int displayOrder;

  const ProductGroupModel({
    required this.groupId,
    required this.groupCode,
    required this.groupName,
    this.groupType,
    this.imageUrl,
    this.mobileColor,
    this.mobileIcon,
    this.showInPos = true,
    this.displayOrder = 0,
  });

  factory ProductGroupModel.fromJson(Map<String, dynamic> json) =>
      ProductGroupModel(
        groupId: json['group_id'] as String,
        groupCode: json['group_code'] as String,
        groupName: json['group_name'] as String,
        groupType: json['group_type'] as String?,
        imageUrl: json['image_url'] as String?,
        mobileColor: json['mobile_color'] as String?,
        mobileIcon: json['mobile_icon'] as String?,
        showInPos: json['show_in_pos'] as bool? ?? true,
        displayOrder: json['display_order'] as int? ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────
// productGroupsProvider — ดึง product groups ทั้งหมด
// ─────────────────────────────────────────────────────────────
final productGroupsProvider = FutureProvider<List<ProductGroupModel>>((
  ref,
) async {
  try {
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/products/groups');
    if (res.statusCode == 200 && res.data != null) {
      final list = res.data['data'] as List;
      return list
          .map((j) => ProductGroupModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading product groups: $e');
    }
    return [];
  }
});

final productGroupRepositoryProvider = Provider<ProductGroupRepository>((ref) {
  return ProductGroupRepository(ref);
});

class ProductGroupRepository {
  final Ref ref;

  ProductGroupRepository(this.ref);

  Future<bool> createGroup(Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/products/groups', data: payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        ref.invalidate(productGroupsProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating product group: $e');
      }
      return false;
    }
  }

  Future<bool> updateGroup(String groupId, Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put('/api/products/groups/$groupId', data: payload);
      if (res.statusCode == 200) {
        ref.invalidate(productGroupsProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating product group: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> checkDeleteGroup(String groupId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/products/groups/$groupId/check-delete');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking product group delete: $e');
      }
      return {'success': false, 'message': '$e'};
    }
  }

  Future<String?> deleteGroup(String groupId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.delete('/api/products/groups/$groupId');
      if (res.statusCode == 200) {
        ref.invalidate(productGroupsProvider);
        return (res.data as Map?)?['message'] as String? ??
            'ลบหมวดสินค้าสำเร็จ';
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting product group: $e');
      }
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// topSellingProductRankProvider
// คืน Map<productId, rank> โดย rank=1 คือขายดีที่สุด
// ─────────────────────────────────────────────────────────────
final topSellingProductRankProvider =
    FutureProvider<Map<String, int>>((ref) async {
  try {
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return {};
    final api = ref.read(apiClientProvider);
    final res = await api.get(
      '/api/reports/top-products',
      queryParameters: {'limit': 500},
    );
    if (res.statusCode == 200 && res.data != null) {
      final list = res.data['data'] as List? ?? [];
      final Map<String, int> rank = {};
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final id = item['product_id'] as String?;
        if (id != null) rank[id] = i + 1;
      }
      return rank;
    }
    return {};
  } catch (_) {
    return {};
  }
});
