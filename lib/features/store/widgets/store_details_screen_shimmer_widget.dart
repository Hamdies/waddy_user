import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/util/dimensions.dart';

class StoreDetailsScreenShimmerWidget extends StatelessWidget {
  const StoreDetailsScreenShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Matches the 220 cover in FoodStoreScreen's hero so the skeleton
          // does not jump when the real photo lands. The cover is edge-to-edge
          // and runs under the status bar, so no top radius here either.
          Shimmer(
            child: Container(height: 220, color: Theme.of(context).shadowColor),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Container(
            height: 110,
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            margin: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              border: Border.all(color: Theme.of(context).shadowColor),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  child: Shimmer(
                    child: Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeLarge),

                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                      child: Shimmer(
                        child: Container(
                          height: 10,
                          width: 150,
                          decoration: BoxDecoration(
                            color: Theme.of(context).shadowColor,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                        ),
                      ),
                    ),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                      child: Shimmer(
                        child: Container(
                          height: 10,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(context).shadowColor,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                        ),
                      ),
                    ),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                      child: Shimmer(
                        child: Container(
                          height: 10,
                          width: 150,
                          decoration: BoxDecoration(
                            color: Theme.of(context).shadowColor,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(),
                  ],
                ),

                const Spacer(),

                Icon(
                  Icons.favorite_border,
                  size: 25,
                  color: Theme.of(context).shadowColor,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Icon(
                  Icons.share,
                  size: 25,
                  color: Theme.of(context).shadowColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeLarge,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              border: Border.all(color: Theme.of(context).shadowColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.star, color: Theme.of(context).shadowColor),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                          child: Shimmer(
                            child: Container(
                              height: 10,
                              width: 70,
                              decoration: BoxDecoration(
                                color: Theme.of(context).shadowColor,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Column(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Theme.of(context).shadowColor,
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                          child: Shimmer(
                            child: Container(
                              height: 10,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(context).shadowColor,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Column(
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: Theme.of(context).shadowColor,
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                          child: Shimmer(
                            child: Container(
                              height: 10,
                              width: 70,
                              decoration: BoxDecoration(
                                color: Theme.of(context).shadowColor,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          ListView.builder(
            itemCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeSmall,
                ),
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  margin: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    border: Border.all(color: Theme.of(context).shadowColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                        child: Shimmer(
                          child: Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                              color: Theme.of(context).shadowColor,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusSmall,
                              ),
                            ),
                          ),
                        ),
                      ),

                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                            child: Shimmer(
                              child: Container(
                                height: 10,
                                width: 200,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).shadowColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                            child: Shimmer(
                              child: Container(
                                height: 10,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).shadowColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                            child: Shimmer(
                              child: Container(
                                height: 10,
                                width: 200,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).shadowColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(),
                        ],
                      ),

                      Icon(
                        Icons.favorite_border,
                        size: 25,
                        color: Theme.of(context).shadowColor,
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
  }
}
