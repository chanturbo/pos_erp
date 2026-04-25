import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/modifier_model.dart';

// ── All modifier groups (for management page) ─────────────────────
final modifierGroupsProvider =
    AsyncNotifierProvider<ModifierGroupsNotifier, List<ModifierGroupModel>>(
        ModifierGroupsNotifier.new);

class ModifierGroupsNotifier
    extends AsyncNotifier<List<ModifierGroupModel>> {
  @override
  Future<List<ModifierGroupModel>> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return [];
    return _fetch();
  }

  Future<List<ModifierGroupModel>> _fetch() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/modifiers/groups');
    if (res.statusCode == 200) {
      final list = res.data['data'] as List;
      return list
          .map((j) => ModifierGroupModel.fromJson(
              Map<String, dynamic>.from(j as Map)))
          .toList();
    }
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<bool> createGroup(Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.post('/api/modifiers/groups', data: payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ createGroup: $e');
      return false;
    }
  }

  Future<bool> updateGroup(
      String groupId, Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
          '/api/modifiers/groups/$groupId', data: payload);
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ updateGroup: $e');
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.delete('/api/modifiers/groups/$groupId');
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ deleteGroup: $e');
      return false;
    }
  }

  Future<bool> createOption(
      String groupId, Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
          '/api/modifiers/groups/$groupId/options',
          data: payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ createOption: $e');
      return false;
    }
  }

  Future<bool> updateOption(
      String optionId, Map<String, dynamic> payload) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
          '/api/modifiers/options/$optionId', data: payload);
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ updateOption: $e');
      return false;
    }
  }

  Future<bool> deleteOption(String optionId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.delete('/api/modifiers/options/$optionId');
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ deleteOption: $e');
      return false;
    }
  }

  Future<bool> linkGroup(String productId, String groupId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api
          .post('/api/modifiers/by-product/$productId/$groupId');
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ linkGroup: $e');
      return false;
    }
  }

  Future<bool> unlinkGroup(String productId, String groupId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api
          .delete('/api/modifiers/by-product/$productId/$groupId');
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ unlinkGroup: $e');
      return false;
    }
  }
}

// ── Modifier groups for a specific product (used by POS picker) ───
final productModifierGroupsProvider = FutureProvider.family
    .autoDispose<List<ModifierGroupModel>, String>((ref, productId) async {
  final auth = ref.watch(authProvider);
  if (auth.isRestoring || !auth.isAuthenticated) return [];
  try {
    final api = ref.read(apiClientProvider);
    final res =
        await api.get('/api/modifiers/by-product/$productId');
    if (res.statusCode == 200) {
      final list = res.data['data'] as List;
      return list
          .map((j) => ModifierGroupModel.fromJson(
              Map<String, dynamic>.from(j as Map)))
          .toList();
    }
    return [];
  } catch (e) {
    if (kDebugMode) debugPrint('❌ productModifiers($productId): $e');
    return [];
  }
});

// ── Product's linked group IDs (for product form checkboxes) ──────
final productLinkedGroupIdsProvider = FutureProvider.family
    .autoDispose<Set<String>, String>((ref, productId) async {
  final groups =
      await ref.watch(productModifierGroupsProvider(productId).future);
  return groups.map((g) => g.modifierGroupId).toSet();
});
