import 'package:lottie/lottie.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';

class NoDataScreen extends StatelessWidget {
  final bool isCart;
  final bool showFooter;
  final String? text;
  final bool fromAddress;
  const NoDataScreen({super.key, required this.text, this.isCart = false, this.showFooter = false, this.fromAddress = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: FooterView(
        visibility: showFooter,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [

          Center(
            child: Lottie.asset(
              fromAddress ? Images.address : isCart ? Images.address : Images.address,
              width: MediaQuery.of(context).size.height*0.5, height: MediaQuery.of(context).size.height*0.3,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height*0.03),

          Text(
            isCart ? 'cart_is_empty'.tr : text!,
            style: robotoMedium.copyWith(fontSize: 17, color: fromAddress ? Theme.of(context).textTheme.bodyMedium!.color : Theme.of(context).disabledColor),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: MediaQuery.of(context).size.height*0.03),

          fromAddress ? Text(
            'please_add_your_address_for_your_better_experience'.tr,
            style: robotoMedium.copyWith(fontSize: MediaQuery.of(context).size.height*0.0175, color: Theme.of(context).disabledColor),
            textAlign: TextAlign.center,
          ) : const SizedBox(),
          SizedBox(height: MediaQuery.of(context).size.height*0.05),

          const SizedBox(),

        ]),
      ),
    );
  }
}
