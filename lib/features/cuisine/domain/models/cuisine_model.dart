import 'package:waddy_app/common/models/image_variants.dart';

/// What a restaurant IS, as opposed to what it happens to sell.
///
/// Food stores are grouped by cuisine, not by category: the Food module has no
/// category rows at all, which is why the home strip has to read this list.
class CuisineModel {
  int? id;
  String? name;
  String? imageFullUrl;
  int? priority;

  /// Right-sized WebP set for [imageFullUrl]; null when the backend emitted
  /// none. Hand it to CustomImage's `variants:`. See ImageVariants.
  ImageVariants? imageVariants;

  CuisineModel({this.id, this.name, this.imageFullUrl, this.priority});

  CuisineModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    // `image_full_url` is the appended accessor; `image` is the raw column and
    // is all the list endpoint selects on some builds.
    imageFullUrl = json['image_full_url'] ?? json['image'];
    priority = json['priority'];
    imageVariants = ImageVariants.fromJson(json['image_variants']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image_full_url'] = imageFullUrl;
    data['priority'] = priority;
    if (imageVariants != null) data['image_variants'] = imageVariants!.toJson();
    return data;
  }
}
