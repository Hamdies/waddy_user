import 'package:waddy_app/common/models/image_variants.dart';
import 'package:waddy_app/features/item/domain/models/basic_campaign_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

class BannerModel {
  List<BasicCampaignModel>? campaigns;
  List<Banner>? banners;

  BannerModel({this.campaigns, this.banners});

  BannerModel.fromJson(Map<String, dynamic> json) {
    if (json['campaigns'] != null) {
      campaigns = [];
      json['campaigns'].forEach((v) {
        campaigns!.add(BasicCampaignModel.fromJson(v));
      });
    }
    if (json['banners'] != null) {
      banners = [];
      json['banners'].forEach((v) {
        banners!.add(Banner.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (campaigns != null) {
      data['campaigns'] = campaigns!.map((v) => v.toJson()).toList();
    }
    if (banners != null) {
      data['banners'] = banners!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Banner {
  int? id;
  String? title;
  String? type;
  String? imageFullUrl;

  /// Right-sized WebP set for [imageFullUrl]; null when the backend emitted
  /// none. Hand it to CustomImage's `variants:`. See ImageVariants.
  ImageVariants? imageVariants;
  String? link;
  Store? store;
  Item? item;

  Banner({
    this.id,
    this.title,
    this.type,
    this.imageFullUrl,
    this.link,
    this.store,
    this.item,
  });

  Banner.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    type = json['type'];
    imageFullUrl = json['image_full_url'];
    imageVariants = ImageVariants.fromJson(json['image_variants']);
    link = json['link'];
    store = json['store'] != null ? Store.fromJson(json['store']) : null;
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['type'] = type;
    data['image_full_url'] = imageFullUrl;
    if (imageVariants != null) data['image_variants'] = imageVariants!.toJson();
    data['link'] = link;
    if (store != null) {
      data['store'] = store!.toJson();
    }
    if (item != null) {
      data['item'] = item!.toJson();
    }
    return data;
  }
}
