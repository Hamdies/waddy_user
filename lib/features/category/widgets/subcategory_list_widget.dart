import 'package:flutter/material.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class SubcategoryListWidget extends StatelessWidget {
  final CategoryController catController;
  final String? categoryID;
  final Key? scaffoldKey;
  final double? width;

  const SubcategoryListWidget({
    super.key,
    required this.catController,
    required this.categoryID,
    this.scaffoldKey,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (catController.subCategoryList == null || catController.isSearching) {
      return const SizedBox();
    }

    return Center(
      child: Container(
        height: 40,
        width: width,
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
        child: ListView.builder(
          key: scaffoldKey,
          scrollDirection: Axis.horizontal,
          itemCount: catController.subCategoryList!.length,
          padding: const EdgeInsets.only(left: Dimensions.paddingSizeSmall),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () => catController.setSubCategoryIndex(index, categoryID),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
                margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  color: index == catController.subCategoryIndex
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      catController.subCategoryList![index].name!,
                      style: index == catController.subCategoryIndex
                          ? robotoMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).primaryColor,
                            )
                          : robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
