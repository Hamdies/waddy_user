import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:url_launcher/url_launcher_string.dart';

class StoreBannerWidget extends StatelessWidget {
  final StorePageController storeController;
  const StoreBannerWidget({super.key, required this.storeController});

  @override
  Widget build(BuildContext context) {
    return (storeController.storeBanners != null &&
            storeController.storeBanners!.isNotEmpty)
        ? Container(
          height: context.width * 0.3,
          width: double.infinity,
          // The section gap lives here, not around the widget: wrapped in
          // padding, an empty banner slot still pushed the next section 24pt
          // down — the dead band above the first aisle panel.
          margin: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            32,
            Dimensions.paddingSizeDefault,
            0,
          ),
          child: CarouselSlider.builder(
            options: CarouselOptions(
              autoPlay: true,
              enlargeCenterPage: true,
              disableCenter: true,
              viewportFraction: 1,
              autoPlayInterval: const Duration(seconds: 4),
            ),
            itemCount: storeController.storeBanners!.length,
            itemBuilder: (context, index, _) {
              return InkWell(
                onTap: () async {
                  String url =
                      storeController.storeBanners![index].defaultLink!;
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    showCustomSnackBar('unable_to_found_url'.tr);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  child: CustomImage(
                    image:
                        '${storeController.storeBanners![index].imageFullUrl}',
                  ),
                ),
              );
            },
          ),
        )
        : const SizedBox();
  }
}
