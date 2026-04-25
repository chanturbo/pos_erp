import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/app_database.dart';

class ModifierRoutes {
  final AppDatabase db;
  ModifierRoutes(this.db);

  static final _json = {'Content-Type': 'application/json'};

  Response _ok(Object data) =>
      Response.ok(jsonEncode({'success': true, 'data': data}), headers: _json);

  Response _err(String msg, {int status = 400}) => Response(
        status,
        body: jsonEncode({'success': false, 'message': msg}),
        headers: _json,
      );

  Router get router {
    final r = Router();

    // ── Modifier Groups ───────────────────────────────────────
    r.get('/groups', _listGroups);
    r.post('/groups', _createGroup);
    r.put('/groups/<id>', _updateGroup);
    r.delete('/groups/<id>', _deleteGroup);

    // ── Modifier Options ──────────────────────────────────────
    r.get('/groups/<id>/options', _listOptions);
    r.post('/groups/<id>/options', _createOption);
    r.put('/options/<optId>', _updateOption);
    r.delete('/options/<optId>', _deleteOption);

    // ── Product ↔ Group links ─────────────────────────────────
    r.get('/by-product/<productId>', _listByProduct);
    r.post('/by-product/<productId>/<groupId>', _linkGroup);
    r.delete('/by-product/<productId>/<groupId>', _unlinkGroup);

    return r;
  }

