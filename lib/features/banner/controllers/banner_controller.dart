import 'package:waddy_app/common/models/image_variants.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/banner/domain/models/banner_model.dart';
import 'package:waddy_app/features/banner/domain/models/others_banner_model.dart';
import 'package:waddy_app/features/banner/domain/models/promotional_banner_model.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/banner/domain/services/banner_service_interface.dart';

class BannerController extends GetxController implements GetxService {
  final BannerServiceInterface bannerServiceInterface;
  BannerController({required this.bannerServiceInterface});

  List<String?>? _bannerImageList;
  List<String?>? get bannerImageList => _bannerImageList;

  /// Variant sets aligned index-for-index with [bannerImageList].
  ///
  /// The image list is flattened to bare URL strings, so the model — and with
  /// it the variant map — is lost by the time the carousel renders. This keeps
  /// it reachable without changing the shape the widgets already consume.
  List<ImageVariants?>? _bannerVariantsList;
  List<ImageVariants?>? get bannerVariantsList => _bannerVariantsList;

  List<String?>? _featuredBannerList;
  List<String?>? get featuredBannerList => _featuredBannerList;

  List<dynamic>? _bannerDataList;
  List<dynamic>? get bannerDataList => _bannerDataList;

  List<dynamic>? _featuredBannerDataList;
  List<dynamic>? get featuredBannerDataList => _featuredBannerDataList;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  ParcelOtherBannerModel? _parcelOtherBannerModel;
  ParcelOtherBannerModel? get parcelOtherBannerModel => _parcelOtherBannerModel;

  PromotionalBanner? _promotionalBanner;
  PromotionalBanner? get promotionalBanner => _promotionalBanner;

  Future<void> getFeaturedBanner() async {
    BannerModel? bannerModel =
        await bannerServiceInterface.getFeaturedBannerList();
    if (bannerModel != null) {
      _featuredBannerList = [];
      _featuredBannerDataList = [];

      List<int?> moduleIdList = bannerServiceInterface.moduleIdList();

      for (var campaign in bannerModel.campaigns!) {
        if (_featuredBannerList!.contains(campaign.imageFullUrl)) {
          _featuredBannerList!.add(
            '${campaign.imageFullUrl}${bannerModel.campaigns!.indexOf(campaign)}',
          );
        } else {
          _featuredBannerList!.add(campaign.imageFullUrl);
        }
        _featuredBannerDataList!.add(campaign);
      }
      for (var banner in bannerModel.banners!) {
        if (_featuredBannerList!.contains(banner.imageFullUrl)) {
          _featuredBannerList!.add(
            '${banner.imageFullUrl}${bannerModel.banners!.indexOf(banner)}',
          );
        } else {
          _featuredBannerList!.add(banner.imageFullUrl);
        }
        if (banner.item != null &&
            moduleIdList.contains(banner.item!.moduleId)) {
          _featuredBannerDataList!.add(banner.item);
        } else if (banner.store != null &&
            moduleIdList.contains(banner.store!.moduleId)) {
          _featuredBannerDataList!.add(banner.store);
        } else if (banner.type == 'default') {
          _featuredBannerDataList!.add(banner.link);
        } else {
          _featuredBannerDataList!.add(null);
        }
      }
    }
    update();
  }

  void clearBanner() {
    _bannerImageList = null;
  }

  Future<void> getBannerList(
    bool reload, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (_bannerImageList == null || reload || fromRecall) {
      if (reload) {
        _bannerImageList = null;
      }
      BannerModel? bannerModel;
      if (dataSource == DataSourceEnum.local) {
        bannerModel = await bannerServiceInterface.getBannerList(
          source: DataSourceEnum.local,
        );
        await _prepareBanner(bannerModel);

        getBannerList(
          false,
          dataSource: DataSourceEnum.client,
          fromRecall: true,
        );
      } else {
        bannerModel = await bannerServiceInterface.getBannerList(
          source: DataSourceEnum.client,
        );
        _prepareBanner(bannerModel);
      }
    }
  }

  _prepareBanner(BannerModel? bannerModel) async {
    if (bannerModel != null) {
      _bannerImageList = [];
      _bannerDataList = [];
      _bannerVariantsList = [];
      for (var campaign in bannerModel.campaigns!) {
        if (_bannerImageList!.contains(campaign.imageFullUrl)) {
          _bannerImageList!.add(
            '${campaign.imageFullUrl}${bannerModel.campaigns!.indexOf(campaign)}',
          );
        } else {
          _bannerImageList!.add(campaign.imageFullUrl);
        }
        _bannerVariantsList!.add(campaign.imageVariants);
        _bannerDataList!.add(campaign);
      }
      for (var banner in bannerModel.banners!) {
        if (_bannerImageList!.contains(banner.imageFullUrl)) {
          _bannerImageList!.add(
            '${banner.imageFullUrl}${bannerModel.banners!.indexOf(banner)}',
          );
        } else {
          _bannerImageList!.add(banner.imageFullUrl);
        }
        _bannerVariantsList!.add(banner.imageVariants);

        if (banner.item != null) {
          _bannerDataList!.add(banner.item);
        } else if (banner.store != null) {
          _bannerDataList!.add(banner.store);
        } else if (banner.type == 'default') {
          _bannerDataList!.add(banner.link);
        } else {
          _bannerDataList!.add(null);
        }
      }
    }
    update();
  }

  Future<void> getParcelOtherBannerList(
    bool reload, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (_parcelOtherBannerModel == null || reload || fromRecall) {
      ParcelOtherBannerModel? parcelOtherBannerModel;
      if (dataSource == DataSourceEnum.local) {
        parcelOtherBannerModel = await bannerServiceInterface
            .getParcelOtherBannerList(source: dataSource);
        _prepareParcelBanner(parcelOtherBannerModel);
        getParcelOtherBannerList(
          false,
          dataSource: DataSourceEnum.client,
          fromRecall: true,
        );
      } else {
        parcelOtherBannerModel = await bannerServiceInterface
            .getParcelOtherBannerList(source: dataSource);
        _prepareParcelBanner(parcelOtherBannerModel);
      }
    }
  }

  _prepareParcelBanner(ParcelOtherBannerModel? parcelOtherBannerModel) {
    if (parcelOtherBannerModel != null) {
      _parcelOtherBannerModel = parcelOtherBannerModel;
    }
    update();
  }

  Future<void> getPromotionalBannerList(bool reload) async {
    if (_promotionalBanner == null || reload) {
      PromotionalBanner? promotionalBanner =
          await bannerServiceInterface.getPromotionalBannerList();
      if (promotionalBanner != null) {
        _promotionalBanner = promotionalBanner;
      }
      update();
    }
  }

  void setCurrentIndex(int index, bool notify) {
    _currentIndex = index;
    if (notify) {
      update();
    }
  }
}
