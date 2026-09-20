import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeliveryManWidget extends StatelessWidget {
  final DeliveryMan? deliveryMan;
  const DeliveryManWidget({super.key, required this.deliveryMan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[Get.isDarkMode ? 700 : 300]!,
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'delivery_man'.tr,
            style: waddyRegular.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
            ),
          ),
          ListTile(
            leading: ClipOval(
              child: CustomImage(
                image: '${deliveryMan!.imageFullUrl}',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              '${deliveryMan!.fName} ${deliveryMan!.lName}',
              style: waddyRegular.copyWith(fontSize: Dimensions.fontSizeLarge),
            ),
            subtitle: RatingBar(
              rating: deliveryMan!.avgRating,
              size: 15,
              ratingCount: deliveryMan!.ratingCount ?? 0,
            ),
          ),
        ],
      ),
    );
  }
}
