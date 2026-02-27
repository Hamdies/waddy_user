import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/common/widgets/custom_ink_well.dart';
import 'package:sixam_mart/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/features/home/widgets/components/flash_sale_card_widget.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/features/flash_sale/widgets/timer_widget.dart';
import 'package:sixam_mart/features/flash_sale/widgets/flash_sale_timer_view_widget.dart';

class FlashSaleViewWidget extends StatefulWidget {
  const FlashSaleViewWidget({super.key});

  @override
  State<FlashSaleViewWidget> createState() => _FlashSaleViewWidgetState();
}

class _FlashSaleViewWidgetState extends State<FlashSaleViewWidget> {

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (homeController) {
        final isRamadanMode = homeController.isRamadanCelebrationActive;
        
        return GetBuilder<FlashSaleController>(builder: (flashSaleController) {
          Item? item;
          int stock = 0;
          int remaining = 0;
          int sold = 0;
          if(flashSaleController.flashSaleModel != null && flashSaleController.flashSaleModel!.activeProducts != null) {
            int index = flashSaleController.flashSaleModel!.activeProducts!.length > 1 ? flashSaleController.pageIndex : 0;
            item = flashSaleController.flashSaleModel!.activeProducts![index].item;
            stock = flashSaleController.flashSaleModel!.activeProducts![index].stock!;
            sold = flashSaleController.flashSaleModel!.activeProducts![index].sold!;
            remaining = stock - sold;
          }
          
          if (flashSaleController.flashSaleModel == null) {
            return const FlashSaleShimmerView();
          }
          
          if (flashSaleController.flashSaleModel!.activeProducts == null || 
              flashSaleController.duration!.inSeconds <= 1) {
            return const SizedBox();
          }

          // Ramadan themed colors
          const ramadanGold = Color(0xFFD4AF37);
          const ramadanTeal = Color(0xFF0D7C66);
          const ramadanDarkTeal = Color(0xFF0A5F51);
          
          return Container(
            width: Get.width,
            margin: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              gradient: isRamadanMode 
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFBF5), Color(0xFFFFF8E7)],
                  )
                : null,
              color: isRamadanMode ? null : Theme.of(context).primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: isRamadanMode 
                  ? ramadanGold.withValues(alpha: 0.4) 
                  : Theme.of(context).primaryColor.withValues(alpha: 0.2),
                width: isRamadanMode ? 1.5 : 1,
              ),
              boxShadow: isRamadanMode ? [
                BoxShadow(
                  color: ramadanTeal.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ] : null,
            ),
            child: Column(children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: isRamadanMode ? const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ramadanTeal, ramadanDarkTeal],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(Dimensions.radiusDefault - 1),
                    topRight: Radius.circular(Dimensions.radiusDefault - 1),
                  ),
                ) : null,
                child: CustomInkWell(
                  onTap: () => Get.toNamed(RouteHelper.getFlashSaleDetailsScreen(flashSaleController.flashSaleModel!.activeProducts![0].flashSaleId!)),
                  radius: Dimensions.paddingSizeSmall,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Row(children: [
                      if (isRamadanMode) ...[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ramadanGold.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flash_on_rounded,
                            color: ramadanGold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'flash_sale'.tr, 
                          style: robotoBold.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: isRamadanMode ? ramadanGold : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'limited_time_offer'.tr, 
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall, 
                            color: isRamadanMode 
                              ? Colors.white.withValues(alpha: 0.8) 
                              : Theme.of(context).disabledColor,
                          ),
                        ),
                      ]),
                    ]),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isRamadanMode 
                          ? ramadanGold.withValues(alpha: 0.2) 
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isRamadanMode ? Border.all(
                          color: ramadanGold.withValues(alpha: 0.5),
                        ) : null,
                      ),
                      child: Text(
                        'see_all'.tr, 
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall, 
                          color: isRamadanMode 
                            ? ramadanGold 
                            : Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              // Timer section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  if (isRamadanMode) ...[
                    Icon(Icons.nightlight_round, color: ramadanGold.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 8),
                  ],
                  FlashSaleTimerView(eventDuration: flashSaleController.duration),
                  if (isRamadanMode) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.nightlight_round, color: ramadanGold.withValues(alpha: 0.7), size: 16),
                  ],
                ]),
              ),

              // Product card
              flashSaleController.flashSaleModel!.activeProducts != null
                ? FlashSaleCard(
                activeProducts: flashSaleController.flashSaleModel!.activeProducts!,
                soldOut: remaining == 0,
              ) : const SizedBox(),

              // Product name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                child: Text(
                  "${item!.name}", 
                  style: robotoMedium.copyWith(
                    color: isRamadanMode ? const Color(0xFF2D3436) : null,
                  ), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, 
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              // Unit type
              (Get.find<SplashController>().configModel!.moduleConfig!.module!.unit! && item.unitType != null) ? Text(
                '(${ item.unitType ?? ''})',
                style: robotoRegular.copyWith(color: Theme.of(context).disabledColor),
              ) : const SizedBox(),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              // Price section
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                item.discount != null && item.discount! > 0  ? Flexible(child: Text(
                  PriceConverter.convertPrice(Get.find<ItemController>().getStartingPrice(item)),
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall, 
                    color: Theme.of(context).disabledColor,
                    decoration: TextDecoration.lineThrough,
                  ), textDirection: TextDirection.ltr,
                )) : const SizedBox(),
                SizedBox(width: item.discount != null && item.discount! > 0 ? Dimensions.paddingSizeExtraSmall : 0),

                Flexible(child: Text(
                  PriceConverter.convertPrice(
                    Get.find<ItemController>().getStartingPrice(item), discount: item.discount,
                    discountType: item.discountType,
                  ),
                  textDirection: TextDirection.ltr, 
                  style: robotoBold.copyWith(
                    color: isRamadanMode ? ramadanTeal : Theme.of(context).primaryColor,
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                )),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                child: SizedBox(
                  width: Get.width * 0.7,
                  child: Stack(
                    children: [
                      Builder(
                        builder: (context) {
                          bool bothZero = remaining == 0 && stock == 0;
                          return Container(
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                              gradient: isRamadanMode 
                                ? LinearGradient(
                                    colors: [
                                      ramadanTeal.withValues(alpha: 0.2),
                                      ramadanGold.withValues(alpha: 0.2),
                                    ],
                                  )
                                : null,
                              color: isRamadanMode ? null : Theme.of(context).primaryColor.withValues(alpha: 0.15),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                              child: LinearProgressIndicator(
                                minHeight: 18,
                                value: bothZero ? 0 : remaining / stock,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isRamadanMode ? ramadanTeal : Theme.of(context).primaryColor,
                                ),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          );
                        }
                      ),

                      Positioned.fill(
                        child: Center(
                          child: Text(
                            '${'sold'.tr} $sold/$stock',
                            style: robotoMedium.copyWith(
                              color: Colors.white, 
                              fontSize: Dimensions.fontSizeSmall,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ]),
          );
        });
      },
    );
  }
}

class FlashSaleShimmerView extends StatelessWidget {
  const FlashSaleShimmerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width, height: ResponsiveHelper.isDesktop(context) ? 330 : 350,
      margin: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Shimmer(
        duration: const Duration(seconds: 2),
        enabled: true,
        child: Column(children: [

          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('flash_sale'.tr, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                ResponsiveHelper.isDesktop(context) ? const SizedBox() : Text('limited_time_offer'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor)),
              ],
              ),
              const Spacer(),

              Row(children: [

                TimerWidget(
                  timeCount: 00,
                  timeUnit: 'days'.tr,
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),

                TimerWidget(
                  timeCount: 00,
                  timeUnit: 'hours'.tr,
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),

                TimerWidget(
                  timeCount: 00,
                  timeUnit: 'mins'.tr,
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),

                TimerWidget(
                  timeCount: 00,
                  timeUnit: 'sec'.tr,
                ),

              ])
            ]),
          ),

          Container(
            height: ResponsiveHelper.isDesktop(context) ? 150 : 170, width: Get.width * 0.7,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Container(
            height: 10, width: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Container(
            height: 10, width: 200,
            color: Colors.grey[300],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Container(
            height: 10, width: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
        ],
        ),
      ),
    );
  }
}

