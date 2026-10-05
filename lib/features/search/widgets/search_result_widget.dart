import 'package:waddy_app/features/search/controllers/search_controller.dart'
    as search;
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/search/widgets/filter_widget.dart';
import 'package:waddy_app/features/search/widgets/item_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchResultWidget extends StatefulWidget {
  final String searchText;
  final TabController? tabController;
  const SearchResultWidget({
    super.key,
    required this.searchText,
    this.tabController,
  });

  @override
  SearchResultWidgetState createState() => SearchResultWidgetState();
}

class SearchResultWidgetState extends State<SearchResultWidget>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    if (widget.tabController != null) {
      _tabController = widget.tabController;
    } else {
      _tabController = TabController(length: 2, initialIndex: 0, vsync: this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GetBuilder<search.SearchController>(
          builder: (searchController) {
            bool isNull = true;
            int length = 0;
            if (searchController.isStore) {
              isNull = searchController.searchStoreList == null;
              if (!isNull) {
                length = searchController.searchStoreList!.length;
              }
            } else {
              isNull = searchController.searchItemList == null;
              if (!isNull) {
                length = searchController.searchItemList!.length;
              }
            }
            return isNull
                ? const SizedBox()
                : Center(
                  child: SizedBox(
                    width: Dimensions.maxContentWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeDefault,
                        Dimensions.paddingSizeExtraSmall,
                        Dimensions.paddingSizeDefault,
                        Dimensions.paddingSizeSmall,
                      ),
                      child: Row(
                        children: [
                          // "12 results" as one muted line. The count used to be set in bold
                          // primary against a grey label, which gave the loudest colour on
                          // the screen to a number nobody came here to read — the results
                          // themselves are what should carry weight.
                          Expanded(
                            child: Text(
                              '$length ${'results'.tr}',
                              textDirection: TextDirection.ltr,
                              style: waddyMedium.copyWith(
                                color: const Color(0xFF6B7876),
                                fontSize: Dimensions.fontSizeExtraSmall,
                              ),
                            ),
                          ),
                          (widget.searchText.isNotEmpty)
                              ? InkWell(
                                onTap: () {
                                  List<double?> prices = [];
                                  if (!Get.find<search.SearchController>()
                                      .isStore) {
                                    for (var product
                                        in Get.find<search.SearchController>()
                                            .allItemList!) {
                                      prices.add(product.price);
                                    }
                                    prices.sort();
                                  }
                                  double? maxValue =
                                      prices.isNotEmpty
                                          ? prices[prices.length - 1]
                                          : 1000;
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder:
                                        (_) => FilterWidget(
                                          maxValue: maxValue,
                                          isStore:
                                              Get.find<
                                                    search.SearchController
                                                  >()
                                                  .isStore,
                                        ),
                                  );
                                },
                                child: const Icon(Icons.filter_list),
                              )
                              : const SizedBox(),
                        ],
                      ),
                    ),
                  ),
                );
          },
        ),

        Center(
          child: Container(
            width: Dimensions.maxContentWidth,
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).disabledColor,
              unselectedLabelStyle: waddyRegular.copyWith(
                color: Theme.of(context).disabledColor,
                fontSize: Dimensions.fontSizeSmall,
              ),
              labelStyle: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).primaryColor,
              ),

              tabs: [
                Tab(text: 'item'.tr),
                Tab(
                  text:
                      Get.find<SplashController>()
                                  .configModel
                                  .moduleConfig!
                                  .module!
                                  .showRestaurantText ??
                              false
                          ? 'restaurants'.tr
                          : 'stores'.tr,
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: NotificationListener(
            onNotification: (dynamic scrollNotification) {
              if (scrollNotification is ScrollEndNotification) {
                Get.find<search.SearchController>().setStore(
                  _tabController!.index == 1,
                );
                Get.find<search.SearchController>().searchData(
                  widget.searchText,
                  false,
                );
              }
              return false;
            },
            child: TabBarView(
              controller: _tabController,
              children: const [
                ItemViewWidget(isItem: false),
                ItemViewWidget(isItem: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
