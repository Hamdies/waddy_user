import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/favourite/widgets/empty_favourites_view.dart';
import 'package:waddy_app/features/favourite/widgets/favourite_item_card.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FavItemViewWidget extends StatelessWidget {
  final bool isStore;
  final bool isSearch;
  const FavItemViewWidget({
    super.key,
    required this.isStore,
    this.isSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<FavouriteController>(
        builder: (favouriteController) {
          // Check if favorites list is empty
          bool isEmpty =
              isStore
                  ? (favouriteController.wishStoreList == null ||
                      favouriteController.wishStoreList!.isEmpty)
                  : (favouriteController.wishItemList == null ||
                      favouriteController.wishItemList!.isEmpty);

          return RefreshIndicator(
            onRefresh: () async {
              await favouriteController.getFavouriteList();
            },
            child:
                isEmpty
                    ? EmptyFavouritesView(isStore: isStore)
                    : isStore
                    ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: FooterView(
                        child: SizedBox(
                          width: Dimensions.maxContentWidth,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 80.0),
                            child: ItemsView(
                              isStore: isStore,
                              items: null,
                              stores: favouriteController.wishStoreList,
                              noDataText: 'no_wish_data_found'.tr,
                              isFeatured: true,
                            ),
                          ),
                        ),
                      ),
                    )
                    : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: FooterView(
                        child: SizedBox(
                          width: Dimensions.maxContentWidth,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeDefault,
                              80.0,
                            ),
                            child: Column(
                              children: List.generate(
                                favouriteController.wishItemList?.length ?? 0,
                                (index) {
                                  final item =
                                      favouriteController.wishItemList?[index];
                                  if (item == null) return const SizedBox();
                                  return FavouriteItemCard(
                                    item: item,
                                    store:
                                        (favouriteController
                                                    .wishStoreList
                                                    ?.isNotEmpty ??
                                                false)
                                            ? favouriteController.wishStoreList!
                                                .firstWhere(
                                                  (store) =>
                                                      store?.id == item.storeId,
                                                  orElse:
                                                      () =>
                                                          favouriteController
                                                              .wishStoreList!
                                                              .first,
                                                )
                                            : null,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
          );
        },
      ),
    );
  }
}
