import 'package:waddy_app/features/item/controllers/campaign_controller.dart';
import 'package:waddy_app/features/item/domain/models/basic_campaign_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CampaignScreen extends StatefulWidget {
  final BasicCampaignModel campaign;
  const CampaignScreen({super.key, required this.campaign});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  @override
  void initState() {
    super.initState();

    Get.find<CampaignController>().getBasicCampaignDetails(widget.campaign.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      backgroundColor: Theme.of(context).cardColor,
      body: GetBuilder<CampaignController>(
        builder: (campaignController) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                toolbarHeight: 50,
                pinned: true,
                floating: false,
                backgroundColor: Colors.white,
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  // title: Text(
                  //   widget.campaign.title!,
                  //   style: waddyMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.black),
                  // ),
                  background: CustomImage(
                    fit: BoxFit.cover,
                    image: '${widget.campaign.imageFullUrl}',
                  ),
                ),
                actions: const [SizedBox()],
              ),

              SliverToBoxAdapter(
                child: FooterView(
                  child: Container(
                    width: Dimensions.maxContentWidth,
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Dimensions.radiusExtraLarge),
                      ),
                    ),
                    child: Column(
                      children: [
                        campaignController.basicCampaign != null
                            ? Column(
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusSmall,
                                      ),
                                      child: CustomImage(
                                        image:
                                            '${campaignController.basicCampaign!.imageFullUrl}',
                                        height: 40,
                                        width: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeSmall,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            campaignController
                                                .basicCampaign!
                                                .title!,
                                            style: waddyMedium.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeLarge,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            campaignController
                                                    .basicCampaign!
                                                    .description ??
                                                '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: waddyRegular.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeSmall,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).disabledColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraSmall,
                                ),

                                campaignController.basicCampaign!.startTime !=
                                        null
                                    ? Row(
                                      children: [
                                        Text(
                                          'campaign_schedule'.tr,
                                          style: waddyRegular.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            color:
                                                Theme.of(context).disabledColor,
                                          ),
                                        ),
                                        const SizedBox(
                                          width:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),
                                        Text(
                                          '${DateConverter.stringToLocalDateOnly(campaignController.basicCampaign!.availableDateStarts!)}'
                                          ' - ${DateConverter.stringToLocalDateOnly(campaignController.basicCampaign!.availableDateEnds!)}',
                                          style: waddyMedium.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ],
                                    )
                                    : const SizedBox(),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraSmall,
                                ),

                                campaignController.basicCampaign!.startTime !=
                                        null
                                    ? Row(
                                      children: [
                                        Text(
                                          'daily_time'.tr,
                                          style: waddyRegular.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            color:
                                                Theme.of(context).disabledColor,
                                          ),
                                        ),
                                        const SizedBox(
                                          width:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),
                                        Text(
                                          '${DateConverter.convertTimeToTime(campaignController.basicCampaign!.startTime!)}'
                                          ' - ${DateConverter.convertTimeToTime(campaignController.basicCampaign!.endTime!)}',
                                          style: waddyMedium.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ],
                                    )
                                    : const SizedBox(),
                                const SizedBox(
                                  height: Dimensions.paddingSizeDefault,
                                ),
                              ],
                            )
                            : const SizedBox(),

                        ItemsView(
                          isStore: true,
                          items: null,
                          padding: EdgeInsets.zero,
                          stores: campaignController.basicCampaign?.store,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
