import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/item/domain/models/basic_medicine_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/item/domain/models/common_condition_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/common/widgets/cart_snackbar.dart';
import 'package:waddy_app/common/widgets/confirmation_dialog.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:waddy_app/features/item/screens/item_details_screen.dart';
import 'package:waddy_app/features/item/domain/services/item_service_interface.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/cart/widgets/cart_module_conflict_dialog.dart';

class ItemController extends GetxController implements GetxService {
  final ItemServiceInterface itemServiceInterface;
  ItemController({required this.itemServiceInterface});

  List<Item>? _popularItemList;
  List<Item>? get popularItemList => _popularItemList;

  List<Item>? _reviewedItemList;
  List<Item>? get reviewedItemList => _reviewedItemList;

  List<Item>? _recommendedItemList;
  List<Item>? get recommendedItemList => _recommendedItemList;

  List<Item>? _discountedItemList;
  List<Item>? get discountedItemList => _discountedItemList;

  List<Item>? _ramadanFeaturedItemList;
  List<Item>? get ramadanFeaturedItemList => _ramadanFeaturedItemList;

  List<Categories>? _reviewedCategoriesList;
  List<Categories>? get reviewedCategoriesList => _reviewedCategoriesList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _pageSize = 0;
  int? get pageSize => _pageSize;

  List<String> _offsetList = [];

  int _offset = 1;
  int get offset => _offset;

  List<int>? _variationIndex;
  List<int>? get variationIndex => _variationIndex;

  List<List<bool?>> _selectedVariations = [];
  List<List<bool?>> get selectedVariations => _selectedVariations;

  int? _quantity = 1;
  int? get quantity => _quantity;

  List<bool> _addOnActiveList = [];
  List<bool> get addOnActiveList => _addOnActiveList;

  List<int?> _addOnQtyList = [];
  List<int?> get addOnQtyList => _addOnQtyList;

  final String _popularType = 'all';
  String get popularType => _popularType;

  final String _reviewedType = 'all';
  String get reviewType => _reviewedType;

  final String _discountedType = 'all';
  String get discountedType => _discountedType;

  static final List<String> _itemTypeList = ['all', 'veg', 'non_veg'];
  List<String> get itemTypeList => _itemTypeList;

  int _imageIndex = 0;
  int get imageIndex => _imageIndex;

  int _cartIndex = -1;
  int get cartIndex => _cartIndex;

  Item? _item;
  Item? get item => _item;

  String? _storeLogoUrl;
  String? get storeLogoUrl => _storeLogoUrl;

  int _productSelect = 0;
  int get productSelect => _productSelect;

  int _imageSliderIndex = 0;
  int get imageSliderIndex => _imageSliderIndex;

  List<bool> _collapseVariation = [];
  List<bool> get collapseVariation => _collapseVariation;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool _isReadMore = false;
  bool get isReadMore => _isReadMore;

  BasicMedicineModel? _basicMedicineModel;
  BasicMedicineModel? get basicMedicineModel => _basicMedicineModel;

  List<CommonConditionModel>? _commonConditions;
  List<CommonConditionModel>? get commonConditions => _commonConditions;

  int _selectedCommonCondition = 0;
  int get selectedCommonCondition => _selectedCommonCondition;

  List<Item>? _conditionWiseProduct;
  List<Item>? get conditionWiseProduct => _conditionWiseProduct;

  ItemModel? _featuredCategoriesItem;
  ItemModel? get featuredCategoriesItem => _featuredCategoriesItem;

  int _selectedCategory = 0;
  int get selectedCategory => _selectedCategory;

  static final List<String> _sortOptions = [
    'default',
    'a_to_z',
    'z_to_a',
    'high',
    'low',
  ];
  List<String> get sortOptions => _sortOptions;

  String _selectedSortOption = 'default';
  String get selectedSortOption => _selectedSortOption;

  final List<String> _filter = [];
  List<String>? get filter => _filter;

  int? _rating;
  int? get rating => _rating;

  final List<int> _selectedCategoryIds = [];
  List<int> get selectedCategoryIds => _selectedCategoryIds;

  double _selectedMinPrice = 0;
  double get selectedMinPrice => _selectedMinPrice;

  double _selectedMaxPrice = 9999999999;
  double get selectedMaxPrice => _selectedMaxPrice;

  List<Categories>? _categoryList = [];
  List<Categories>? get categoryList => _categoryList;

  bool _isAvailableItems = false;
  bool get isAvailableItems => _isAvailableItems;

  bool _isUnAvailableItems = false;
  bool get isUnAvailableItems => _isUnAvailableItems;

  bool _isTopRated = false;
  bool get isTopRated => _isTopRated;

  bool _isMostLoved = false;
  bool get isMostLoved => _isMostLoved;

