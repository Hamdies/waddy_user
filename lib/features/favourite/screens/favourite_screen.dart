import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:waddy_app/features/favourite/widgets/fav_item_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  FavouriteScreenState createState() => FavouriteScreenState();
}

class FavouriteScreenState extends State<FavouriteScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, initialIndex: 0, vsync: this);

    initCall();
  }

  void initCall() {
    if (AuthHelper.isLoggedIn()) {
      Get.find<FavouriteController>().getFavouriteList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'favourite'.tr, backButton: true),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body:
          AuthHelper.isLoggedIn()
              ? SafeArea(
                child: Column(
                  children: [
                    SizedBox(
                      width: Dimensions.maxContentWidth,
                      child: Container(
                        width: Dimensions.maxContentWidth,
                        color: Theme.of(context).cardColor,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeLarge,
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          tabAlignment: TabAlignment.center,
                          indicatorColor:
                              Theme.of(context).secondaryHeaderColor,
                          indicatorWeight: 2,
                          indicatorSize: TabBarIndicatorSize.label,
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: Theme.of(context).disabledColor,
                          dividerHeight: 0.5,
                          dividerColor: Theme.of(
                            context,
                          ).disabledColor.withOpacity(0.2),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 50.0,
                            vertical: 2,
                          ),
                          unselectedLabelStyle: waddyRegular.copyWith(
                            color: Theme.of(context).disabledColor,
                            fontSize: Dimensions.fontSizeDefault,
                          ),
                          labelStyle: waddyBold.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: Theme.of(context).primaryColor,
                          ),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedFavourite,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('item'.tr),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.store_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    Get.find<SplashController>()
                                                .configModel
                                                .moduleConfig!
                                                .module!
                                                .showRestaurantText ??
                                            false
                                        ? 'restaurants'.tr
                                        : 'stores'.tr,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          FavItemViewWidget(isStore: false),
                          FavItemViewWidget(isStore: true),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              : NotLoggedInScreen(
                callBack: (value) {
                  initCall();
                  setState(() {});
                },
              ),
    );
  }
}
