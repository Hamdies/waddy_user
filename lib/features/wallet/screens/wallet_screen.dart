import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/features/wallet/screens/add_fund_screen.dart';
import 'package:waddy_app/features/wallet/widgets/bonus_banner_widget.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:waddy_app/features/wallet/widgets/wallet_card_widget.dart';
import 'package:waddy_app/features/wallet/widgets/wallet_history_widget.dart';

class WalletScreen extends StatefulWidget {
  final String? fundStatus;
  final String? token;
  final bool fromNotification;
  const WalletScreen({
    super.key,
    this.fundStatus,
    this.token,
    this.fromNotification = false,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ScrollController scrollController = ScrollController();

  // Theme colors
  static const Color _neonGreen = Color(0xFF1EF2A0);

  @override
  void initState() {
    super.initState();
    initCall();
  }

  void initCall() {
    if (AuthHelper.isLoggedIn()) {
      Get.find<WalletController>().insertFilterList();
      Get.find<WalletController>().setWalletFilerType('all', isUpdate: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<WalletController>().loadCardAppearance();
      });

      if ((widget.fundStatus == 'success' ||
              widget.fundStatus == 'fail' ||
              widget.fundStatus == 'cancel') &&
          Get.find<WalletController>().getWalletAccessToken() != widget.token) {
        Future.delayed(const Duration(seconds: 2), () {
          showCustomSnackBar(
            widget.fundStatus == 'success'
                ? 'fund_successfully_added_to_wallet'.tr
                : 'fund_not_added_to_wallet'.tr,
            isError: widget.fundStatus != 'success',
            showDuration: 3,
          );
        }).then((value) {
          Get.find<WalletController>().setWalletAccessToken(widget.token ?? '');
        });
      }
      Get.find<ProfileController>().getUserInfo();
      Get.find<WalletController>().getWalletBonusList(isUpdate: false);
      Get.find<WalletController>().getWalletTransactionList(
        '1',
        false,
        Get.find<WalletController>().type,
      );
      Get.find<WalletController>().setOffset(1);

      scrollController.addListener(() {
        if (scrollController.position.pixels ==
                scrollController.position.maxScrollExtent &&
            Get.find<WalletController>().transactionList != null &&
            !Get.find<WalletController>().isLoading) {
          int pageSize =
              (Get.find<WalletController>().popularPageSize! / 10).ceil();
          if (Get.find<WalletController>().offset < pageSize) {
            Get.find<WalletController>().setOffset(
              Get.find<WalletController>().offset + 1,
            );
            if (kDebugMode) {
              print('end of the page');
            }
            Get.find<WalletController>().showBottomLoader();
            Get.find<WalletController>().getWalletTransactionList(
              Get.find<WalletController>().offset.toString(),
              false,
              Get.find<WalletController>().type,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  void _openAddFundScreen() {
    Get.to(() => const AddFundScreen());
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = AuthHelper.isLoggedIn();

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (widget.fromNotification) {
          Get.offAllNamed(RouteHelper.getInitialRoute());
        } else {
          return;
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        appBar: _buildCustomAppBar(context),
        body: GetBuilder<ProfileController>(
          builder: (profileController) {
            return isLoggedIn
                ? profileController.userInfoModel != null
                    ? SafeArea(
                      child: Stack(
                        children: [
                          RefreshIndicator(
                            color: _neonGreen,
                            onRefresh: () async {
                              Get.find<WalletController>().setWalletFilerType(
                                'all',
                              );
                              Get.find<WalletController>()
                                  .getWalletTransactionList('1', true, 'all');
                              Get.find<ProfileController>().getUserInfo();
                            },
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.only(bottom: 90),
                              child: Column(
                                children: [
                                  FooterView(
                                    child: SizedBox(
                                      width: Dimensions.maxContentWidth,
                                      child: GetBuilder<WalletController>(
                                        builder: (walletController) {
                                          return Column(
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal:
                                                          Dimensions
                                                              .paddingSizeLarge,
                                                    ),
                                                child: const WalletCardWidget(),
                                              ),
                                              const BonusBannerWidget(),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      Dimensions
                                                          .paddingSizeLarge,
                                                ),
                                                child: WalletHistoryWidget(),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Floating Add Fund button
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 12,
                            child: GestureDetector(
                              onTap: _openAddFundScreen,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF134E4A),
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusLarge,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'add_fund'.tr,
                                    style: waddyBold.copyWith(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const Center(child: CircularProgressIndicator())
                : NotLoggedInScreen(
                  callBack: (value) {
                    initCall();
                    setState(() {});
                  },
                );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
              vertical: Dimensions.paddingSizeSmall,
            ),
            child: Row(
              children: [
                // Back button with neo-pop style
                GestureDetector(
                  onTap: () {
                    if (widget.fromNotification) {
                      Get.offAllNamed(RouteHelper.getInitialRoute());
                    } else {
                      Get.back();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,

                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                ),

                // Title
                Expanded(
                  child: Center(
                    child: Text(
                      'wallet'.tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeExtraLarge,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),

                // Placeholder for symmetry
                const SizedBox(width: 44),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
