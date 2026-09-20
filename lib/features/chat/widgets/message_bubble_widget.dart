import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/chat/widgets/image_file_view_widget.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:waddy_app/features/chat/domain/models/chat_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

class MessageBubbleWidget extends StatelessWidget {
  final Message message;
  final User? user;
  final String userType;
  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.user,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    bool isReply =
        message.senderId !=
        Get.find<ProfileController>().userInfoModel!.userInfo!.id;

    return (isReply)
        ? Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 0.0,
            vertical: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusExtraLarge,
                    ),
                    child: CustomImage(
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      image: '${user != null ? user!.imageFullUrl : ''}',
                    ),
                  ),
                  const SizedBox(width: 10),

                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.message != null)
                          Flexible(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: .10),
                                borderRadius: const BorderRadius.only(
                                  bottomRight: Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  topRight: Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  bottomLeft: Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.all(
                                message.message != null
                                    ? Dimensions.paddingSizeDefault
                                    : 0,
                              ),
                              child: Text(
                                message.message ?? '',
                                style: waddyRegular.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8.0),

                        (message.fileFullUrl != null &&
                                message.fileFullUrl!.isNotEmpty)
                            ? SizedBox(
                              width: 200,
                              child: ImageFileViewWidget(
                                currentMessage: message,
                                isRightMessage: true,
                              ),
                            )
                            : const SizedBox(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Text(
                DateConverter.convertTodayYesterdayFormat(message.createdAt!),
                style: waddyRegular.copyWith(
                  color: Theme.of(context).hintColor,
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
            ],
          ),
        )
        : Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          margin: const EdgeInsets.symmetric(
            vertical: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          child: GetBuilder<ProfileController>(
            builder: (profileController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            message.order != null
                                ? adminOrderMessage(context, message.order!)
                                : const SizedBox(),

                            // NEW: Reply-to message preview
                            if (message.replyTo != null &&
                                message.replyTo!.message != null)
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom: Dimensions.paddingSizeExtraSmall,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeSmall,
                                  vertical: Dimensions.paddingSizeExtraSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                  border: Border(
                                    left: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  message.replyTo!.message!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: waddyRegular.copyWith(
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                              ),

                            (message.message != null &&
                                    message.message!.isNotEmpty)
                                ? Flexible(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Get.isDarkMode
                                              ? Theme.of(context).primaryColor
                                                  .withValues(alpha: 0.2)
                                              : const Color(0xffE8EEFA),
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(50),
                                      ),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.all(
                                        message.message != null
                                            ? Dimensions.paddingSizeDefault
                                            : 0,
                                      ),
                                      child: Text(
                                        message.message ?? '',
                                        style: waddyRegular.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyLarge?.color,
                                          fontSize: Dimensions.fontSizeSmall,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                : const SizedBox(),

                            SizedBox(
                              height:
                                  (message.message != null &&
                                          message.message!.isNotEmpty)
                                      ? Dimensions.paddingSizeSmall
                                      : 0,
                            ),

                            (message.fileFullUrl != null &&
                                    message.fileFullUrl!.isNotEmpty)
                                ? Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: SizedBox(
                                    width: 200,
                                    child: ImageFileViewWidget(
                                      currentMessage: message,
                                      isRightMessage: true,
                                    ),
                                  ),
                                )
                                : const SizedBox(),
                          ],
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraLarge,
                        ),
                        child: CustomImage(
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          image:
                              profileController.userInfoModel != null
                                  ? '${profileController.userInfoModel!.imageFullUrl}'
                                  : '',
                        ),
                      ),
                    ],
                  ),

                  // Enhanced read receipts using new status field
                  _buildReadReceiptIcon(context),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Text(
                    DateConverter.convertTodayYesterdayFormat(
                      message.createdAt!,
                    ),
                    style: waddyRegular.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],
              );
            },
          ),
        );
  }

  Widget adminOrderMessage(BuildContext context, Order order) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).disabledColor, width: 0.5),
        borderRadius: const BorderRadius.all(
          Radius.circular(Dimensions.radiusDefault),
        ),
      ),
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Dimensions.radiusDefault),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${'order_id'.tr} ', style: waddyMedium),
                          Text('#${order.id}', style: waddyBold),
                        ],
                      ),

                      Text(
                        '${'total'.tr}: ${PriceConverter.convertPrice(order.orderAmount ?? 0)}',
                        style: waddyMedium.copyWith(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                        ),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeExtraSmall,
                        ),
                        margin: const EdgeInsets.only(
                          bottom: Dimensions.paddingSizeExtraSmall,
                        ),
                        child: Text(
                          '${order.orderStatus}'.tr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: waddyMedium.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),

                      Text(
                        DateConverter.stringToLocalDateOnly(order.createdAt!),
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'delivery_address'.tr,
                        style: waddyRegular.copyWith(
                          color: Theme.of(context).disabledColor,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                      Text(
                        order.deliveryAddress?.contactPersonNumber ?? '',
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),

                      RichText(
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: waddyRegular.copyWith(
                            color:
                                Theme.of(context).textTheme.bodyMedium!.color,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                          children: [
                            if (order.deliveryAddress != null &&
                                order.deliveryAddress!.house != null &&
                                order.deliveryAddress!.house!.isNotEmpty)
                              TextSpan(
                                text:
                                    '${'house'.tr}:${order.deliveryAddress?.house ?? 0}, ',
                              ),

                            if (order.deliveryAddress != null &&
                                order.deliveryAddress!.road != null &&
                                order.deliveryAddress!.road!.isNotEmpty)
                              TextSpan(
                                text:
                                    '${'road'.tr}:${order.deliveryAddress?.road ?? 0}, ',
                              ),

                            TextSpan(
                              text: order.deliveryAddress?.address ?? '',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                order.detailsCount != null && order.detailsCount! > 0
                    ? Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.1),
                      ),
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeSmall,
                      ),
                      child: Column(
                        children: [
                          Text('items'.tr, style: waddyRegular),
                          Text(
                            order.detailsCount.toString(),
                            style: waddyMedium.copyWith(
                              fontSize: Dimensions.fontSizeOverLarge,
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds read receipt icon based on message status
  /// - Single check (gray): sent
  /// - Double check (gray): delivered
  /// - Double check (blue/primary): read
  Widget _buildReadReceiptIcon(BuildContext context) {
    IconData icon;
    Color color;

    // Use new status field if available, fallback to isSeen for backward compatibility
    if (message.status != null) {
      switch (message.status) {
        case 'read':
          icon = Icons.done_all;
          color = Theme.of(context).primaryColor;
          break;
        case 'delivered':
          icon = Icons.done_all;
          color = Theme.of(context).disabledColor;
          break;
        case 'sent':
        default:
          icon = Icons.check;
          color = Theme.of(context).disabledColor;
          break;
      }
    } else {
      // Fallback to old isSeen field
      icon = message.isSeen == 1 ? Icons.done_all : Icons.check;
      color =
          message.isSeen == 1
              ? Theme.of(context).primaryColor
              : Theme.of(context).disabledColor;
    }

    return Icon(icon, size: 12, color: color);
  }
}
