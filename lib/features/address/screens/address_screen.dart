import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/address/widgets/address_confirmation_dialogue.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/common/widgets/no_data_screen.dart';
import 'package:sixam_mart/common/widgets/not_logged_in_screen.dart';
import 'package:sixam_mart/common/widgets/web_page_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddressScreen extends StatefulWidget {
  final bool fromDashboard;
  const AddressScreen({super.key, this.fromDashboard = false});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initCall();
  }

  void initCall() {
    if (AuthHelper.isLoggedIn()) {
      Get.find<AddressController>().getAddressList();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = AuthHelper.isLoggedIn();
    return GetBuilder<AddressController>(
      builder: (addressController) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'my_address'.tr,
            backButton: widget.fromDashboard ? false : true,
          ),
          endDrawer: const MenuDrawer(),
          endDrawerEnableOpenDragGesture: false,
          body: isLoggedIn
              ? RefreshIndicator(
                  onRefresh: () async {
                    await addressController.getAddressList();
                  },
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ResponsiveHelper.isDesktop(context)
                        ? _buildDesktopBody(context, addressController)
                        : _buildMobileBody(context, addressController),
                  ),
                )
              : NotLoggedInScreen(callBack: (value) {
                  initCall();
                  setState(() {});
                }),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: GestureDetector(
                onTap: () {
                  Get.toNamed(RouteHelper.getAddAddressRoute(false, false, 0));
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'add_new_address'.tr,
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopBody(BuildContext context, AddressController addressController) {
    return Column(
      children: [
        WebScreenTitleWidget(title: 'address'.tr),
        Center(
          child: FooterView(
            minHeight: 0.45,
            child: SizedBox(
              width: Dimensions.webMaxWidth,
              child: addressController.addressList != null
                  ? addressController.addressList!.isNotEmpty
                      ? GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisSpacing: Dimensions.paddingSizeLarge,
                            mainAxisSpacing: Dimensions.paddingSizeLarge,
                            childAspectRatio: 2.8,
                            crossAxisCount: 3,
                          ),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                          itemCount: addressController.addressList!.length + 1,
                          itemBuilder: (context, index) {
                            if (index == addressController.addressList!.length) {
                              return _buildAddAddressCard(context);
                            }
                            return _buildAddressCard(
                              context,
                              addressController.addressList![index],
                              index,
                              addressController,
                            );
                          },
                        )
                      : NoDataScreen(text: 'no_saved_address_found'.tr, fromAddress: true)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(BuildContext context, AddressController addressController) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      child: Column(
        children: [
          const SizedBox(height: Dimensions.paddingSizeSmall),

          // Address list
          if (addressController.addressList != null)
            addressController.addressList!.isNotEmpty
                ? ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: addressController.addressList!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeSmall),
                    itemBuilder: (context, index) {
                      return _buildAddressCard(
                        context,
                        addressController.addressList![index],
                        index,
                        addressController,
                      );
                    },
                  )
                : _buildEmptyState(context)
          else
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Lottie.asset(Images.address, width: 120, height: 120),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              Text(
                'no_saved_address_found'.tr,
                style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                child: Text(
                  'please_add_your_address_for_your_better_experience'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).disabledColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAddressCard(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(RouteHelper.getAddAddressRoute(false, false, 0)),
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAddCircle,
                color: Theme.of(context).primaryColor,
                size: 28,
                strokeWidth: 2,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(
                'add_new_address'.tr,
                style: robotoMedium.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    AddressModel address,
    int index,
    AddressController addressController,
  ) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address type row with icon and dots button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: address.addressType == 'home'
                      ? HugeIcons.strokeRoundedHome01
                      : address.addressType == 'office'
                          ? HugeIcons.strokeRoundedBriefcase01
                          : HugeIcons.strokeRoundedLocation01,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeDefault),
              Expanded(
                child: Text(
                  address.addressType?.tr ?? '',
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _buildOptionsSheet(context, address, index, addressController),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreHorizontal,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: Dimensions.paddingSizeDefault),

          // Divider
          Divider(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            height: 1,
          ),

          const SizedBox(height: Dimensions.paddingSizeDefault),

          // Full address
          Text(
            'Address',
            style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            address.address ?? '',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Theme.of(context).textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),

          const SizedBox(height: Dimensions.paddingSizeDefault),

          // Phone number
          if (address.contactPersonNumber != null && address.contactPersonNumber!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Number',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCall02,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Expanded(
                      child: Text(
                        address.contactPersonNumber!,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            const SizedBox.shrink(),

          const SizedBox(height: Dimensions.paddingSizeDefault),

          // Divider
          Divider(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            height: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSheet(
    BuildContext context,
    AddressModel address,
    int index,
    AddressController addressController,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeLarge),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            // Edit option
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: Theme.of(context).primaryColor,
                size: 22,
                strokeWidth: 2,
              ),
              title: Text('edit_details'.tr, style: robotoMedium),
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getEditAddressRoute(address));
              },
            ),

            // Delete option
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: Colors.red,
                size: 22,
                strokeWidth: 2,
              ),
              title: Text('delete'.tr, style: robotoMedium.copyWith(color: Colors.red)),
              onTap: () {
                Get.back();
                if (Get.isSnackbarOpen) {
                  Get.back();
                }
                Get.dialog(AddressConfirmDialogue(
                  icon: Images.locationConfirm,
                  title: 'are_you_sure'.tr,
                  description: 'you_want_to_delete_this_location'.tr,
                  onYesPressed: () {
                    addressController.deleteUserAddressByID(
                      addressController.addressList![index].id, index,
                    ).then((response) {
                      Get.back();
                      showCustomSnackBar(response.message, isError: !response.isSuccess);
                    });
                  },
                ));
              },
            ),

            const SizedBox(height: Dimensions.paddingSizeSmall),
          ],
        ),
      ),
    );
  }
}
