import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/features/order/widgets/games/reflex_tap_game.dart';
import 'package:sixam_mart/features/order/widgets/games/simon_says_game.dart';
import 'package:sixam_mart/features/order/widgets/games/speed_math_game.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/images.dart';

/// Compact "While you wait" section with dropdown expand.
/// 2 tabs: Games (3 game picker) + Featured Items.
class WaitingGameWidget extends StatefulWidget {
  const WaitingGameWidget({super.key});

  @override
  State<WaitingGameWidget> createState() => _WaitingGameWidgetState();
}

class _WaitingGameWidgetState extends State<WaitingGameWidget>
    with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF134E4A);
  static const Color _neon = Color(0xFF1EF2A0);
  static const double _contentHeight = 290;

  bool _expanded = false;
  int _selectedTab = 0; // 0=Games, 1=Featured
  int? _activeGame; // null=picker, 0=reflex, 1=simon, 2=math

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _selectGame(int index) => setState(() => _activeGame = index);
  void _backToPicker() => setState(() => _activeGame = null);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Compact Header ──
        GestureDetector(
          onTap: _toggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(Images.scratchCardLogo, width: 32, height: 32),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expanded ? _headerTitle() : 'while_you_wait'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_expanded)
                      Text(
                        'play_browse_explore'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white54, size: 22),
              ),
            ]),
          ),
        ),

        // ── Expandable Content ──
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildTabBar(),
            IndexedStack(index: _selectedTab, children: [
              _buildGamesTab(),
              _buildFeaturedItemsTab(),
            ]),
          ]),
        ),
      ]),
    );
  }

  String _headerTitle() {
    if (_selectedTab == 1) return 'featured_items'.tr;
    if (_activeGame == null) return 'choose_a_game'.tr;
    switch (_activeGame) {
      case 0: return 'Reflex Tap';
      case 1: return 'Balloon Pop';
      case 2: return 'Snake';
      default: return 'games'.tr;
    }
  }

  // ─── Tab Bar ─────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        _tabButton(0, Icons.sports_esports_outlined, 'games'.tr),
        _tabButton(1, Icons.local_fire_department_outlined, 'featured'.tr),
      ]),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _neon.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: selected ? _neon : Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? _neon : Colors.white38,
            )),
          ]),
        ),
      ),
    );
  }

  // ─── Games Tab ───────────────────────────────────────────────────────
  Widget _buildGamesTab() {
    return SizedBox(
      height: _contentHeight,
      child: _activeGame == null
          ? _buildGamePicker()
          : _buildActiveGame(),
    );
  }

  Widget _buildGamePicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'pick_a_challenge'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(children: [
              _gameCard(
                index: 0,
                icon: Icons.bolt,
                color: _neon,
                title: 'Reflex Tap',
                desc: 'Tap lit tiles\nbefore they vanish',
              ),
              const SizedBox(width: 10),
              _gameCard(
                index: 1,
                icon: Icons.bubble_chart,
                color: Colors.pink,
                title: 'Balloon Pop',
                desc: 'Pop them before\nthey escape!',
              ),
              const SizedBox(width: 10),
              _gameCard(
                index: 2,
                icon: Icons.pest_control,
                color: Colors.green,
                title: 'Snake',
                desc: 'Swipe to move\neat to grow!',
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _gameCard({
    required int index,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectGame(index),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'play'.tr,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildActiveGame() {
    switch (_activeGame) {
      case 0:
        return ReflexTapGame(onBack: _backToPicker);
      case 1:
        return BalloonPopGame(onBack: _backToPicker);
      case 2:
        return SnakeGame(onBack: _backToPicker);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Featured Items Tab ──────────────────────────────────────────────
  Widget _buildFeaturedItemsTab() {
    return SizedBox(
      height: _contentHeight,
      child: GetBuilder<ItemController>(builder: (itemController) {
        final List<Item>? items = itemController.popularItemList;
        if (items == null) {
          return const Center(
            child: CircularProgressIndicator(color: _neon, strokeWidth: 2),
          );
        }
        if (items.isEmpty) {
          return Center(
            child: Text(
              'no_items_available'.tr,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          );
        }
        final displayItems = items.take(10).toList();
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            return GestureDetector(
              onTap: () =>
                  Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false)),
              child: Container(
                width: 130,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: SizedBox(
                        height: 100,
                        width: 130,
                        child: CustomImage(
                          image: item.imageFullUrl ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (item.storeName != null)
                            Text(
                              item.storeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(
                              PriceConverter.convertPrice(item.price),
                              style: const TextStyle(
                                color: _neon,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (item.avgRating != null &&
                                item.avgRating! > 0) ...[
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                item.avgRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
