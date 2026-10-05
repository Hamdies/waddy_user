import 'package:waddy_app/common/models/image_variants.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/banner/domain/models/banner_model.dart';
import 'package:waddy_app/features/item/domain/models/basic_campaign_model.dart';
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

      // Same `?? const []` guard as _prepareBanner: the backend's error path
      // returns a bare `[]`, which parses into a model with both fields null.
      final List<BasicCampaignModel> campaigns =
          bannerModel.campaigns ?? const [];
      final List<Banner> banners = bannerModel.banners ?? const [];

      for (var campaign in campaigns) {
        if (_featuredBannerList!.contains(campaign.imageFullUrl)) {
          _featuredBannerList!.add(
            '${campaign.imageFullUrl}${campaigns.indexOf(campaign)}',
          );
        } else {
          _featuredBannerList!.add(campaign.imageFullUrl);
        }
        _featuredBannerDataList!.add(campaign);
      }
      for (var banner in banners) {
        if (_featuredBannerList!.contains(banner.imageFullUrl)) {
          _featuredBannerList!.add(
            '${banner.imageFullUrl}${banners.indexOf(banner)}',
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

  /// Drops all three banner lists together.
  ///
  /// They are built index-for-index in [_prepareBanner], so nulling only the
  /// image list left the data and variant lists holding the previous module's
  /// entries — and a refetch that then failed would leave them that way.
  void clearBanner() {
    _bannerImageList = null;
    _bannerDataList = null;
    _bannerVariantsList = null;
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
        // A cache miss is not an answer, so it must not paint one. Publishing
        // the empty state here would flash "no banner" on every cold start
        // before the network reply lands; staying null keeps the shimmer up
        // and lets the client call below resolve it.
        if (bannerModel != null) {
          _prepareBanner(bannerModel);
        }

        // Awaited: this is the call that actually resolves the state on a
        // cold start. Fire-and-forget meant a failure here left the lists
        // null and the shimmer running for the life of the screen.
        await getBannerList(
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

  /// Resolves the banner lists to a rendered state, always.
  ///
  /// BannerView reads null as "still loading" and an empty list as "no
  /// banner", so leaving the lists null on a failed or empty fetch shimmers
  /// forever. Every path through here therefore ends with non-null lists, so
  /// a failed or empty fetch collapses the section instead of loading forever.
  ///
  /// The campaign and banner collections are read with `?? const []`: the
  /// backend's own error path returns a bare `[]` with status 200, which
  /// parses into a model whose fields are both null, and the bangs that used
  /// to be here threw inside the fetch — swallowed by the home screen's
  /// `_safe`, leaving the lists null and the shimmer running.
  void _prepareBanner(BannerModel? bannerModel) {
    _bannerImageList = [];
    _bannerDataList = [];
    _bannerVariantsList = [];

    if (bannerModel != null) {
      final List<BasicCampaignModel> campaigns =
          bannerModel.campaigns ?? const [];
      final List<Banner> banners = bannerModel.banners ?? const [];

      for (var campaign in campaigns) {
        if (_bannerImageList!.contains(campaign.imageFullUrl)) {
          _bannerImageList!.add(
            '${campaign.imageFullUrl}${campaigns.indexOf(campaign)}',
          );
        } else {
          _bannerImageList!.add(campaign.imageFullUrl);
        }
        _bannerVariantsList!.add(campaign.imageVariants);
        _bannerDataList!.add(campaign);
      }
      for (var banner in banners) {
        if (_bannerImageList!.contains(banner.imageFullUrl)) {
          _bannerImageList!.add(
            '${banner.imageFullUrl}${banners.indexOf(banner)}',
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
