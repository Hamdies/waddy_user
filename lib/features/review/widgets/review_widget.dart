import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/rating_bar.dart';
import 'package:waddy_app/common/widgets/readmore_widget.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/review/domain/models/review_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReviewWidget extends StatelessWidget {
  final ReviewModel review;
  final bool hasDivider;
  final String? storeName;
  const ReviewWidget({
    super.key,
    required this.review,
    required this.hasDivider,
    this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.customerName ?? '', style: waddyMedium),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  RatingBar(
                    rating: review.rating!.toDouble(),
                    ratingCount: null,
                    size: 18,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  const SizedBox(),
                  SizedBox(height: 0),

                  Text(
                    DateConverter.stringToLocalDateOnly(review.createdAt!),
                    style: waddyRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 0),

            InkWell(
              onTap: () {
                Get.find<ItemController>().navigateToItemPage(
                  review.item,
                  context,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  border: Border.all(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    SizedBox(
                      width: 70,
                      child: Text(
                        review.itemName ?? '',
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                      child: CustomImage(
                        image: review.itemImageFullUrl ?? '',
                        height: 45,
                        width: 45,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),

        ReadMoreText(
          review.comment ?? '',
          style: waddyRegular.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
          ),
          trimMode: TrimMode.Line,
          trimLines: 3,
          colorClickableText: Theme.of(context).primaryColor,
          lessStyle: waddyBold.copyWith(color: Theme.of(context).primaryColor),
          trimCollapsedText: 'show_more'.tr,
          trimExpandedText: ' ${'show_less'.tr}',
          moreStyle: waddyBold.copyWith(color: Theme.of(context).primaryColor),
        ),
        SizedBox(height: Dimensions.paddingSizeSmall),

        review.reply != null
            ? Container(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeDefault,
                horizontal: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(storeName ?? '', style: waddyMedium),

                      Text(
                        DateConverter.stringToLocalDateOnly(review.updatedAt!),
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),

                  ReadMoreText(
                    review.reply ?? '',
                    style: waddyRegular.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
                    ),
                    trimMode: TrimMode.Line,
                    trimLines: 3,
                    colorClickableText: Theme.of(context).primaryColor,
                    lessStyle: waddyBold.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                    trimCollapsedText: 'show_more'.tr,
                    trimExpandedText: ' ${'show_less'.tr}',
                    moreStyle: waddyBold.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            )
            : const SizedBox(),

        hasDivider
            ? Divider(
              height: 40,
              thickness: 1,
              color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
            )
            : const SizedBox(),
      ],
    );
  }
}