  bool _isPopular = false;
  bool get isPopular => _isPopular;

  bool _isLatest = false;
  bool get isLatest => _isLatest;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  final TextEditingController _searchController = TextEditingController(
    text: '',
  );
  TextEditingController get searchController => _searchController;

  void clearSearch({bool withUpdate = true}) {
    _searchController.text = '';
    _isSearching = false;
    if (withUpdate) {
      update();
    }
  }

  void toggleCategory(int? categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId!);
    }
    update();
  }

  void setMinAndMaxPrice(double min, double max, {bool withUpdate = true}) {
    _selectedMinPrice = min;
    _selectedMaxPrice = max;
    if (withUpdate) {
      update();
    }
  }

  void toggleAvailableItems() {
    _isAvailableItems = !_isAvailableItems;
    if (_isAvailableItems) {
      _filter.add("available_now");
    } else {
      _filter.remove("available_now");
    }
    update();
  }

  void toggleUnavailableItems() {
    _isUnAvailableItems = !_isUnAvailableItems;
    if (_isUnAvailableItems) {
      _filter.add("un_available_now");
    } else {
      _filter.remove("un_available_now");
    }
    update();
  }

  void toggleTopRated() {
    _isTopRated = !_isTopRated;
    if (_isTopRated) {
      _filter.add("top_rated");
    } else {
      _filter.remove("top_rated");
    }
    update();
  }

  void toggleMostLoved() {
    _isMostLoved = !_isMostLoved;
    if (_isMostLoved) {
      _filter.add("most_loved");
    } else {
      _filter.remove("most_loved");
    }
    update();
  }

  void togglePopular() {
    _isPopular = !_isPopular;
    if (_isPopular) {
      _filter.add("popular");
    } else {
      _filter.remove("popular");
    }
    update();
  }

  void toggleLatest() {
    _isLatest = !_isLatest;
    if (_isLatest) {
      _filter.add("latest");
    } else {
      _filter.remove("latest");
    }
    update();
  }

  void setSelectedRating(int rating) {
    _rating = rating;
    update();
  }

  void setSelectedSortOption(String option) {
    _selectedSortOption = option;

    for (var element in _sortOptions) {
      if (_filter.contains(element)) {
        _filter.remove(element);
      } else if (element == _selectedSortOption) {
        _filter.add(element);
      }
    }
    update();
  }

  void selectCategory(int index) {
    _selectedCategory = index;
    update();
  }

  void applyFilters({bool isPopular = false, bool isSpecial = false}) {
    if (isPopular) {
      getPopularItemList(
        notify: true,
        offset: '1',
        dataSource: DataSourceEnum.client,
      );
    } else if (isSpecial) {
      getDiscountedItemList(
        notify: true,
        offset: '1',
        dataSource: DataSourceEnum.client,
      );
    } else {
      getReviewedItemList(
        notify: true,
        offset: '1',
        dataSource: DataSourceEnum.client,
      );
    }
  }

  void resetFilters({bool isPopular = false, bool isSpecial = false}) {
    _selectedCategoryIds.clear();
    _filter.clear();
    _rating = null;
    _selectedMinPrice = 0;
    _selectedMaxPrice = 9999999999;
    _isAvailableItems = false;
    _isUnAvailableItems = false;
    _isTopRated = false;
    _isMostLoved = false;
    _isPopular = false;
    _isLatest = false;
    _selectedSortOption = 'default';
    _searchController.text = '';

    if (isPopular) {
      getPopularItemList(offset: '1', dataSource: DataSourceEnum.client);
    } else if (isSpecial) {
      getDiscountedItemList(offset: '1', dataSource: DataSourceEnum.client);
    } else {
      getReviewedItemList(offset: '1', dataSource: DataSourceEnum.client);
    }

    update();
  }

  void clearFilters({bool isPopular = false, bool isSpecial = false}) {
    _selectedCategoryIds.clear();
    _filter.clear();
    _rating = null;
    _selectedMinPrice = 0;
    _selectedMaxPrice = 9999999999;
    _isAvailableItems = false;
    _isUnAvailableItems = false;
    _isTopRated = false;
    _isMostLoved = false;
    _isPopular = false;
    _isLatest = false;
    _selectedSortOption = 'default';
    _searchController.text = '';

    if (isPopular) {
      getPopularItemList(
        offset: '1',
        dataSource: DataSourceEnum.client,
        firstTimeCategoryLoad: true,
      );
    } else if (isSpecial) {
      getDiscountedItemList(
        offset: '1',
        dataSource: DataSourceEnum.client,
        firstTimeCategoryLoad: true,
      );
    } else {
      getReviewedItemList(
        offset: '1',
        dataSource: DataSourceEnum.client,
        firstTimeCategoryLoad: true,
      );
    }
  }

  void selectCommonCondition(int index) {
    _selectedCommonCondition = index;
    getConditionsWiseItem(_commonConditions![index].id!, true);
    update();
  }

  void changeReadMore() {
    _isReadMore = !_isReadMore;
    update();
  }

  void setCurrentIndex(int index, bool notify) {
    _currentIndex = index;
    if (notify) {
      update();
    }
  }

  void clearItemLists() {
    _popularItemList = null;
    _reviewedItemList = null;
    _discountedItemList = null;
    _featuredCategoriesItem = null;
    _recommendedItemList = null;
    _ramadanFeaturedItemList = null;
  }

  Future<void> getRamadanFeaturedItemList({
    DataSourceEnum dataSource = DataSourceEnum.local,
  }) async {
    if (dataSource == DataSourceEnum.local) {
      _ramadanFeaturedItemList = null;
      update();
      _ramadanFeaturedItemList = await itemServiceInterface
          .getRamadanFeaturedItemList(DataSourceEnum.local);
      update();
      getRamadanFeaturedItemList(dataSource: DataSourceEnum.client);
    } else {
      _ramadanFeaturedItemList = await itemServiceInterface
          .getRamadanFeaturedItemList(DataSourceEnum.client);
      update();
    }
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  bool hasMoreData({bool isPopular = false, bool isSpecial = false}) {
    if (isPopular) {
      return _popularItemList != null && _popularItemList!.length < _pageSize!;
    } else if (isSpecial) {
      return _discountedItemList != null &&
          _discountedItemList!.length < _pageSize!;
    } else {
      return _reviewedItemList != null &&
          _reviewedItemList!.length < _pageSize!;
    }
  }

  Future<void> getPopularItemList({
    required String offset,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool notify = false,
    bool firstTimeCategoryLoad = false,
  }) async {
    if (_searchController.text.isEmpty) {
      _isSearching = false;
      if (notify) update();
    } else {
      _isSearching = true;
      if (notify) update();
    }

    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _popularItemList = null;
      if (firstTimeCategoryLoad) _categoryList = null;
      if (notify) update();
    }

    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);

      ItemModel? itemModel = await itemServiceInterface.getPopularItemList(
        type: _popularType,
        source: dataSource,
        offset: _offset,
        search: _searchController.text,
        categoryIds: _selectedCategoryIds,
        filter: _filter,
        rating: _rating,
        minPrice: _selectedMinPrice,
        maxPrice: _selectedMaxPrice,
      );

      _preparePopularItems(itemModel, offset, firstTimeCategoryLoad);

      if (dataSource == DataSourceEnum.local) {
        getPopularItemList(
          notify: notify,
          dataSource: DataSourceEnum.client,
          offset: '1',
        );
      }
    } else {
      if (isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  void _preparePopularItems(
    ItemModel? itemModel,
    String offset,
    bool firstTimeCategoryLoad,
  ) {
    if (itemModel != null) {
      if (offset == '1') {
        _popularItemList = [];
        if (firstTimeCategoryLoad) _categoryList = [];
      }
      _popularItemList!.addAll(itemModel.items!);
      if (firstTimeCategoryLoad) _categoryList!.addAll(itemModel.categories!);
      _pageSize = itemModel.totalSize;
      _isLoading = false;
    }
    update();
  }

  Future<void> getReviewedItemList({
    required String offset,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool notify = false,
    bool firstTimeCategoryLoad = false,
  }) async {
    if (_searchController.text.isEmpty) {
      _isSearching = false;
      if (notify) update();
    } else {
      _isSearching = true;
      if (notify) update();
    }

    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _reviewedItemList = null;
      _reviewedCategoriesList = null;
      if (firstTimeCategoryLoad) _categoryList = null;
      if (notify) update();
    }

    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);

      ItemModel? itemModel = await itemServiceInterface.getReviewedItemList(
        type: _reviewedType,
        source: dataSource,
        offset: _offset,
        search: _searchController.text,
        categoryIds: _selectedCategoryIds,
        filter: _filter,
        rating: _rating,
        minPrice: _selectedMinPrice,
        maxPrice: _selectedMaxPrice,
      );

      _preparedReviewedItems(itemModel, offset, firstTimeCategoryLoad);

      if (dataSource == DataSourceEnum.local) {
        getReviewedItemList(
          notify: notify,
          dataSource: DataSourceEnum.client,
          offset: '1',
        );
      }
    } else {
      if (_isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  void _preparedReviewedItems(
    ItemModel? itemModel,
    String offset,
    bool firstTimeCategoryLoad,
  ) {
    if (itemModel != null) {
      if (offset == '1') {
        _reviewedItemList = [];
        _reviewedCategoriesList = [];
        if (firstTimeCategoryLoad) _categoryList = [];
      }
      _reviewedItemList!.addAll(itemModel.items!);
      _reviewedCategoriesList!.addAll(itemModel.categories!);
      if (firstTimeCategoryLoad) _categoryList!.addAll(itemModel.categories!);
      _pageSize = itemModel.totalSize;
      _isLoading = false;
    }
    update();
  }

  Future<void> getDiscountedItemList({
    required String offset,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool notify = false,
    bool firstTimeCategoryLoad = false,
  }) async {
    if (_searchController.text.isEmpty) {
      _isSearching = false;
      if (notify) update();
    } else {
      _isSearching = true;
      if (notify) update();
    }

    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _discountedItemList = null;
      if (firstTimeCategoryLoad) _categoryList = null;
      if (notify) update();
    }

    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);

      ItemModel? itemModel = await itemServiceInterface.getDiscountedItemList(
        type: _discountedType,
        source: dataSource,
        offset: _offset,
        search: _searchController.text,
        categoryIds: _selectedCategoryIds,
        filter: _filter,
        rating: _rating,
        minPrice: _selectedMinPrice,
        maxPrice: _selectedMaxPrice,
      );

      _prepareDiscountedItems(itemModel, offset, firstTimeCategoryLoad);

      if (dataSource == DataSourceEnum.local) {
        getDiscountedItemList(
          notify: notify,
          dataSource: DataSourceEnum.client,
          offset: '1',
        );
      }
    } else {
      if (isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  void _prepareDiscountedItems(
    ItemModel? itemModel,
    String offset,
    bool firstTimeCategoryLoad,
  ) {
    if (itemModel != null) {
      if (offset == '1') {
        _discountedItemList = [];
        if (firstTimeCategoryLoad) _categoryList = [];
      }
      _discountedItemList!.addAll(itemModel.items!);
      if (firstTimeCategoryLoad) _categoryList!.addAll(itemModel.categories!);
      _pageSize = itemModel.totalSize;
      _isLoading = false;
    }
    update();
  }

  Future<void> getFeaturedCategoriesItemList(
    bool reload,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _featuredCategoriesItem = null;
    }
    if (notify) {
      update();
    }
    if (_featuredCategoriesItem == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local) {
        _featuredCategoriesItem = await itemServiceInterface
            .getFeaturedCategoriesItemList(dataSource);
        update();
        getFeaturedCategoriesItemList(
          false,
          notify,
          dataSource: DataSourceEnum.client,
          fromRecall: true,
        );
      } else {
        _featuredCategoriesItem = await itemServiceInterface
            .getFeaturedCategoriesItemList(dataSource);
        update();
      }
    }
  }

  Future<void> getRecommendedItemList(
    bool reload,
    String type,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _recommendedItemList = null;
    }
    if (notify) {
      update();
    }
    if (_recommendedItemList == null || reload || fromRecall) {
      List<Item>? items;
      if (dataSource == DataSourceEnum.local) {
        items = await itemServiceInterface.getRecommendedItemList(
          type,
          dataSource,
        );
        _prepareRecommendedItems(items);

        getRecommendedItemList(
          false,
          type,
          notify,
          dataSource: DataSourceEnum.client,
          fromRecall: true,
        );
      } else {
        items = await itemServiceInterface.getRecommendedItemList(
          type,
          dataSource,
        );
        _prepareRecommendedItems(items);
      }
    }
  }

  _prepareRecommendedItems(List<Item>? items) {
    if (items != null) {
      _recommendedItemList = [];
      _recommendedItemList!.addAll(items);
      _isLoading = false;
    }
    update();
  }

  Future<void> getBasicMedicine(
    bool reload,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _basicMedicineModel = null;
    }
    if (notify) {
      update();
    }
    if (_basicMedicineModel == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local) {
        _basicMedicineModel = await itemServiceInterface.getBasicMedicine(
          DataSourceEnum.local,
        );
        _isLoading = false;
        update();
        getBasicMedicine(
          false,
          notify,
          fromRecall: true,
          dataSource: DataSourceEnum.client,
        );
      } else {
        _basicMedicineModel = await itemServiceInterface.getBasicMedicine(
          DataSourceEnum.client,
        );
        _isLoading = false;
        update();
      }
    }
  }

  Future<void> getConditionsWiseItem(int id, bool notify) async {
    _conditionWiseProduct = null;
    if (notify) {
      update();
    }
    List<Item>? items = await itemServiceInterface.getConditionsWiseItems(id);
    if (items != null) {
      _conditionWiseProduct = [];
      _conditionWiseProduct!.addAll(items);
      _isLoading = false;
    }
    update();
  }

  Future<void> getCommonConditions(bool notify) async {
    _commonConditions = [];
    if (notify) {
      update();
    }
    List<CommonConditionModel>? conditions =
        await itemServiceInterface.getCommonConditions();
    if (conditions != null) {
      _commonConditions!.addAll(conditions);
      _isLoading = false;
    }
    update();
  }

  Future<void> getItemDetails({required int itemId, CartModel? cart}) async {
    _item = null;
    _storeLogoUrl = null;
    _item = await itemServiceInterface.getItemDetails(itemId);
    if (_item != null) {
      initData(_item, cart);
      setExistInCart(_item, _selectedVariations);
      _fetchStoreLogo(_item!.storeId);
    }
    update();
  }

  Future<void> _fetchStoreLogo(int? storeId) async {
    if (storeId == null) return;
    try {
      if (Get.isRegistered<StoreController>()) {
        final storeController = Get.find<StoreController>();
        // If store is already loaded with matching ID, use its logo
        if (storeController.store != null &&
            storeController.store!.id == storeId) {
          _storeLogoUrl = storeController.store!.logoFullUrl;
          update();
          return;
        }
      }
      // Lightweight fetch: use store service directly
      final store = await Get.find<StoreController>().storeServiceInterface
          .getStoreDetails(
            storeId.toString(),
            false,
            '',
            Get.find<LocalizationController>().locale.languageCode,
            ModuleHelper.currentModuleId(),
          );
      if (store != null) {
        _storeLogoUrl = store.logoFullUrl;
        update();
      }
    } catch (_) {
      // Silently fail — letter fallback will show
    }
  }

  void initData(Item? item, CartModel? cart) {
    _variationIndex = [];
    _addOnQtyList = [];
    _addOnActiveList = [];
    _selectedVariations = [];
    _collapseVariation = [];
    if (cart != null) {
      _quantity = cart.quantity;
      _addOnActiveList.addAll(
        itemServiceInterface.initializeCartAddonActiveList(
          cart.addOnIds,
          item!.addOns,
        ),
      );
      _addOnQtyList.addAll(
        itemServiceInterface.initializeCartAddonsQtyList(
          cart.addOnIds,
          item.addOns,
        ),
      );

      if (ModuleHelper.getModuleConfig(item.moduleType).newVariation!) {
        _selectedVariations.addAll(cart.foodVariations!);
        _collapseVariation.addAll(
          itemServiceInterface.collapseVariation(item.foodVariations!),
        );
      } else {
        _variationIndex = itemServiceInterface.initializeCartVariationIndexes(
          cart.variation,
          item.choiceOptions,
        );
      }
    } else {
      if (ModuleHelper.getModuleConfig(item!.moduleType).newVariation!) {
        _selectedVariations.addAll(
          itemServiceInterface.initializeSelectedVariation(item.foodVariations),
        );
        _collapseVariation.addAll(
          itemServiceInterface.initializeCollapseVariation(item.foodVariations),
        );
      } else {
        _variationIndex = itemServiceInterface.initializeVariationIndexes(
          item.choiceOptions,
        );
      }
      _quantity = 1;
      _addOnActiveList.addAll(
        itemServiceInterface.initializeAddonActiveList(item.addOns),
      );
      _addOnQtyList.addAll(
        itemServiceInterface.initializeAddonQtyList(item.addOns),
      );

      setExistInCart(item, _selectedVariations, notify: true);
    }
  }

  void cartIndexSet() {
    _cartIndex = -1;
  }

  Future<int> setExistInCart(
    Item? item,
    List<List<bool?>>? selectedVariations, {
    bool notify = false,
  }) async {
    String variationType = await itemServiceInterface.prepareVariationType(
      item!.choiceOptions,
      _variationIndex,
    );

    if (ModuleHelper.getModuleConfig(
      ModuleHelper.getModule() != null
          ? ModuleHelper.getModule()!.moduleType
          : ModuleHelper.getCacheModule()!.moduleType,
    ).newVariation!) {
      _cartIndex = await itemServiceInterface.isExistInCartForBottomSheet(
        Get.find<CartController>().cartList,
        item.id,
        null,
        selectedVariations,
      );
    } else {
      _cartIndex = Get.find<CartController>().isExistInCart(
        item.id,
        variationType,
        false,
        null,
      );
    }

    if (_cartIndex != -1) {
      _quantity = Get.find<CartController>().cartList[_cartIndex].quantity;
      _addOnActiveList = itemServiceInterface.initializeCartAddonActiveList(
        Get.find<CartController>().cartList[_cartIndex].addOnIds,
        item.addOns,
      );
      _addOnQtyList = itemServiceInterface.initializeCartAddonsQtyList(
        Get.find<CartController>().cartList[_cartIndex].addOnIds,
        item.addOns,
      );
    } else {
      _quantity = 1;
    }
    if (notify) {
      update();
    }
    return _cartIndex;
  }

  void setAddOnQuantity(bool isIncrement, int index) {
    _addOnQtyList[index] = itemServiceInterface.setAddOnQuantity(
      isIncrement,
      _addOnQtyList[index]!,
    );
    update();
  }

  Future<void> setQuantity(
    bool isIncrement,
    int? stock,
    int? quantityLimit, {
    bool getxSnackBar = false,
  }) async {
    _quantity = await itemServiceInterface.setQuantity(
      isIncrement,
      Get.find<SplashController>().configModel.moduleConfig!.module!.stock!,
      stock,
      _quantity!,
      quantityLimit,
      getxSnackBar: getxSnackBar,
    );
    update();
  }

  void setCartVariationIndex(int index, int i, Item? item) {
    _variationIndex![index] = i;
    _quantity = 1;
    setExistInCart(item, _selectedVariations);
    update();
  }

  void showMoreSpecificSection(int index) {
    _collapseVariation[index] = !_collapseVariation[index];
    update();
  }

  void setNewCartVariationIndex(int index, int i, Item item) {
    _selectedVariations = itemServiceInterface.setNewCartVariationIndex(
      index,
      i,
      item.foodVariations!,
      _selectedVariations,
    );
    setExistInCart(item, _selectedVariations);
    // if(!item.foodVariations![index].multiSelect!) {
    //   for(int j = 0; j < _selectedVariations[index].length; j++) {
    //     if(item.foodVariations![index].required!){
    //       _selectedVariations[index][j] = j == i;
    //     }else{
    //       if(_selectedVariations[index][j]!){
    //         _selectedVariations[index][j] = false;
    //       }else{
    //         _selectedVariations[index][j] = j == i;
    //       }
    //     }
    //   }
    // } else {
    //   if(!_selectedVariations[index][i]! && selectedVariationLength(_selectedVariations, index) >= item.foodVariations![index].max!) {
    //     showCustomSnackBar(
    //       '${'maximum_variation_for'.tr} ${item.foodVariations![index].name} ${'is'.tr} ${item.foodVariations![index].max}',
    //       getXSnackBar: true,
    //     );
    //   }else {
    //     _selectedVariations[index][i] = !_selectedVariations[index][i]!;
    //   }
    // }
    update();
  }

  int selectedVariationLength(List<List<bool?>> selectedVariations, int index) {
    return itemServiceInterface.selectedVariationLength(
      selectedVariations,
      index,
    );
  }

  void addAddOn(bool isAdd, int index) {
    _addOnActiveList[index] = isAdd;
    update();
  }

  void setImageIndex(int index, bool notify) {
    _imageIndex = index;
    if (notify) {
      update();
    }
  }

  void setSelect(int select, bool notify) {
    _productSelect = select;
    if (notify) {
      update();
    }
  }

  void setImageSliderIndex(int index) {
    _imageSliderIndex = index;
    update();
  }

  double? getStartingPrice(Item item) {
    return itemServiceInterface.getStartingPrice(item);
  }

  bool isAvailable(Item item) {
    return DateConverter.isAvailable(
      item.availableTimeStarts,
      item.availableTimeEnds,
    );
  }

  double? getDiscount(Item item) => item.discount;

  String? getDiscountType(Item item) => item.discountType;

  void navigateToItemPage(
    Item? item,
    BuildContext context, {
    bool inStore = false,
    bool isCampaign = false,
  }) {
    if (Get.find<SplashController>()
            .configModel
            .moduleConfig!
            .module!
            .showRestaurantText! ||
        item!.moduleType == 'food') {
      Get.bottomSheet(
        ItemBottomSheet(
          itemId: item!.id!,
          inStorePage: inStore,
          isCampaign: isCampaign,
        ),
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
      );
    } else {
      Get.toNamed(
        RouteHelper.getItemDetailsRoute(item.id, inStore),
        arguments: ItemDetailsScreen(
          itemId: item.id!,
          inStorePage: inStore,
          isCampaign: isCampaign,
        ),
      );
    }
  }

  /// The "added to cart" toast, now off by default.
  ///
  /// Adding is self-evident: every surface that can add an item also shows the
  /// cart bar updating in front of the user, so the toast announced something
  /// already on screen while covering the content underneath it. Callers that
  /// genuinely have no visible cart affordance can still opt in by passing
  /// showToast: true.
  void _maybeCartToast(bool showToast) {
    if (showToast) showCartSnackBar();
  }

  /// Adds a variation-free item straight to the cart, with no detail fetch.
  ///
  /// Mirrors the simple-add branch of [itemDirectlyAddToCart] — including the
  /// cross-module and cross-store guards, which are correctness rules and must
  /// not be skipped for speed — but sources every field from the list item
  /// instead of a fresh network record.
  void _addSimpleItemToCart(Item item, {required bool showToast}) {
    final double price = item.price ?? 0;
    final double discount = item.discount ?? 0;
    final double discountPrice =
        PriceConverter.convertWithDiscount(
          price,
          discount,
          item.discountType,
        ) ??
        price;

    final CartModel cartModel = CartModel(
      null,
      price,
      discountPrice,
      [],
      [],
      (price - discountPrice),
      1,
      [],
      [],
      item.availableDateStarts != null,
      item.stock,
      item,
      item.quantityLimit,
    );

    final OnlineCart onlineCart = OnlineCart(
      null,
      item.id,
      null,
      price.toString(),
      '',
      null,
      ModuleHelper.getModuleConfig(item.moduleType).newVariation! ? [] : null,
      1,
      [],
      [],
      [],
      'Item',
    );

    final cartController = Get.find<CartController>();
    final splashController = Get.find<SplashController>();

    if (splashController.configModel.moduleConfig!.module!.stock! &&
        (item.stock ?? 0) <= 0) {
      showCustomSnackBar('out_of_stock'.tr);
      return;
    }

    final int? moduleId =
        ModuleHelper.getModule()?.id ?? ModuleHelper.getCacheModule()?.id;

    // Cross-module and cross-store conflicts still need confirmation — those
    // dialogs guard against silently wiping someone's basket.
    if (cartController.existAnotherModuleItem(moduleId)) {
      String currentModuleName = 'another category'.tr;
      if (cartController.cartList.isNotEmpty) {
        final cartModuleId = cartController.cartList.first.item?.moduleId;
        if (cartModuleId != null && splashController.moduleList != null) {
          currentModuleName =
              splashController.moduleList!
                  .firstWhereOrNull((m) => m.id == cartModuleId)
                  ?.moduleName ??
              currentModuleName;
        }
      }
      final newModuleName =
          splashController.module?.moduleName ??
          splashController.cacheModule?.moduleName ??
          'this category'.tr;

      Get.dialog(
        CartModuleConflictDialog(
          currentModuleName: currentModuleName,
          newModuleName: newModuleName,
          onClearCart: () {
            cartController.clearCartOnline().then((success) async {
              if (success) {
                await cartController.addToCartOnline(
                  onlineCart,
                  localFallback: cartModel,
                );
                Get.back();
                _maybeCartToast(showToast);
              }
            });
          },
          onCancel: () => Get.back(),
        ),
        barrierDismissible: false,
      );
      return;
    }

    if (cartController.existAnotherStoreItem(item.storeId, moduleId)) {
      Get.dialog(
        ConfirmationDialog(
          icon: Images.warning,
          title: 'are_you_sure_to_reset'.tr,
          description:
              splashController
                      .configModel
                      .moduleConfig!
                      .module!
                      .showRestaurantText!
                  ? 'if_you_continue'.tr
                  : 'if_you_continue_without_another_store'.tr,
          onYesPressed: () {
            cartController.clearCartOnline().then((success) async {
              if (success) {
                await cartController.addToCartOnline(
                  onlineCart,
                  localFallback: cartModel,
                );
                Get.back();
                _maybeCartToast(showToast);
              }
            });
          },
        ),
        barrierDismissible: false,
      );
      return;
    }

    cartController.addToCartOnline(onlineCart, localFallback: cartModel);
    _maybeCartToast(showToast);
  }

  /// [showToast] gates the "item added to cart" bar. Off by default.
  ///
  /// Adding is self-evident — every surface that adds an item also shows a cart
  /// bar updating in front of the user — so the toast restated what was already
  /// on screen while covering the content beneath it. Callers with no visible
  /// cart affordance can opt back in. See docs/food_store_add_feedback_plan.md.
  void itemDirectlyAddToCart(
    Item? item,
    BuildContext context, {
    bool inStore = false,
    bool isCampaign = false,
    bool showToast = false,
  }) {
    // FAST PATH — skip the getItemDetails round-trip.
    //
    // A tap on "+" used to fire THREE sequential network calls before the cart
    // could change: getItemDetails, then _fetchStoreLogo inside it, then
    // addToCartOnline. That is what made the bar feel laggy.
    //
    // The list item already carries everything the simple-add branch reads
    // (price, discount, discountType, stock, quantityLimit, moduleType,
    // variations, foodVariations) — the store screen's own menu row reads
    // `foodVariations` to decide its "customizable" label, so the data is
    // provably there. When the item has NO variations there is nothing the
    // detail call would add, so go straight to the cart.
    //
    // Anything customizable still takes the slow path: those need the full
    // record to build the options sheet.
    final bool simpleItem =
        (item?.variations?.isEmpty ?? false) &&
        (item?.foodVariations?.isEmpty ?? false) &&
        item?.price != null;

    if (simpleItem && !isCampaign) {
      _addSimpleItemToCart(item!, showToast: showToast);
      return;
    }

    getItemDetails(itemId: item!.id!).then((value) {
      final bool isFoodItem =
          ModuleType.of(_item?.moduleType) == ModuleType.food;
      if (((_item!.foodVariations != null && _item!.foodVariations!.isEmpty) &&
              isFoodItem) ||
          (_item?.variations != null &&
              _item!.variations!.isEmpty &&
              !isFoodItem)) {
        double price = _item!.price!;
        double discount = _item!.discount!;
        double discountPrice =
            PriceConverter.convertWithDiscount(
              price,
              discount,
              _item!.discountType,
            )!;

        CartModel cartModel = CartModel(
          null,
          price,
          discount,
          [],
          [],
          (price - discountPrice),
          1,
          [],
          [],
          isCampaign,
          _item?.stock,
          _item,
          _item?.quantityLimit,
        );

        OnlineCart onlineCart = OnlineCart(
          null,
          isCampaign ? null : _item?.id,
          isCampaign ? _item?.id : null,
          price.toString(),
          '',
          null,
          ModuleHelper.getModuleConfig(_item?.moduleType).newVariation!
              ? []
              : null,
          1,
          [],
          [],
          [],
          'Item',
        );
        if (Get.find<SplashController>()
                .configModel
                .moduleConfig!
                .module!
                .stock! &&
            _item!.stock! <= 0) {
          showCustomSnackBar('out_of_stock'.tr);
        }
        // First check for different module
        else if (Get.find<CartController>().existAnotherModuleItem(
          ModuleHelper.getModule()?.id ?? ModuleHelper.getCacheModule()?.id,
        )) {
          // Get module names for the dialog
          final cartController = Get.find<CartController>();
          final splashController = Get.find<SplashController>();

          // Get current cart module name
          String currentModuleName = 'another category'.tr;
          if (cartController.cartList.isNotEmpty) {
            final cartModuleId = cartController.cartList.first.item?.moduleId;
            if (cartModuleId != null && splashController.moduleList != null) {
              final cartModule = splashController.moduleList!.firstWhereOrNull(
                (m) => m.id == cartModuleId,
              );
              currentModuleName =
                  cartModule?.moduleName ?? 'another category'.tr;
            }
          }

          // Get new module name
          final newModuleName =
              splashController.module?.moduleName ??
              splashController.cacheModule?.moduleName ??
              'this category'.tr;

          Get.dialog(
            CartModuleConflictDialog(
              currentModuleName: currentModuleName,
              newModuleName: newModuleName,
              onClearCart: () {
                Get.find<CartController>().clearCartOnline().then((
                  success,
                ) async {
                  if (success) {
                    await Get.find<CartController>().addToCartOnline(
                      onlineCart,
                      localFallback: cartModel,
                    );
                    Get.back();
                    _maybeCartToast(showToast);
                  }
                });
              },
              onCancel: () => Get.back(),
            ),
            barrierDismissible: false,
          );
        } else if (Get.find<CartController>().existAnotherStoreItem(
          cartModel.item!.storeId,
          ModuleHelper.getModule() != null
              ? ModuleHelper.getModule()?.id
              : ModuleHelper.getCacheModule()?.id,
        )) {
          Get.dialog(
            ConfirmationDialog(
              icon: Images.warning,
              title: 'are_you_sure_to_reset'.tr,
              description:
                  Get.find<SplashController>()
                          .configModel
                          .moduleConfig!
                          .module!
                          .showRestaurantText!
                      ? 'if_you_continue'.tr
                      : 'if_you_continue_without_another_store'.tr,
              onYesPressed: () {
                Get.find<CartController>().clearCartOnline().then((
                  success,
                ) async {
                  if (success) {
                    await Get.find<CartController>().addToCartOnline(
                      onlineCart,
                      localFallback: cartModel,
                    );
                    Get.back();
                    _maybeCartToast(showToast);
                  }
                });
              },
            ),
            barrierDismissible: false,
          );
        } else {
          Get.find<CartController>().addToCartOnline(
            onlineCart,
            localFallback: cartModel,
          );
          _maybeCartToast(showToast);
        }
      } else if (Get.find<SplashController>()
              .configModel
              .moduleConfig!
              .module!
              .showRestaurantText! ||
          ModuleType.of(_item?.moduleType) == ModuleType.food) {
        Get.bottomSheet(
          ItemBottomSheet(
            itemId: _item!.id!,
            inStorePage: inStore,
            isCampaign: isCampaign,
          ),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
        );
      } else {
        Get.toNamed(
          RouteHelper.getItemDetailsRoute(_item!.id, inStore),
          arguments: ItemDetailsScreen(
            itemId: _item!.id!,
            inStorePage: inStore,
          ),
        );
      }
    });
  }
}
