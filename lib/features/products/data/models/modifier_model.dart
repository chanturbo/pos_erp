class ModifierOptionModel {
  final String modifierId;
  final String modifierGroupId;
  final String modifierName;
  final double priceAdjustment;
  final bool isDefault;
  final int displayOrder;

  const ModifierOptionModel({
    required this.modifierId,
    required this.modifierGroupId,
    required this.modifierName,
    this.priceAdjustment = 0,
    this.isDefault = false,
    this.displayOrder = 0,
  });

  factory ModifierOptionModel.fromJson(Map<String, dynamic> json) =>
      ModifierOptionModel(
        modifierId: json['modifier_id'] as String,
        modifierGroupId: json['modifier_group_id'] as String,
        modifierName: json['modifier_name'] as String,
        priceAdjustment:
            (json['price_adjustment'] as num?)?.toDouble() ?? 0,
        isDefault: json['is_default'] as bool? ?? false,
        displayOrder: json['display_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'modifier_id': modifierId,
        'modifier_group_id': modifierGroupId,
        'modifier_name': modifierName,
        'price_adjustment': priceAdjustment,
        'is_default': isDefault,
        'display_order': displayOrder,
      };
}

class ModifierGroupModel {
  final String modifierGroupId;
  final String groupName;
  final String selectionType; // SINGLE | MULTIPLE
  final int minSelection;
  final int maxSelection;
  final bool isRequired;
  final List<ModifierOptionModel> options;

  const ModifierGroupModel({
    required this.modifierGroupId,
    required this.groupName,
    this.selectionType = 'SINGLE',
    this.minSelection = 0,
    this.maxSelection = 1,
    this.isRequired = false,
    this.options = const [],
  });

  bool get isSingle => selectionType == 'SINGLE';

  factory ModifierGroupModel.fromJson(Map<String, dynamic> json) =>
      ModifierGroupModel(
        modifierGroupId: json['modifier_group_id'] as String,
        groupName: json['group_name'] as String,
        selectionType: json['selection_type'] as String? ?? 'SINGLE',
        minSelection: json['min_selection'] as int? ?? 0,
        maxSelection: json['max_selection'] as int? ?? 1,
        isRequired: json['is_required'] as bool? ?? false,
        options: (json['options'] as List<dynamic>? ?? [])
            .map((o) => ModifierOptionModel.fromJson(
                Map<String, dynamic>.from(o as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'modifier_group_id': modifierGroupId,
        'group_name': groupName,
        'selection_type': selectionType,
        'min_selection': minSelection,
        'max_selection': maxSelection,
        'is_required': isRequired,
        'options': options.map((o) => o.toJson()).toList(),
      };
}
