import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/features/review/widgets/rating_widget.dart';
import 'package:waddy_app/features/review/widgets/review_list_widget.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReviewScreen extends StatefulWidget {
  final String? storeName;
  final String? storeID;
  final Store? store;
  const ReviewScreen({
    super.key,
    required this.storeID,
    this.storeName,
    this.store,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    Get.find<ReviewController>().getStoreReviewList(widget.storeID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: widget.storeName ?? 'store_reviews'.tr),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: GetBuilder<ReviewController>(
        builder: (reviewController) {
          return reviewController.storeReviewList != null
              ? reviewController.storeReviewList!.isNotEmpty
                  ? RefreshIndicator(
                    onRefresh: () async {
                      await reviewController.getStoreReviewList(widget.storeID);
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: FooterView(
                        child: Column(
                          children: [
                            Center(
                              child: SizedBox(
                                width: Dimensions.maxContentWidth,
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    Dimensions.paddingSizeDefault,
                                  ),
                                  child: Column(
                                    children: [
                                      RatingWidget(
                                        averageRating:
                                            widget.store?.avgRating ?? 0,
                                        ratingCount:
                                            widget.store?.ratingCount ?? 0,
                                        reviewCommentCount:
                                            widget
                                                .store
                                                ?.reviewsCommentsCount ??
                                            0,
                                        ratings: widget.store?.ratings,
                                      ),
                                      const SizedBox(
                                        height: Dimensions.paddingSizeLarge,
                                      ),

                                      ReviewListWidget(
                                        reviewController: reviewController,
                                        storeName: widget.storeName,
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
                  )
                  : Center(
                    child: NoDataScreen(
                      text: 'no_review_found'.tr,
                      showFooter: true,
                    ),
                  )
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
