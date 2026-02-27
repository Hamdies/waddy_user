import 'package:get/get.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final Function? onPressed;
  final String buttonText;
  final bool transparent;
  final EdgeInsets? margin;
  final double? height;
  final double? width;
  final double? fontSize;
  final double radius;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isLoading;
  final bool isBold;
  final bool isBorder;
  const CustomButton({
    super.key,
    this.onPressed,
    required this.buttonText,
    this.transparent = false,
    this.margin,
    this.width,
    this.height,
    this.fontSize,
    this.radius = 30,
    this.icon,
    this.color,
    this.textColor,
    this.isLoading = false,
    this.isBold = true,
    this.isBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    final Color buttonColor = isDisabled
        ? Theme.of(context).disabledColor
        : transparent
            ? Colors.transparent
            : color ?? Theme.of(context).primaryColor;

    return Center(
      child: SizedBox(
        width: width ?? Dimensions.webMaxWidth,
        child: Padding(
          padding: margin ?? EdgeInsets.zero,
          child: GestureDetector(
            onTap: isLoading || isDisabled ? null : onPressed as void Function()?,
            child: Container(
              height: height ?? 50,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: transparent
                      ? Theme.of(context).primaryColor.withOpacity(0.4)
                      : Theme.of(context).secondaryHeaderColor.withOpacity(0.4),
                  width: 0.5,
                ),
                boxShadow: transparent || isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: Theme.of(context).secondaryHeaderColor,
                          blurRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 15,
                            width: 15,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Text(
                            'loading'.tr,
                            style: robotoMedium.copyWith(color: Colors.white),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon != null
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    right: Dimensions.paddingSizeExtraSmall,
                                  ),
                                  child: Icon(
                                    icon,
                                    color: transparent
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).cardColor,
                                  ),
                                )
                              : const SizedBox(),
                          Text(
                            buttonText,
                            textAlign: TextAlign.center,
                            style: isBold
                                ? robotoBold.copyWith(
                                    color: textColor ??
                                        (transparent
                                            ? Theme.of(context).primaryColor
                                            : Colors.white),
                                    fontSize:
                                        fontSize ?? Dimensions.fontSizeLarge,
                                  )
                                : robotoRegular.copyWith(
                                    color: textColor ??
                                        (transparent
                                            ? Theme.of(context).primaryColor
                                            : Colors.white),
                                    fontSize:
                                        fontSize ?? Dimensions.fontSizeLarge,
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
