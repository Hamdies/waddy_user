import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_review_model.dart';
import 'package:sixam_mart/features/places/widgets/place_vote_sheet.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final int placeId;
  const PlaceDetailsScreen({super.key, required this.placeId});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  final PageController _galleryController = PageController();
  int _currentGalleryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final controller = Get.find<PlacesController>();
    await controller.getPlaceDetails(widget.placeId);
    controller.getPlaceReviews(widget.placeId);
    if (AuthHelper.isLoggedIn()) {
      controller.getVoteStatus(widget.placeId);
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final neon = Theme.of(context).secondaryHeaderColor;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GetBuilder<PlacesController>(
        builder: (controller) {
          final place = controller.placeDetails;

          if (controller.isDetailsLoading || place == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  CircularProgressIndicator(color: neon),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildGalleryAppBar(context, place, primary, neon),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, place, primary, neon, controller),
                    if (place.tags != null && place.tags!.isNotEmpty)
                      _buildTags(context, place),
                    _buildQuickActions(context, place, primary, neon),
                    _buildInfoSection(context, place, primary, neon),
                    if (place.address != null)
                      _buildAddress(context, place, primary, neon),
                    _buildVoteCTA(context, controller, place, primary, neon),
                    _buildReviewsSection(context, controller, primary, neon),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GALLERY APP BAR — immersive full-bleed gallery
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGalleryAppBar(BuildContext context, Place place, Color primary, Color neon) {
    final images = <String>[];
    if (place.gallery != null && place.gallery!.isNotEmpty) {
      images.addAll(place.gallery!.map((e) => e.image));
    } else if (place.image != null) {
      images.add(place.image!);
    }

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: primary,
      leading: _circleButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => Get.back(),
      ),
      actions: [
        if (AuthHelper.isLoggedIn())
          GetBuilder<PlacesController>(
            builder: (c) {
              final isFav = place.isFavorited == true;
              return _circleButton(
                icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF5252) : Colors.white,
                onTap: () => c.toggleFavorite(place.id),
              );
            },
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isEmpty
            ? Container(
                color: primary.withValues(alpha: 0.2),
                child: const Center(child: Text('📍', style: TextStyle(fontSize: 60))),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _galleryController,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentGalleryIndex = i),
                    itemBuilder: (_, i) => CustomImage(image: images[i], fit: BoxFit.cover),
                  ),
                  // Bottom gradient
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Top gradient for status bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black45, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Page indicator
                  if (images.length > 1)
                    Positioned(
                      bottom: 16, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) {
                          final isActive = _currentGalleryIndex == i;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isActive ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  // Photo count badge
                  if (images.length > 1)
                    Positioned(
                      bottom: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${_currentGalleryIndex + 1}/${images.length}',
                              style: robotoMedium.copyWith(fontSize: 11, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, Color? color, required VoidCallback onTap}) {
    final p = Theme.of(context).primaryColor;
    final n = Theme.of(context).secondaryHeaderColor;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: p.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: n.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 20),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER — title, category, rating, open status
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, Place place, Color primary, Color neon, PlacesController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  place.title,
                  style: robotoBold.copyWith(fontSize: 24, height: 1.2),
                ),
              ),
              if (place.isOpenNow != null)
                Container(
                  margin: const EdgeInsets.only(left: 10, top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: place.isOpenNow == true
                        ? const Color(0xFF00C853)
                        : const Color(0xFFFF5252),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        place.isOpenNow == true ? 'open'.tr : 'closed'.tr,
                        style: robotoBold.copyWith(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Category
          if (place.categoryName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: neon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: neon.withValues(alpha: 0.2)),
              ),
              child: Text(
                place.categoryName!,
                style: robotoMedium.copyWith(fontSize: 12, color: neon),
              ),
            ),

          const SizedBox(height: 14),

          // Rating row — vibrant style
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: neon.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(color: neon.withValues(alpha: 0.05), blurRadius: 8),
              ],
            ),
            child: Row(
              children: [
                // Big rating number
                Column(
                  children: [
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: robotoBold.copyWith(fontSize: 28),
                    ),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < place.rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: Colors.amber.shade700,
                      )),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 40, color: neon.withValues(alpha: 0.2)),
                const SizedBox(width: 16),
                // Stats
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('🗳️', '${place.votesCount}', 'votes'.tr),
                      _statItem('❤️', '${place.favoritesCount}', 'favorites'.tr),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: robotoBold.copyWith(fontSize: 16)),
        Text(label, style: robotoRegular.copyWith(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAGS — colorful vibe pills
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTags(BuildContext context, Place place) {
    const tagColors = [
      Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF7C4DFF),
      Color(0xFFFFAB00), Color(0xFF448AFF), Color(0xFFE040FB),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: place.tags!.asMap().entries.map((entry) {
          final tag = entry.value;
          final color = tagColors[entry.key % tagColors.length];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tag.icon != null && tag.icon!.isNotEmpty) ...[
                  Text(tag.icon!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                ],
                Text(tag.localizedName,
                    style: robotoMedium.copyWith(fontSize: 12, color: color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUICK ACTIONS — call, website, instagram, directions
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuickActions(BuildContext context, Place place, Color primary, Color neon) {
    final actions = <_QuickAction>[];

    if (place.phone != null && place.phone!.isNotEmpty) {
      actions.add(_QuickAction('📞', 'call'.tr, () {
        launchUrl(Uri.parse('tel:${place.phone}'));
      }));
    }
    if (place.website != null && place.website!.isNotEmpty) {
      actions.add(_QuickAction('🌐', 'website'.tr, () {
        launchUrl(Uri.parse(place.website!), mode: LaunchMode.externalApplication);
      }));
    }
    if (place.instagram != null && place.instagram!.isNotEmpty) {
      actions.add(_QuickAction('📸', 'instagram'.tr, () {
        launchUrl(Uri.parse('https://instagram.com/${place.instagram}'),
            mode: LaunchMode.externalApplication);
      }));
    }
    if (place.lat != null && place.lng != null) {
      actions.add(_QuickAction('🗺️', 'directions'.tr, () {
        launchUrl(Uri.parse('https://maps.google.com/?q=${place.lat},${place.lng}'),
            mode: LaunchMode.externalApplication);
      }));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: actions.map((action) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: action.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neon.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(color: neon.withValues(alpha: 0.04), blurRadius: 6),
                  ],
                ),
                child: Column(
                  children: [
                    Text(action.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      action.label,
                      style: robotoMedium.copyWith(fontSize: 10, color: neon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // INFO SECTION — hours
  // ═══════════════════════════════════════════════════════════════
  Widget _buildInfoSection(BuildContext context, Place place, Color primary, Color neon) {
    if (place.openingHours == null) return const SizedBox.shrink();

    String hours = '';
    if (place.openingHours is String) {
      hours = place.openingHours;
    } else if (place.openingHours is Map) {
      hours = (place.openingHours as Map).entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
    }
    if (hours.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neon.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🕐', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('opening_hours'.tr,
                    style: robotoBold.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Text(hours,
                    style: robotoRegular.copyWith(fontSize: 12, color: Theme.of(context).disabledColor, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ADDRESS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAddress(BuildContext context, Place place, Color primary, Color neon) {
    return GestureDetector(
      onTap: () {
        if (place.lat != null && place.lng != null) {
          launchUrl(Uri.parse('https://maps.google.com/?q=${place.lat},${place.lng}'),
              mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: neon.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Text('📍', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(place.address!,
                  style: robotoRegular.copyWith(fontSize: 13, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.directions_rounded, size: 22, color: neon),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VOTE CTA — gradient button
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVoteCTA(BuildContext context, PlacesController controller, Place place, Color primary, Color neon) {
    final hasVoted = controller.voteStatus?.hasVoted == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: GestureDetector(
        onTap: () {
          if (!AuthHelper.isLoggedIn()) {
            Get.snackbar('login_required'.tr, 'please_login_to_vote'.tr);
            return;
          }
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => PlaceVoteSheet(placeId: place.id, hasVoted: hasVoted),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: hasVoted
                ? LinearGradient(colors: [neon, neon.withValues(alpha: 0.8)])
                : LinearGradient(colors: [primary, primary.withValues(alpha: 0.85)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neon.withValues(alpha: hasVoted ? 0.5 : 0.3)),
            boxShadow: [
              BoxShadow(
                color: neon.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hasVoted ? '✅' : '🗳️',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 10),
              Text(
                hasVoted ? 'you_voted'.tr : 'vote_for_this_place'.tr,
                style: robotoBold.copyWith(fontSize: 15, color: hasVoted ? primary : Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REVIEWS SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReviewsSection(BuildContext context, PlacesController controller, Color primary, Color neon) {
    final reviews = controller.reviews;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('💬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('reviews'.tr, style: robotoBold.copyWith(fontSize: 18)),
              const Spacer(),
              if (controller.totalReviews != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: neon.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.totalReviews}',
                    style: robotoMedium.copyWith(fontSize: 11, color: neon),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (controller.isReviewsLoading && (reviews == null || reviews.isEmpty))
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: neon, strokeWidth: 2),
              ),
            )
          else if (reviews == null || reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('📝', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    Text('no_reviews_yet'.tr,
                        style: robotoMedium.copyWith(fontSize: 14, color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Text('be_the_first'.tr,
                        style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey[350])),
                  ],
                ),
              ),
            )
          else
            ...reviews.map((review) => _buildReviewCard(context, review, primary, neon)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, PlaceReview review, Color primary, Color neon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neon.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info + rating
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: neon.withValues(alpha: 0.1),
                backgroundImage: review.userImage != null
                    ? NetworkImage(review.userImage!)
                    : null,
                child: review.userImage == null
                    ? const Text('👤', style: TextStyle(fontSize: 16))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName ?? 'anonymous'.tr,
                        style: robotoMedium.copyWith(fontSize: 13)),
                    if (review.createdAt != null)
                      Text(_formatDate(review.createdAt!),
                          style: robotoRegular.copyWith(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ),
              // Star rating pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 2),
                    Text(
                      '${review.rating}',
                      style: robotoBold.copyWith(fontSize: 12, color: Colors.amber.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.comment!,
                style: robotoRegular.copyWith(fontSize: 13, height: 1.5, color: Colors.grey[700])),
          ],

          // Photo review
          if (review.imageUrl != null && review.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomImage(
                image: review.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          // Report
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _showReportDialog(context, review.id),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('report'.tr,
                    style: robotoRegular.copyWith(fontSize: 10, color: Colors.grey[350])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showReportDialog(BuildContext context, int voteId) {
    if (!AuthHelper.isLoggedIn()) return;

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🚩', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('report_review'.tr, style: robotoBold.copyWith(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'reason'.tr,
            hintStyle: robotoRegular.copyWith(color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Get.find<PlacesController>().reportReview(voteId, controller.text.trim());
                Get.back();
              }
            },
            child: Text('submit'.tr),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.emoji, this.label, this.onTap);
}
