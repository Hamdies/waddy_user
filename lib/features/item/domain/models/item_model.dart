import 'package:waddy_app/common/models/image_variants.dart';
import 'package:waddy_app/util/parse.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/item/domain/models/basic_medicine_model.dart';

class ItemModel {
  int? totalSize;
  String? limit;
  int? offset;
  List<Item>? items;
  List<Categories>? categories;

  ItemModel({
    this.totalSize,
    this.limit,
    this.offset,
    this.items,
    this.categories,
  });

  ItemModel.fromJson(Map<String, dynamic> json) {
    totalSize = json['total_size'];
    limit = json['limit'].toString();
    offset =
        (json['offset'] != null && json['offset'].toString().trim().isNotEmpty)
            ? Parse.lenientInt(json['offset'])
            : null;
    if (json['products'] != null) {
      items = [];
      json['products'].forEach((v) {
        items!.add(Item.fromJson(v));
      });
    }
    if (json['items'] != null) {
      items = [];
      json['items'].forEach((v) {
        if (v['module_type'] == null ||
            !Get.find<SplashController>()
                .getModuleConfig(v['module_type'])
                .newVariation! ||
            v['variations'] == null ||
            v['variations'].isEmpty ||
            (v['food_variations'] != null && v['food_variations'].isNotEmpty)) {
          items!.add(Item.fromJson(v));
        }
      });
    }
    if (json['categories'] != null) {
      categories = <Categories>[];
      json['categories'].forEach((v) {
        categories!.add(Categories.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['offset'] = offset;
    if (items != null) {
      data['products'] = items!.map((v) => v.toJson()).toList();
    }
    if (categories != null) {
      data['categories'] = categories!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Item {
  int? id;
  String? name;
  String? description;
  String? imageFullUrl;

  /// Right-sized WebP set for [imageFullUrl]; null when the backend emitted
  /// none. Hand it to CustomImage's `variants:`. See ImageVariants.
  ImageVariants? imageVariants;
  List<String>? imagesFullUrl;
  int? categoryId;
  List<CategoryIds>? categoryIds;

  /// Lifetime orders, as the backend counts them. Lets a "best sellers" rail
  /// tell real sales from a sort over all-zero counts.
  int? orderCount;
  List<Variation>? variations;
  List<FoodVariation>? foodVariations;
  List<AddOns>? addOns;
  List<ChoiceOptions>? choiceOptions;
  double? price;
  double? tax;
  double? discount;
  String? discountType;
  String? availableTimeStarts;
  String? availableTimeEnds;
  int? storeId;
  String? storeName;

  /// The selling store's logo and whether it is taking orders now — set on
  /// item search results, which group by store. Null where the endpoint does
  /// not say.
  String? storeLogoFullUrl;
  bool? storeOpen;

  /// The store's delivery window in minutes, as the item payload carries it;
  /// zero or null when the store states none.
  int? minDeliveryTime;
  int? maxDeliveryTime;
  int? zoneId;
  bool? scheduleOrder;
  double? avgRating;
  int? ratingCount;
  int? veg;
  int? moduleId;
  String? moduleType;
  String? unitType;

  /// The master catalogue product this listing takes its content from; null
  /// for an unlinked listing. Two listings in one rail with the same id are
  /// one product sold twice — see `ShelfListings.dedupe`.
  int? catalogProductId;
  int? stock;
  String? availableDateStarts;
  int? organic;
  int? quantityLimit;
  int? flashSale;
  bool? isStoreHalalActive;
  bool? isHalalItem;
  bool? isPrescriptionRequired;
  List<String>? nutritionsName;
  List<String>? allergiesName;
  List<String>? genericName;
  int? potentialXp;

  /// The produce question this item asks before adding — `ripeness` or
  /// `use` — from its category; null for everything else. See
  /// `ProducePreference`.
  String? prepOption;

  Item({
    this.id,
    this.name,
    this.description,
    this.imageFullUrl,
    this.imagesFullUrl,
    this.categoryId,
    this.categoryIds,
    this.variations,
    this.foodVariations,
    this.addOns,
    this.choiceOptions,
    this.price,
    this.tax,
    this.discount,
    this.discountType,
    this.availableTimeStarts,
    this.availableTimeEnds,
    this.storeId,
    this.storeName,
    this.zoneId,
    this.scheduleOrder,
    this.avgRating,
    this.ratingCount,
    this.veg,
    this.moduleId,
    this.moduleType,
    this.unitType,
    this.catalogProductId,
    this.stock,
    this.organic,
    this.quantityLimit,
    this.flashSale,
    this.isStoreHalalActive,
    this.isHalalItem,
    this.isPrescriptionRequired,
    this.nutritionsName,
    this.allergiesName,
    this.genericName,
    this.potentialXp,
    this.prepOption,
  });

  Item.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    imageFullUrl = json['image_full_url'];
    imageVariants = ImageVariants.fromJson(json['image_variants']);
    if (json['images_full_url'] != null) {
      imagesFullUrl = [];
      json['images_full_url'].forEach((v) {
        if (v != null) {
          imagesFullUrl!.add(v.toString());
        }
      });
    }
    categoryId = json['category_id'];
    orderCount = int.tryParse('${json['order_count'] ?? ''}');
    if (json['category_ids'] != null) {
      categoryIds = [];
      json['category_ids'].forEach((v) {
        categoryIds!.add(CategoryIds.fromJson(v));
      });
    }
    variations = [];
    if (json['variations'] != null) {
      json['variations'].forEach((v) {
        variations!.add(Variation.fromJson(v));
      });
    }
    foodVariations = [];
    if (json['food_variations'] != null && json['food_variations'].isNotEmpty) {
      json['food_variations'].forEach((v) {
        foodVariations!.add(FoodVariation.fromJson(v));
      });
    }
    if (json['add_ons'] != null) {
      addOns = [];
      if (json['add_ons'].length > 0 && json['add_ons'][0] != '[') {
        json['add_ons'].forEach((v) {
          addOns!.add(AddOns.fromJson(v));
        });
      } else if (json['addons'] != null) {
        json['addons'].forEach((v) {
          addOns!.add(AddOns.fromJson(v));
        });
      }
    }
    if (json['choice_options'] != null) {
      choiceOptions = [];
      json['choice_options'].forEach((v) {
        choiceOptions!.add(ChoiceOptions.fromJson(v));
      });
    }
    price = json['price'] != null ? json['price'].toDouble() : 0;
    tax = json['tax']?.toDouble();
    discount = json['discount'] != null ? json['discount'].toDouble() : 0;
    discountType = json['discount_type'];
    availableTimeStarts = json['available_time_starts'];
    availableTimeEnds = json['available_time_ends'];
    storeId = json['store_id'];
    storeName = json['store_name'];
    // Flat keys first (item search adds them); the nested store object is what
    // every item payload that loads the relation carries.
    final dynamic nestedStore = json['store'];
    storeLogoFullUrl =
        json['store_logo_full_url'] ??
        (nestedStore is Map ? nestedStore['logo_full_url'] : null);
    storeOpen =
        json['store_open'] != null
            ? (json['store_open'] == true || json['store_open'] == 1)
            : (nestedStore is Map && nestedStore['open'] != null
                ? (nestedStore['open'] == 1 || nestedStore['open'] == true) &&
                    (nestedStore['active'] == null ||
                        nestedStore['active'] == 1 ||
                        nestedStore['active'] == true)
                : null);
    minDeliveryTime = Parse.lenientInt(json['min_delivery_time']);
    maxDeliveryTime = Parse.lenientInt(json['max_delivery_time']);
    zoneId = json['zone_id'];
    scheduleOrder = json['schedule_order'];
    avgRating = json['avg_rating']?.toDouble();
    ratingCount = json['rating_count'];
    moduleId = json['module_id'];
    moduleType = json['module_type'];
    veg = Parse.lenientInt(json['veg']);
    stock = json['stock'];
    unitType = json['unit_type'];
    // Null is normal (an unlinked listing), so not `Parse.strictInt`, which
    // reports a null as unreadable.
    final Object? catalogProduct = json['catalog_product_id'];
    catalogProductId =
        catalogProduct is num
            ? catalogProduct.toInt()
            : int.tryParse('${catalogProduct ?? ''}');
    availableDateStarts = json['available_date_starts'];
    organic = json['organic'];
    quantityLimit = json['maximum_cart_quantity'];
    flashSale = json['flash_sale'];
    isStoreHalalActive = json['halal_tag_status'] == 1;
    isHalalItem = json['is_halal'] == 1;
    isPrescriptionRequired = json['is_prescription_required'] == 1;
    nutritionsName = json['nutritions_name']?.cast<String>();
    allergiesName = json['allergies_name']?.cast<String>();
    genericName = json['generic_name']?.cast<String>();
    potentialXp =
        json['potential_xp'] != null
            ? int.tryParse(json['potential_xp'].toString())
            : null;
    prepOption = json['prep_option'] is String ? json['prep_option'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['description'] = description;
    data['image_full_url'] = imageFullUrl;
    if (imageVariants != null) data['image_variants'] = imageVariants!.toJson();
    data['images_full_url'] = imagesFullUrl;
    data['category_id'] = categoryId;
    if (categoryIds != null) {
      data['category_ids'] = categoryIds!.map((v) => v.toJson()).toList();
    }
    if (variations != null) {
      data['variations'] = variations!.map((v) => v.toJson()).toList();
    }
    if (foodVariations != null) {
      data['food_variations'] = foodVariations!.map((v) => v.toJson()).toList();
    }
    if (addOns != null) {
      data['add_ons'] = addOns!.map((v) => v.toJson()).toList();
    }
    if (choiceOptions != null) {
      data['choice_options'] = choiceOptions!.map((v) => v.toJson()).toList();
    }
    data['price'] = price;
    data['tax'] = tax;
    data['discount'] = discount;
    data['discount_type'] = discountType;
    data['available_time_starts'] = availableTimeStarts;
    data['available_time_ends'] = availableTimeEnds;
    data['store_id'] = storeId;
    data['store_name'] = storeName;
    data['store_logo_full_url'] = storeLogoFullUrl;
    data['store_open'] = storeOpen;
    data['min_delivery_time'] = minDeliveryTime;
    data['max_delivery_time'] = maxDeliveryTime;
    data['zone_id'] = zoneId;
    data['schedule_order'] = scheduleOrder;
    data['avg_rating'] = avgRating;
    data['rating_count'] = ratingCount;
    data['veg'] = veg;
    data['module_id'] = moduleId;
    data['module_type'] = moduleType;
    data['stock'] = stock;
    data['unit_type'] = unitType;
    data['catalog_product_id'] = catalogProductId;
    data['available_date_starts'] = availableDateStarts;
    data['organic'] = organic;
    data['maximum_cart_quantity'] = quantityLimit;
    data['flash_sale'] = flashSale;
    data['halal_tag_status'] = isStoreHalalActive;
    data['is_halal'] = isHalalItem;
    data['is_prescription_required'] = isPrescriptionRequired;
    data['nutritions_name'] = nutritionsName;
    data['allergies_name'] = allergiesName;
    data['generic_name'] = genericName;
    data['potential_xp'] = potentialXp;
    data['prep_option'] = prepOption;
    return data;
  }

  /// Get XP for this item: use server-provided potentialXp, or calculate client-side
  /// Formula: floor(price × module_multiplier × 0.1)
  int getDisplayXp({double multiplier = 1.0}) {
    if (potentialXp != null && potentialXp! > 0) return potentialXp!;
    if (price == null || price! <= 0) return 0;
    return (price! * multiplier * 0.1).floor();
  }
}

class CategoryIds {
  int? id;
  int? position;

  CategoryIds({this.id, this.position});

  CategoryIds.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'].toString()) ?? 0;
    position = int.tryParse(json['position'].toString()) ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['position'] = position;
    return data;
  }
}

class Variation {
  String? type;
  double? price;
  int? stock;

  Variation({this.type, this.price, this.stock});

  Variation.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    price = json['price']?.toDouble();
    stock = Parse.lenientInt(json['stock']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['price'] = price;
    data['stock'] = stock;
    return data;
  }
}

class AddOns {
  int? id;
  String? name;
  double? price;

  AddOns({this.id, this.name, this.price});

  AddOns.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    price = json['price'] != null ? json['price'].toDouble() : 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['price'] = price;
    return data;
  }
}

class ChoiceOptions {
  String? name;
  String? title;
  List<String>? options;

  ChoiceOptions({this.name, this.title, this.options});

  ChoiceOptions.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    title = json['title'];
    options = json['options'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['title'] = title;
    data['options'] = options;
    return data;
  }
}

class FoodVariation {
  String? name;
  bool? multiSelect;
  int? min;
  int? max;
  bool? required;
  List<VariationValue>? variationValues;

  FoodVariation({
    this.name,
    this.multiSelect,
    this.min,
    this.max,
    this.required,
    this.variationValues,
  });

  FoodVariation.fromJson(Map<String, dynamic> json) {
    if (json['max'] != null) {
      name = json['name'];
      multiSelect = json['type'] == 'multi';
      min = multiSelect! ? Parse.lenientInt(json['min']) : 0;
      max = multiSelect! ? Parse.lenientInt(json['max']) : 0;
      required = json['required'] == 'on';
      if (json['values'] != null) {
        variationValues = [];
        json['values'].forEach((v) {
          variationValues!.add(VariationValue.fromJson(v));
        });
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['type'] = multiSelect;
    data['min'] = min;
    data['max'] = max;
    data['required'] = required;
    if (variationValues != null) {
      data['values'] = variationValues!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class VariationValue {
  String? level;
  double? optionPrice;
  bool? isSelected;

  VariationValue({this.level, this.optionPrice, this.isSelected});

  VariationValue.fromJson(Map<String, dynamic> json) {
    level = json['label'];
    // Strict: an option price feeds the cart line and the order total.
    optionPrice = Parse.strictDouble(json['optionPrice'], 'optionPrice');
    isSelected = json['isSelected'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['label'] = level;
    data['optionPrice'] = optionPrice;
    data['isSelected'] = isSelected;
    return data;
  }
}
