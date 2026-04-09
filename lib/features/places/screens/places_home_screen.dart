import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/widgets/area_filter_tabs.dart';
import 'package:waddy_app/features/places/widgets/chillers_section.dart';
import 'package:waddy_app/features/places/widgets/places_list_view.dart';
import 'package:waddy_app/features/places/widgets/podium_section.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';

// Warm off-white page tint — makes white cards feel elevated
const _kPageBg = Color(0xFFF5F4F1);

class PlacesHomeScreen extends StatefulWidget {
  const PlacesHomeScreen({super.key});

  @override
  State<PlacesHomeScreen> createState() => _PlacesHomeScreenState();
}

class _PlacesHomeScreenState extends State<PlacesHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final controller = Get.find<PlacesController>();
    await controller.initializePlacesData();
    if (AuthHelper.isLoggedIn()) controller.getFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final neon    = Theme.of(context).secondaryHeaderColor;
    final primary = Theme.of(context).primaryColor;

    return ColoredBox(
      color: _kPageBg,
      child: GetBuilder<PlacesController>(
        builder: (placesController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Header ──
              _buildHeaderBar(context, neon, primary),
              const SizedBox(height: 14),

              // ── Area filter tabs ──
            

              // ── Divider ──

              // ── The Podium ──
              const PodiumSection(),

              // ── Divider ──
              _divider(),
 Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions. paddingSizeDefault, vertical: 8),
                child: const ChillersSection(),
              ),

              const SizedBox(height: 16),
               _divider(),
              // ── All Spots (primary action area) ──
              const PlacesListView(),

              // ── Divider ──
             

              // ── Top 3 Chillers (social proof, secondary) ──
             

              const SizedBox(height: 120),
            ],
          );
        },
      ),
    );
  }

  // Thin full-width black rule — consistent visual rhythm between sections
  Widget _divider() => Container(
        height: 1.5,
        color: Colors.black,
        margin: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: Dimensions.paddingSizeDefault),
      );

  Widget _buildHeaderBar(BuildContext context, Color neon, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Back button — neubrutalism square ──
          GestureDetector(
            onTap: () => Get.find<SplashController>().setModule(null),
            child: Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:     Colors.white,
                border:    Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color:      Colors.black,
                      offset:     Offset(2, 2),
                      blurRadius: 0),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: Colors.black),
            ),
          ),

          const SizedBox(width: 12),

          // ── Branding ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'WADDI',
                      style: robotoBlack.copyWith(
                          fontSize: 26, height: 1, color: Colors.black),
                    ),
                    const SizedBox(width: 6),
                    // "Maadi" badge — neubrutalism: no radius, black border
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:  neon,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color:      Colors.black,
                              offset:     Offset(2, 2),
                              blurRadius: 0),
                        ],
                      ),
                      child: Text(
                        'Maadi',
                        style: robotoBlack.copyWith(
                            fontSize: 13, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Spots',
                  style: robotoBlack.copyWith(
                    fontSize: 20,
                    color:       primary,
                    fontStyle:   FontStyle.italic,
                    height:      1,
                  ),
                ),
              ],
            ),
          ),

          // ── Coin display — neubrutalism: no radius, black border ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:     Colors.white,
              border:    Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(
                    color:      Colors.black,
                    offset:     Offset(2, 2),
                    blurRadius: 0),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/image/waddy_coin.png',
                    width: 20, height: 20),
                const SizedBox(width: 6),
                Text(
                  '761',
                  style: robotoBlack.copyWith(
                      fontSize: 16, color: primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
