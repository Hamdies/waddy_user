import 'package:sixam_mart/features/item/domain/models/item_model.dart';

class StoreBundleModel {
  int? id;
  int? storeId;
  String? name;
  String? description;
  double? price;
  String? imageFullUrl;
  bool? isActive;
  String? createdAt;
  String? updatedAt;
  List<Item>? items;

  StoreBundleModel({
    this.id,
    this.storeId,
    this.name,
    this.description,
    this.price,
    this.imageFullUrl,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.items,
  });

  StoreBundleModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    storeId = json['store_id'];
    name = json['name'];
    description = json['description'];
    price = json['price']?.toDouble();
    imageFullUrl = json['image_full_url'];
    isActive = json['is_active'] == 1 || json['is_active'] == true;
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    if (json['items'] != null) {
      items = [];
      json['items'].forEach((v) {
        items!.add(Item.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['store_id'] = storeId;
    data['name'] = name;
    data['description'] = description;
    data['price'] = price;
    data['image_full_url'] = imageFullUrl;
    data['is_active'] = isActive;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (items != null) {
      data['items'] = items!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
