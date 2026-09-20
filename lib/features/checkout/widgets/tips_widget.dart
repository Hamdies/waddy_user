import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class TipsWidget extends StatelessWidget {
  final String title;
  final bool isSelected;
  final Function onTap;
  final bool isSuggested;
  const TipsWidget({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.isSuggested,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: Dimensions.paddingSizeSmall,
        top: Dimensions.paddingSizeExtraSmall,
        bottom: 0,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap as void Function()?,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeExtraSmall,
                horizontal: Dimensions.paddingSizeSmall,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                border: Border.all(color: Theme.of(context).cardColor),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    spreadRadius: 0.5,
                    blurRadius: 0.5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Text(
                      title,
                      textDirection: TextDirection.ltr,
                      style: waddyRegular.copyWith(
                        color:
                            isSelected
                                ? Theme.of(context).cardColor
                                : Theme.of(context).disabledColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall - 1),

          isSuggested
              ? Text(
                'most_tipped'.tr,
                style: waddyMedium.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontSize: Dimensions.fontSizeExtraSmall,
                ),
              )
              : const SizedBox(),
        ],
      ),
    );
  }
}
