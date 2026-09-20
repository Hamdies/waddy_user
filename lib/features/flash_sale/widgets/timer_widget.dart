import 'package:flutter/material.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class TimerWidget extends StatelessWidget {
  final int timeCount;
  final String timeUnit;
  const TimerWidget({
    super.key,
    required this.timeUnit,
    required this.timeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          ),
          child: Text(
            timeCount > 9 ? timeCount.toString() : '0${timeCount.toString()}',
            style: waddyBold.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(
          timeUnit,
          style: waddyRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
