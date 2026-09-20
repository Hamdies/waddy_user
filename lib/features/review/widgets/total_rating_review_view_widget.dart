import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class TotalRatingReviewViewWidget extends StatelessWidget {
  final bool isRating;
  final int totalNumber;
  const TotalRatingReviewViewWidget({
    super.key,
    required this.totalNumber,
    required this.isRating,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
        margin: null,
        decoration: BoxDecoration(
          color: Theme.of(context).hintColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Text(
          '$totalNumber ${isRating ? 'ratings'.tr : 'reviews'.tr}',
          textAlign: TextAlign.center,
          style: waddyRegular.copyWith(
            fontSize: 8,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge!.color?.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
