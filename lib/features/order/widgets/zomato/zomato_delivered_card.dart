import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/util/styles.dart';

const Color _primary = Color(0xFF134E4A);
const Color _accent = Color(0xFF1EF2A0);

class ZomatoDeliveredCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onReview;

  const ZomatoDeliveredCard({
    super.key,
    required this.order,
    this.onReview,
  });

  @override
  State<ZomatoDeliveredCard> createState() => _ZomatoDeliveredCardState();
}

class _ZomatoDeliveredCardState extends State<ZomatoDeliveredCard> {
  int _restaurantRating = 0;
  String? _packagingFeedback;

  @override
  Widget build(BuildContext context) {
    final String deliveryTime = widget.order.delivered != null
        ? DateConverter.dateTimeStringToDateTime(widget.order.delivered!)
        : '';
    final String dmName = widget.order.deliveryMan != null
        ? '${widget.order.deliveryMan!.fName ?? ''} ${widget.order.deliveryMan!.lName ?? ''}'
            .trim()
        : '';

    return Column(
      children: [
        // Delivered info card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'delivered_at'.tr} ${(widget.order.deliveryAddress?.addressType ?? 'home').tr.capitalizeFirst ?? ''}',
                      style: robotoBold.copyWith(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dmName.isNotEmpty ? 'The delivery partner $dmName delivered your order' : 'Your order was delivered'}${deliveryTime.isNotEmpty ? ' at $deliveryTime' : ''}.',
                      style: robotoRegular.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Restaurant rating + packaging
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store info
              Row(
                children: [
                  if (widget.order.store?.logoFullUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomImage(
                        image: widget.order.store!.logoFullUrl!,
                        height: 44,
                        width: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.store?.name ?? '',
                          style: robotoBold.copyWith(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        if (widget.order.store?.address != null)
                          Text(
                            widget.order.store!.address!,
                            style: robotoRegular.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 16),

              // Order ID
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18, color: _primary),
                  const SizedBox(width: 8),
                  Text(
                    '${'order'.tr} #${widget.order.id}',
                    style: robotoMedium.copyWith(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 16),

              // Rate restaurant
              Row(
                children: [
                  const Icon(Icons.thumb_up_outlined, size: 18, color: _primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${'rate'.tr} ${widget.order.store?.name ?? ''}',
                      style: robotoMedium.copyWith(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _restaurantRating = index + 1);
                      if (widget.onReview != null) widget.onReview!();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        index < _restaurantRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 32,
                        color: index < _restaurantRating
                            ? const Color(0xFFFFB300)
                            : Colors.grey.shade300,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 16),

              // Packaging feedback
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 18, color: _primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'how_was_the_restaurant_packaging'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFeedbackChip('good'.tr, 'good'),
                  const SizedBox(width: 12),
                  _buildFeedbackChip('not_good'.tr, 'not_good'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackChip(String label, String value) {
    final bool selected = _packagingFeedback == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _packagingFeedback = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _primary : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: robotoMedium.copyWith(
              fontSize: 13,
              color: selected ? _primary : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
