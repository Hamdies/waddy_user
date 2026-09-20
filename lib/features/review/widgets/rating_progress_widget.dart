import 'package:waddy_app/util/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/util/styles.dart';

class RatingProgressWidget extends StatelessWidget {
  final String ratingNumber;
  final double ratingPercent;
  final double progressValue;
  const RatingProgressWidget({
    super.key,
    required this.ratingNumber,
    required this.ratingPercent,
    required this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          ratingNumber,
          style: waddyMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        Expanded(
          child: LinearProgressIndicator(
            minHeight: Dimensions.paddingSizeExtraSmall,
            value: progressValue,
            backgroundColor: Theme.of(context).hintColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),

        Container(
          alignment: Alignment.centerRight,
          width: 30,
          child: Text(
            '${ratingPercent.toStringAsFixed(0)}%',
            style: waddyMedium.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium!.color?.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