  // ── helpers ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _groupsWithOptions(
      List<ModifierGroup> groups) async {
    final result = <Map<String, dynamic>>[];
    for (final g in groups) {
      final opts = await (db.select(db.modifiers)
            ..where((o) => o.modifierGroupId.equals(g.modifierGroupId))
            ..orderBy([(o) => OrderingTerm.asc(o.displayOrder)]))
          .get();
      result.add({
        'modifier_group_id': g.modifierGroupId,
        'group_name': g.groupName,
        'selection_type': g.selectionType,
        'min_selection': g.minSelection,
        'max_selection': g.maxSelection,
        'is_required': g.isRequired,
        'options': opts
            .map((o) => {
                  'modifier_id': o.modifierId,
                  'modifier_group_id': o.modifierGroupId,
                  'modifier_name': o.modifierName,
                  'price_adjustment': o.priceAdjustment,
                  'is_default': o.isDefault,
                  'display_order': o.displayOrder,
                })
            .toList(),
      });
    }
    return result;
  }

  // ── Group handlers ────────────────────────────────────────

  Future<Response> _listGroups(Request req) async {
    final groups = await (db.select(db.modifierGroups)
          ..orderBy([(g) => OrderingTerm.asc(g.groupName)]))
        .get();
    return _ok(await _groupsWithOptions(groups));
  }

  Future<Response> _createGroup(Request req) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final id =
          'MG_${DateTime.now().millisecondsSinceEpoch}';
      await db.into(db.modifierGroups).insert(ModifierGroupsCompanion(
            modifierGroupId: Value(id),
            groupName: Value(body['group_name'] as String),
            selectionType: Value(
                body['selection_type'] as String? ?? 'SINGLE'),
            minSelection:
                Value(body['min_selection'] as int? ?? 0),
            maxSelection:
                Value(body['max_selection'] as int? ?? 1),
            isRequired:
                Value(body['is_required'] as bool? ?? false),
          ));
      final created = await (db.select(db.modifierGroups)
            ..where((g) => g.modifierGroupId.equals(id)))
          .getSingle();
      final data = await _groupsWithOptions([created]);
      return _ok(data.first);
    } catch (e) {
      return _err('$e');
    }
  }

  Future<Response> _updateGroup(Request req, String id) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await (db.update(db.modifierGroups)
            ..where((g) => g.modifierGroupId.equals(id)))
          .write(ModifierGroupsCompanion(
        groupName: body.containsKey('group_name')
            ? Value(body['group_name'] as String)
            : const Value.absent(),
        selectionType: body.containsKey('selection_type')
            ? Value(body['selection_type'] as String)
            : const Value.absent(),
        minSelection: body.containsKey('min_selection')
            ? Value(body['min_selection'] as int)
            : const Value.absent(),
        maxSelection: body.containsKey('max_selection')
            ? Value(body['max_selection'] as int)
            : const Value.absent(),
        isRequired: body.containsKey('is_required')
            ? Value(body['is_required'] as bool)
            : const Value.absent(),
      ));
      return _ok({'message': 'updated'});
    } catch (e) {
      return _err('$e');
    }
  }

  Future<Response> _deleteGroup(Request req, String id) async {
    try {
      await (db.delete(db.productModifiers)
            ..where((pm) => pm.modifierGroupId.equals(id)))
          .go();
      await (db.delete(db.modifiers)
            ..where((o) => o.modifierGroupId.equals(id)))
          .go();
      await (db.delete(db.modifierGroups)
            ..where((g) => g.modifierGroupId.equals(id)))
          .go();
      return _ok({'message': 'deleted'});
    } catch (e) {
      return _err('$e');
    }
  }

  // ── Option handlers ───────────────────────────────────────

  Future<Response> _listOptions(Request req, String id) async {
    final opts = await (db.select(db.modifiers)
          ..where((o) => o.modifierGroupId.equals(id))
          ..orderBy([(o) => OrderingTerm.asc(o.displayOrder)]))
        .get();
    return _ok(opts
        .map((o) => {
              'modifier_id': o.modifierId,
              'modifier_group_id': o.modifierGroupId,
              'modifier_name': o.modifierName,
              'price_adjustment': o.priceAdjustment,
              'is_default': o.isDefault,
              'display_order': o.displayOrder,
            })
        .toList());
  }

  Future<Response> _createOption(Request req, String groupId) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final id = 'MOD_${DateTime.now().millisecondsSinceEpoch}';
      await db.into(db.modifiers).insert(ModifiersCompanion(
            modifierId: Value(id),
            modifierGroupId: Value(groupId),
            modifierName: Value(body['modifier_name'] as String),
            priceAdjustment: Value(
                (body['price_adjustment'] as num?)?.toDouble() ?? 0),
            isDefault:
                Value(body['is_default'] as bool? ?? false),
            displayOrder:
                Value(body['display_order'] as int? ?? 0),
          ));
      return _ok({'modifier_id': id});
    } catch (e) {
      return _err('$e');
    }
  }

  Future<Response> _updateOption(Request req, String optId) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await (db.update(db.modifiers)
            ..where((o) => o.modifierId.equals(optId)))
          .write(ModifiersCompanion(
        modifierName: body.containsKey('modifier_name')
            ? Value(body['modifier_name'] as String)
            : const Value.absent(),
        priceAdjustment: body.containsKey('price_adjustment')
            ? Value((body['price_adjustment'] as num).toDouble())
            : const Value.absent(),
        isDefault: body.containsKey('is_default')
            ? Value(body['is_default'] as bool)
            : const Value.absent(),
        displayOrder: body.containsKey('display_order')
            ? Value(body['display_order'] as int)
            : const Value.absent(),
      ));
      return _ok({'message': 'updated'});
    } catch (e) {
      return _err('$e');
    }
  }

  Future<Response> _deleteOption(Request req, String optId) async {
    try {
      await (db.delete(db.modifiers)
            ..where((o) => o.modifierId.equals(optId)))
          .go();
      return _ok({'message': 'deleted'});
    } catch (e) {
      return _err('$e');
    }
  }

  // ── Product ↔ Group link handlers ─────────────────────────

  Future<Response> _listByProduct(
      Request req, String productId) async {
    final links = await (db.select(db.productModifiers)
          ..where((pm) => pm.productId.equals(productId)))
        .get();
    if (links.isEmpty) return _ok([]);

    final groupIds = links.map((l) => l.modifierGroupId).toList();
    final groups = await (db.select(db.modifierGroups)
          ..where((g) => g.modifierGroupId.isIn(groupIds)))
        .get();

    return _ok(await _groupsWithOptions(groups));
  }

  Future<Response> _linkGroup(
      Request req, String productId, String groupId) async {
    try {
      await db.into(db.productModifiers).insertOnConflictUpdate(
            ProductModifiersCompanion(
              productId: Value(productId),
              modifierGroupId: Value(groupId),
            ),
          );
      return _ok({'message': 'linked'});
    } catch (e) {
      return _err('$e');
    }
  }

  Future<Response> _unlinkGroup(
      Request req, String productId, String groupId) async {
    try {
      await (db.delete(db.productModifiers)
            ..where((pm) =>
                pm.productId.equals(productId) &
                pm.modifierGroupId.equals(groupId)))
          .go();
      return _ok({'message': 'unlinked'});
    } catch (e) {
      return _err('$e');
    }
  }
}
