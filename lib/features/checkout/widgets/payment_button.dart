import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';

class PaymentButton extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Function onTap;
  const PaymentButton({
    super.key,
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: InkWell(
        onTap: onTap as void Function()?,
        child: Stack(
          children: [
            // Material rather than a coloured Container: ListTile paints its
            // background and ink splash onto the nearest Material ancestor, so
            // a Container in between hides both. On a payment-method selector
            // that means a row the user taps with no feedback at all.
            //
            // Material carries the colour, the radius and the elevation
            // shadow, so the visual is unchanged — the splash now lands on it.
            Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              elevation: 2,
              shadowColor: Colors.black12,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtraSmall,
                ),
                leading: Image.asset(
                  icon,
                  width: 30,
                  height: 30,
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).disabledColor,
                ),
                title: Text(
                  title,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            Positioned(
              top: 0,
              bottom: 0,
              right: 5,
              child:
                  isSelected
                      ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                      )
                      : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
