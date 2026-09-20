import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';

class EmptyFavouritesView extends StatefulWidget {
  final bool isStore;
  const EmptyFavouritesView({super.key, this.isStore = false});

  @override
  State<EmptyFavouritesView> createState() => _EmptyFavouritesViewState();
}

class _EmptyFavouritesViewState extends State<EmptyFavouritesView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _floatAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true, count: 3);

    // Gentle float animation (bobbing up and down)
    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.02),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Smooth slide animation (coming from right to center)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: FooterView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            // Animated illustration with smooth slide
            SlideTransition(
              position: _floatAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: Image.asset(
                    'assets/image/OBJECTno_love.png',
                    width: MediaQuery.of(context).size.height * 0.4,
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.04),
            // Warm, encouraging message
            Text(
              widget.isStore
                  ? 'no_favourite_stores_yet'.tr
                  : 'no_favourites_yet'.tr,
              style: waddyMedium.copyWith(
                fontSize: 18,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),
            // Strong CTA button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
              ),
              child: CustomButton(
                buttonText: 'browse_items'.tr,
                onPressed: () {
                  Get.offNamed(RouteHelper.getInitialRoute());
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
          ],
        ),
      ),
    );
  }
}
