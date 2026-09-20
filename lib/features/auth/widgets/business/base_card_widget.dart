import 'package:waddy_app/features/auth/controllers/store_registration_controller.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class BaseCardWidget extends StatelessWidget {
  final StoreRegistrationController storeRegistrationController;
  final String title;
  final String? description;
  final int index;
  final Function onTap;
  const BaseCardWidget({
    super.key,
    required this.storeRegistrationController,
    required this.title,
    required this.index,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap as void Function()?,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              color:
                  storeRegistrationController.businessIndex == index
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                      : Theme.of(context).cardColor,
              border: Border.all(
                color:
                    storeRegistrationController.businessIndex == index
                        ? Theme.of(context).primaryColor
                        : Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.5),
                width: 0.5,
              ),
              boxShadow:
                  storeRegistrationController.businessIndex == index
                      ? null
                      : [
                        BoxShadow(
                          color: Colors.grey[200]!,
                          offset: const Offset(5, 5),
                          blurRadius: 10,
                        ),
                      ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    style: waddyMedium.copyWith(
                      color:
                          storeRegistrationController.businessIndex == index
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).textTheme.bodyLarge?.color
                                  ?.withValues(alpha: 0.7),
                      fontSize: Dimensions.fontSizeDefault,
                      fontWeight:
                          storeRegistrationController.businessIndex == index
                              ? FontWeight.w600
                              : FontWeight.w400,
                    ),
                  ),
                ),

                SizedBox(height: 0),

                const SizedBox(),
              ],
            ),
          ),

          storeRegistrationController.businessIndex == index
              ? Positioned(
                top: -10,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.all(
                    Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: Theme.of(context).cardColor,
                  ),
                ),
              )
              : const SizedBox(),
        ],
      ),
    );
  }
}
