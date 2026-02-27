import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/item_view.dart';
import 'package:sixam_mart/common/widgets/paginated_list_view.dart';
import 'package:sixam_mart/features/store/widgets/bottom_cart_widget.dart';
import 'package:sixam_mart/features/store/widgets/filter_widget.dart';
import 'package:sixam_mart/helper/route_helper.dart';

/// Screen that shows all items from a specific category within a store.
/// The category is pre-selected via [categoryIndex] on the StoreController
/// before navigating here.
class StoreCategoryItemsScreen extends StatefulWidget {
  final int? storeId;
  final String categoryName;

  const StoreCategoryItemsScreen({
    super.key,
    required this.storeId,
    required this.categoryName,
  });

  @override
  State<StoreCategoryItemsScreen> createState() => _StoreCategoryItemsScreenState();
}

class _StoreCategoryItemsScreenState extends State<StoreCategoryItemsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return GetBuilder<StoreController>(builder: (storeController) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              // ─── App Bar ───
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 10),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: primaryColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.categoryName,
                        style: robotoBold.copyWith(fontSize: 20, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Search Bar + Filter ───
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Get.toNamed(RouteHelper.getSearchStoreItemRoute(widget.storeId)),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                              const SizedBox(width: 10),
                              Text(
                                'search_for_items'.tr,
                                style: robotoRegular.copyWith(fontSize: 14, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final maxPrice = (storeController.storeItemModel?.items ?? [])
                            .fold<double>(0, (prev, item) => (item.price ?? 0) > prev ? item.price! : prev);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => FilterWidget(maxValue: maxPrice > 0 ? maxPrice : 1000),
                        );
                      },
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                        ),
                        child: Icon(Icons.tune_rounded, size: 20, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Item List ───
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: SizedBox(
                    width: Dimensions.webMaxWidth,
                    child: PaginatedListView(
                      scrollController: _scrollController,
                      onPaginate: (int? offset) => storeController.getStoreItemList(
                        widget.storeId,
                        offset!,
                        storeController.type,
                        false,
                      ),
                      totalSize: storeController.storeItemModel?.totalSize,
                      offset: storeController.storeItemModel?.offset,
                      itemView: ItemsView(
                        isStore: false,
                        stores: null,
                        items: storeController.storeItemModel?.items,
                        inStorePage: true,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: GetBuilder<CartController>(builder: (cartController) {
          return cartController.cartList.isNotEmpty && !ResponsiveHelper.isDesktop(context)
              ? const BottomCartWidget()
              : const SizedBox();
        }),
      );
    });
  }
}
