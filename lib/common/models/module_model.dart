import 'package:waddy_app/util/app_constants.dart';

/// The kinds of module the app knows how to render.
///
/// `module_type` arrives as a bare string and used to be compared by hand in
/// 41 places — `module?.moduleType.toString() == AppConstants.food`, including
/// 26 `.toString()` calls on a field already declared `String?`. A typo in any
/// of them is a silently wrong branch, and adding a module meant finding all
/// 41 by grep. Parsing once at the model boundary turns every one of those into
/// a comparison the compiler checks, and a `switch` over this enum tells you at
/// compile time when a case is missing.
///
/// [wire] is the string the backend sends and the header carries; it stays the
/// currency at the API edge, and this enum is the currency everywhere else.
enum ModuleType {
  grocery(AppConstants.grocery),
  food(AppConstants.food),
  pharmacy(AppConstants.pharmacy),
  ecommerce(AppConstants.ecommerce),
  parcel(AppConstants.parcel),
  places(AppConstants.places),

  /// A module type this build does not know — a new one the backend has
  /// started serving, or a missing field. Never matches a real branch, so the
  /// app falls through to its generic handling rather than guessing.
  unknown('');

  const ModuleType(this.wire);

  final String wire;

  /// The type for a raw `module_type` string. Case-insensitive: the payload
  /// has been seen with both casings, which is what the scattered
  /// `?.toLowerCase()` calls were patching over one site at a time.
  static ModuleType of(String? value) {
    if (value == null) return ModuleType.unknown;
    final String normalised = value.toLowerCase().trim();
    for (final ModuleType type in ModuleType.values) {
      if (type != ModuleType.unknown && type.wire == normalised) return type;
    }
    return ModuleType.unknown;
  }
}

class ModuleModel {
  int? id;
  String? moduleName;
  String? moduleType;
  String? thumbnailFullUrl;
  String? iconFullUrl;
  int? themeId;
  String? description;
  int? storesCount;
  String? createdAt;
  String? updatedAt;
  List<ModuleZoneData>? zones;

  /// This module's kind, parsed once. Prefer this to comparing [moduleType].
  ModuleType get type => ModuleType.of(moduleType);

  ModuleModel({
    this.id,
    this.moduleName,
    this.moduleType,
    this.thumbnailFullUrl,
    this.storesCount,
    this.iconFullUrl,
    this.themeId,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.zones,
  });

  ModuleModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    moduleName = json['module_name'];
    moduleType = json['module_type'];
    thumbnailFullUrl = json['thumbnail_full_url'];
    iconFullUrl = json['icon_full_url'];
    themeId = json['theme_id'];
    description = json['description'];
    storesCount = json['stores_count'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    if (json['zones'] != null) {
      zones = <ModuleZoneData>[];
      json['zones'].forEach((v) => zones!.add(ModuleZoneData.fromJson(v)));
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['module_name'] = moduleName;
    data['module_type'] = moduleType;
    data['thumbnail_full_url'] = thumbnailFullUrl;
    data['icon_full_url'] = iconFullUrl;
    data['theme_id'] = themeId;
    data['description'] = description;
    data['stores_count'] = storesCount;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (zones != null) {
      data['zones'] = zones!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ModuleZoneData {
  int? id;
  String? name;
  int? status;
  String? createdAt;
  String? updatedAt;
  bool? cashOnDelivery;
  bool? digitalPayment;

  ModuleZoneData({
    this.id,
    this.name,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.cashOnDelivery,
    this.digitalPayment,
  });

  ModuleZoneData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    cashOnDelivery = json['cash_on_delivery'];
    digitalPayment = json['digital_payment'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['cash_on_delivery'] = cashOnDelivery;
    data['digital_payment'] = digitalPayment;
    return data;
  }
}
