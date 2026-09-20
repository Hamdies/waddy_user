import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/chat/controllers/chat_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/widgets/support_reason_bottom_sheet.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/chat/domain/models/order_chat_model.dart';

class ChatInputAreaWidget extends StatefulWidget {
  final TextEditingController inputMessageController;
  final NotificationBodyModel? notificationBody;
  final int? conversationID;
  final int? index;
  final OrderChatModel? orderChatModel;

  const ChatInputAreaWidget({
    super.key,
    required this.inputMessageController,
    this.notificationBody,
    this.conversationID,
    this.index,
    this.orderChatModel,
  });

  @override
  State<ChatInputAreaWidget> createState() => _ChatInputAreaWidgetState();
}

class _ChatInputAreaWidgetState extends State<ChatInputAreaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

  @override
  void initState() {
    super.initState();
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sendButtonController.dispose();
    super.dispose();
  }

  void _animateSendButton() {
    _sendButtonController.forward().then((_) {
      _sendButtonController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatController>(
      builder: (chatController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            left: Dimensions.paddingSizeDefault,
            right: Dimensions.paddingSizeDefault,
            top: Dimensions.paddingSizeSmall,
            bottom:
                Dimensions.paddingSizeSmall +
                MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply-to message preview
              _buildReplyPreview(chatController),

              // Image preview
              _buildImagePreview(chatController),

              // Input row
              _buildInputRow(chatController),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(ChatController chatController) {
    if (chatController.replyToMessage == null) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              margin: const EdgeInsets.only(
                bottom: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'replying_to'.tr,
                              style: waddyMedium.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          chatController.replyToMessage!.message ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: waddyRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  InkWell(
                    onTap: () => chatController.clearReplyToMessage(),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusExtraLarge,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeExtraSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).hintColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview(ChatController chatController) {
    if (chatController.chatImage.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 100,
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chatController.chatImage.length,
        itemBuilder: (context, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: Dimensions.paddingSizeSmall,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 80,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          child: Image.memory(
                            chatController.chatRawImage[index],
                            width: 80,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: InkWell(
                          onTap:
                              () => chatController.removeImage(
                                index,
                                widget.inputMessageController.text.trim(),
                              ),
                          child: Container(
                            padding: const EdgeInsets.all(
                              Dimensions.paddingSizeExtraSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInputRow(ChatController chatController) {
    bool showMessageSuggestion =
        (widget.orderChatModel != null &&
            widget.inputMessageController.text.isEmpty &&
            chatController.chatImage.isEmpty &&
            Get.find<OrderController>().supportReasons != null &&
            Get.find<OrderController>().supportReasons!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Image picker button
          _buildIconButton(
            icon: Icons.image_outlined,
            onTap: () => chatController.pickImage(false),
            color: Theme.of(context).primaryColor,
          ),

          // Text input field
          Expanded(
            child: TextField(
              inputFormatters: [
                LengthLimitingTextInputFormatter(Dimensions.messageInputLength),
              ],
              controller: widget.inputMessageController,
              textCapitalization: TextCapitalization.sentences,
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeDefault,
              ),
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'type_message'.tr,
                hintStyle: waddyRegular.copyWith(
                  color: Theme.of(context).hintColor,
                  fontSize: Dimensions.fontSizeDefault,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeSmall,
                ),
              ),
              onChanged: (String newText) {
                if (newText.trim().isNotEmpty &&
                    !chatController.isSendButtonActive) {
                  chatController.toggleSendButtonActivity();
                } else if (newText.isEmpty &&
                    chatController.isSendButtonActive) {
                  chatController.toggleSendButtonActivity();
                }
              },
            ),
          ),

          // Send/Suggestion button
          if (chatController.isLoading)
            const Padding(
              padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ScaleTransition(
              scale: _sendButtonScale,
              child: _buildIconButton(
                icon:
                    showMessageSuggestion
                        ? Icons.lightbulb_outline
                        : Icons.send_rounded,
                onTap:
                    () => _handleSendOrSuggestion(
                      chatController,
                      showMessageSuggestion,
                    ),
                color:
                    chatController.isSendButtonActive || showMessageSuggestion
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).hintColor,
                isActive:
                    chatController.isSendButtonActive || showMessageSuggestion,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isActive = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }

  Future<void> _handleSendOrSuggestion(
    ChatController chatController,
    bool showMessageSuggestion,
  ) async {
    if (showMessageSuggestion) {
      _showMessageSuggestions();
    } else {
      if (chatController.isSendButtonActive) {
        _animateSendButton();
        await chatController.sendMessage(
          message: widget.inputMessageController.text,
          notificationBody: widget.notificationBody,
          conversationID: widget.conversationID,
          index: widget.index,
        );
        widget.inputMessageController.clear();
      } else {
        showCustomSnackBar('write_something'.tr);
      }
    }
  }

  void _showMessageSuggestions() {
    {
      Get.bottomSheet(
        const SupportReasonBottomSheet(orderId: null, fromChatPage: true),
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
      ).then((value) {
        if (value != null) {
          widget.inputMessageController.text = value;
          Get.find<ChatController>().toggleSendButtonActivity();
        }
      });
    }
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
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (orderController.supportReasons!.isNotEmpty)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
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
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
