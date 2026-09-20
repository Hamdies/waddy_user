import 'package:waddy_app/common/models/image_variants.dart';

class CategoryModel {
  int? id;
  String? name;
  String? imageFullUrl;

  /// Right-sized WebP set for [imageFullUrl]; null when the backend emitted
  /// none. Hand it to CustomImage's `variants:`. See ImageVariants.
  ImageVariants? imageVariants;

  CategoryModel({this.id, this.name, this.imageFullUrl});

  CategoryModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    imageFullUrl = json['image_full_url'];
    imageVariants = ImageVariants.fromJson(json['image_variants']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image_full_url'] = imageFullUrl;
    if (imageVariants != null) data['image_variants'] = imageVariants!.toJson();
    return data;
  }
}
