import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/chat/controllers/chat_controller.dart';
import 'package:waddy_app/features/chat/domain/models/order_chat_model.dart';
import 'package:waddy_app/features/chat/enums/user_type_enum.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:waddy_app/common/widgets/paginated_list_view.dart';
import 'package:waddy_app/features/chat/widgets/message_bubble_widget.dart';
import 'package:waddy_app/features/chat/widgets/empty_chat_state_widget.dart';
import 'package:waddy_app/features/chat/widgets/chat_input_area_widget.dart';
import 'package:waddy_app/helper/date_converter.dart';

class ChatScreen extends StatefulWidget {
  final NotificationBodyModel? notificationBody;
  final User? user;
  final int? conversationID;
  final int? index;
  final bool fromNotification;
  final OrderChatModel? orderChatModel;
  const ChatScreen({
    super.key,
    required this.notificationBody,
    required this.user,
    this.conversationID,
    this.index,
    this.fromNotification = false,
    this.orderChatModel,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputMessageController = TextEditingController();
  StreamSubscription? _stream;

  @override
  void initState() {
    super.initState();

    initCall();
  }

  void initCall() {
    if (AuthHelper.isLoggedIn()) {
      if (widget.orderChatModel != null) {
        Get.find<ChatController>().sendMessage(
          message:
              '${widget.orderChatModel!.reason!}\n${widget.orderChatModel!.customMessage!}',
          orderId: widget.orderChatModel!.orderId,
          notificationBody: widget.notificationBody,
          conversationID: widget.conversationID,
          index: widget.index,
        );
      }

      Get.find<ChatController>().getMessages(
        1,
        widget.notificationBody,
        widget.user,
        widget.conversationID,
        firstLoad: true,
      );

      if (Get.find<ProfileController>().userInfoModel == null ||
          Get.find<ProfileController>().userInfoModel!.userInfo == null) {
        Get.find<ProfileController>().getUserInfo();
      }

      if (widget.orderChatModel != null) {
        Get.find<OrderController>().getSupportReasons();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _stream?.cancel();
  }

  /// Formats the last active timestamp into a human-readable "last seen" string
  String _formatLastSeen(String lastActiveAt) {
    try {
      final DateTime lastActive = DateTime.parse(lastActiveAt);
      final Duration difference = DateTime.now().difference(lastActive);

      if (difference.inMinutes < 1) {
        return 'online'.tr;
      } else if (difference.inMinutes < 60) {
        return '${'last_seen'.tr} ${difference.inMinutes} ${'minutes_ago'.tr}';
      } else if (difference.inHours < 24) {
        return '${'last_seen'.tr} ${difference.inHours} ${'hours_ago'.tr}';
      } else if (difference.inDays < 7) {
        return '${'last_seen'.tr} ${difference.inDays} ${'days_ago'.tr}';
      } else {
        return '${'last_seen'.tr} ${DateConverter.dateTimeStringToDate(lastActiveAt)}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatController>(
      builder: (chatController) {
        bool isLoggedIn = AuthHelper.isLoggedIn();

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (widget.fromNotification) {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            } else {
              return;
            }
          },
          child: Scaffold(
            endDrawer: const MenuDrawer(),
            endDrawerEnableOpenDragGesture: false,
            appBar: (AppBar(
              leading: IconButton(
                onPressed: () {
                  if (widget.fromNotification) {
                    Get.offAllNamed(RouteHelper.getInitialRoute());
                  } else {
                    Get.back();
                  }
                },
                icon: const Icon(Icons.arrow_back_ios),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatController.messageModel != null
                        ? '${chatController.messageModel!.conversation!.receiver!.fName}'
                            ' ${chatController.messageModel!.conversation!.receiver!.lName}'
                        : 'receiver_name'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  // NEW: Last seen display
                  if (chatController
                          .messageModel
                          ?.conversation
                          ?.receiver
                          ?.lastActiveAt !=
                      null)
                    Text(
                      _formatLastSeen(
                        chatController
                            .messageModel!
                            .conversation!
                            .receiver!
                            .lastActiveAt!,
                      ),
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                ],
              ),
              backgroundColor: Theme.of(context).cardColor,
              surfaceTintColor: Theme.of(context).cardColor,
              shadowColor: Theme.of(
                context,
              ).disabledColor.withValues(alpha: 0.5),
              elevation: 2,
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        width: 1,
                        color: Theme.of(context).primaryColor,
                      ),
                      color: Theme.of(context).cardColor,
                    ),
                    child: ClipOval(
                      child: CustomImage(
                        image:
                            '${chatController.messageModel != null ? chatController.messageModel!.conversation!.receiver!.imageFullUrl : ''}',
                        fit: BoxFit.cover,
                        height: 40,
                        width: 40,
                      ),
                    ),
                  ),
                ),
              ],
            )),

            body:
                isLoggedIn
                    ? SafeArea(
                      child: Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: Column(
                            children: [
                              SizedBox(height: 0),

                              const SizedBox(),

                              GetBuilder<ChatController>(
                                builder: (chatController) {
                                  return Expanded(
                                    child:
                                        chatController.messageModel != null
                                            ? chatController
                                                    .messageModel!
                                                    .messages!
                                                    .isNotEmpty
                                                ? SingleChildScrollView(
                                                  controller: _scrollController,
                                                  reverse: true,
                                                  child: PaginatedListView(
                                                    scrollController:
                                                        _scrollController,
                                                    reverse: true,
                                                    totalSize:
                                                        chatController
                                                            .messageModel
                                                            ?.totalSize,
                                                    offset:
                                                        chatController
                                                            .messageModel
                                                            ?.offset,
                                                    onPaginate:
                                                        (
                                                          int? offset,
                                                        ) async => await chatController
                                                            .getMessages(
                                                              offset!,
                                                              widget
                                                                  .notificationBody,
                                                              widget.user,
                                                              widget
                                                                  .conversationID,
                                                            ),
                                                    itemView: ListView.builder(
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      shrinkWrap: true,
                                                      reverse: true,
                                                      itemCount:
                                                          chatController
                                                              .messageModel!
                                                              .messages!
                                                              .length,
                                                      itemBuilder: (
                                                        context,
                                                        index,
                                                      ) {
                                                        return AnimatedOpacity(
                                                          opacity: 1.0,
                                                          duration: Duration(
                                                            milliseconds:
                                                                300 +
                                                                (index * 50),
                                                          ),
                                                          child: MessageBubbleWidget(
                                                            message:
                                                                chatController
                                                                    .messageModel!
                                                                    .messages![index],
                                                            user:
                                                                chatController
                                                                    .messageModel!
                                                                    .conversation!
                                                                    .receiver,
                                                            userType:
                                                                widget.notificationBody!.adminId !=
                                                                        null
                                                                    ? UserType
                                                                        .admin
                                                                        .name
                                                                    : widget
                                                                            .notificationBody!
                                                                            .deliverymanId !=
                                                                        null
                                                                    ? UserType
                                                                        .delivery_man
                                                                        .name
                                                                    : UserType
                                                                        .vendor
                                                                        .name,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                )
                                                : const EmptyChatStateWidget()
                                            : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                  );
                                },
                              ),

                              (chatController.messageModel != null &&
                                      (chatController.messageModel!.status! ||
                                          chatController
                                              .messageModel!
                                              .messages!
                                              .isEmpty))
                                  ? ChatInputAreaWidget(
                                    inputMessageController:
                                        _inputMessageController,
                                    notificationBody: widget.notificationBody,
                                    conversationID: widget.conversationID,
                                    index: widget.index,
                                    orderChatModel: widget.orderChatModel,
                                  )
                                  : const SizedBox(),
                            ],
                          ),
                        ),
                      ),
                    )
                    : NotLoggedInScreen(
                      callBack: (value) {
                        initCall();
                        setState(() {});
                      },
                    ),
          ),
        );
      },
    );
  }
}

class MessageSuggestionWidget extends StatelessWidget {
  const MessageSuggestionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderController>(
      builder: (orderController) {
        return Container(
          width: Dimensions.maxContentWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeLarge,
            vertical: 50,
          ),
          alignment:
              Get.find<LocalizationController>().isLtr
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              orderController.supportReasons!.isNotEmpty
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: context.height * 0.5,
                          minHeight: 30,
                        ),
                        width: context.width * 0.8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 10),
                          ],
                        ),
                        margin: EdgeInsets.only(right: 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Dimensions.paddingSizeDefault,
                                  ),
                                  child: Text(
                                    'choose_the_reason_for_support'.tr,
                                    style: waddyBold.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  onPressed: () => Get.back(),
                                  icon: const Icon(Icons.clear),
                                ),
                              ],
                            ),

                            Container(
                              constraints: BoxConstraints(
                                maxHeight: context.height * 0.3,
                                minHeight: 30,
                              ),
                              child: ListView.builder(
                                itemCount:
                                    orderController.supportReasons!.length,
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeSmall,
                                ),
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () {
                                      Get.back(
                                        result:
                                            orderController
                                                .supportReasons![index],
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusSmall,
                                        ),
                                        border: Border.all(
                                          color: Theme.of(context).disabledColor
                                              .withValues(alpha: 0.5),
                                          width: 0.3,
                                        ),
                                        boxShadow: null,
                                      ),
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeSmall,
                                      ),
                                      margin: const EdgeInsets.all(
                                        Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: Text(
                                        orderController
                                                .supportReasons![index] ??
                                            '',
                                        style: waddyRegular,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : const SizedBox(),
            ],
          ),
        );
      },
    );
  }
}
