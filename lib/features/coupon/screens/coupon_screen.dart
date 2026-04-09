import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/web_page_title_widget.dart';
import 'package:waddy_app/features/coupon/widgets/coupon_card_widget.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  ScrollController scrollController = ScrollController();
  @override
  void initState() {
    super.initState();

    initCall();
  }

  void initCall() {
    if (AuthHelper.isLoggedIn()) {
      Get.find<CouponController>().getCouponList();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = AuthHelper.isLoggedIn();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(title: 'coupon'.tr),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body:
          isLoggedIn
              ? GetBuilder<CouponController>(
                builder: (couponController) {
                  return couponController.couponList != null
                      ? couponController.couponList!.isNotEmpty
                          ? RefreshIndicator(
                            onRefresh: () async {
                              await couponController.getCouponList();
                            },
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  WebScreenTitleWidget(title: 'coupon'.tr),
                                  Center(
                                    child: FooterView(
                                      child: SizedBox(
                                        width: Dimensions.webMaxWidth,
                                        child: GridView.builder(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    ResponsiveHelper.isDesktop(
                                                          context,
                                                        )
                                                        ? 3
                                                        : ResponsiveHelper.isTab(
                                                          context,
                                                        )
                                                        ? 2
                                                        : 1,
                                                mainAxisSpacing:
                                                    Dimensions.paddingSizeSmall,
                                                crossAxisSpacing:
                                                    Dimensions.paddingSizeSmall,
                                                childAspectRatio:
                                                    ResponsiveHelper.isMobile(
                                                          context,
                                                        )
                                                        ? 2.8
                                                        : 2.8,
                                              ),
                                          itemCount:
                                              couponController
                                                  .couponList!
                                                  .length,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(
                                            Dimensions.paddingSizeLarge,
                                          ),
                                          itemBuilder: (context, index) {
                                            return CouponCardWidget(
                                              coupon:
                                                  couponController
                                                      .couponList![index],
                                              index: index,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : NoDataScreen(
                            text: 'no_coupon_found'.tr,
                            showFooter: true,
                          )
                      : const Center(child: CircularProgressIndicator());
                },
              )
              : NotLoggedInScreen(
                callBack: (bool value) {
                  initCall();
                  setState(() {});
                },
              ),
    );
  }
}
