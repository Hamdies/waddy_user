import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/widgets/place_vote_sheet.dart';
import 'package:waddy_app/helper/auth_helper.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final int placeId;
  const PlaceDetailsScreen({super.key, required this.placeId});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final c = Get.find<PlacesController>();
    await c.getPlaceDetails(widget.placeId);
    c.getPlaceReviews(widget.placeId);
    if (AuthHelper.isLoggedIn()) c.getVoteStatus(widget.placeId);
  }

  void _onVoteTap(int placeId) {
    if (AuthHelper.isLoggedIn()) {
      Get.bottomSheet(PlaceVoteSheet(placeId: placeId), isScrollControlled: true);
    } else {
      Get.snackbar('Alert', 'Please login to vote');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(builder: (c) {
      final place = c.placeDetails;

      if (place == null) {
        return const Scaffold(
          backgroundColor: Color(0xFFF6F6F6),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF00693E), strokeWidth: 4),
          ),
        );
      }

      final hasSocials = place.website != null || place.instagram != null || place.phone != null;
      final hasTags = place.tags != null && place.tags!.isNotEmpty;

      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),

        // ── Sticky Vote CTA ───────────────────────────────────
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF6F6F6),
            border: Border(top: BorderSide(color: Colors.black, width: 2)),
          ),
          child: InkWell(
            onTap: () => _onVoteTap(place.id),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF00FC9B),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 26, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'DROP YOUR VIBE NOW',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              border: const Border(bottom: BorderSide(width: 2, color: Colors.black)),
              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
            ),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Get.back(),
                    highlightColor: Colors.transparent,
                    splashColor: const Color(0xFF00FC9B).withOpacity(0.3),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, color: Color(0xFF00693E), size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00693E),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {},
                    highlightColor: Colors.transparent,
                    splashColor: const Color(0xFF00FC9B).withOpacity(0.3),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.bookmark_border, color: Color(0xFF2D2F2F), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Hero Image ────────────────────────────────────
              Stack(
                children: [
                  Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
                      color: const Color(0xFFF0F1F1),
                    ),
                    child: CustomImage(
                      image: place.coverImage ?? place.image ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Logo overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
                        color: Colors.white,
                      ),
                      child: CustomImage(image: place.image ?? '', fit: BoxFit.cover),
                    ),
                  ),
                  // Open / Closed badge
                  if (place.isOpenNow != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: place.isOpenNow! ? const Color(0xFF00FC9B) : Colors.redAccent,
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
                        ),
                        child: Text(
                          place.isOpenNow! ? 'OPEN NOW' : 'CLOSED',
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Stats Block ────────────────────────────────────
              _buildStatsBar(place.votesCount, place.rating),
              const SizedBox(height: 16),

              // ── Title & Address ────────────────────────────────
              Text(
                place.title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF00693E)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place.address?.toUpperCase() ?? 'ADDRESS NOT PROVIDED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00693E),
                      ),
                    ),
                  ),
                ],
              ),
              if (place.categoryName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2F2F),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Text(
                    place.categoryName!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (hasTags) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: place.tags!.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text(
                        tag.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (hasSocials) ...[
                const SizedBox(height: 16),
                _buildSocialRow(place.website, place.instagram, place.phone),
              ],
              const SizedBox(height: 24),

              // ── What's The Vibe ───────────────────────────────
              _sectionHeader("WHAT'S THE VIBE TODAY?"),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
                    ),
                    child: Text(
                      place.description?.isNotEmpty == true ? place.description! : '—',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      color: const Color(0xFF00693E),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: const Text(
                        'VIBE CHECK',
                        style: TextStyle(
                          color: Color(0xFFCBFFDA),
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Photos From The Spot ──────────────────────────
              _sectionHeader('PHOTOS FROM THE SPOT'),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: _buildGallery(place, context),
                ),
              ),
              const SizedBox(height: 24),

              // ── How To Get Here ───────────────────────────────
              _sectionHeader('HOW TO GET HERE'),
              const SizedBox(height: 10),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
                ),
                clipBehavior: Clip.hardEdge,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(place.lat ?? 30.0311, place.lng ?? 31.2390),
                    zoom: 15,
                  ),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('place'),
                      position: LatLng(place.lat ?? 30.0311, place.lng ?? 31.2390),
                    ),
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Tap the button below to open in Google Maps',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary CTA — white/outline style
              InkWell(
                onTap: () {
                  // TODO: open in Google Maps / Apple Maps
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_outlined, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'GET DIRECTIONS',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── What Maadi Says ───────────────────────────────
              _sectionHeader('WHAT MAADI SAYS'),
              const SizedBox(height: 12),
              _buildReviews(c, place.id),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {},
                child: CustomPaint(
                  painter: DashedBorderPainter(),
                  child: const SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'SEE MORE FROM THE NEIGHBORHOOD',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Stats Bar ──────────────────────────────────────────────
  Widget _buildStatsBar(int votes, double rating) {
    final hasVotes = votes > 0;
    final votesLabel = votes >= 1000
        ? '${(votes / 1000).toStringAsFixed(1)}K'
        : votes.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_rounded,
                color: hasVotes ? const Color(0xFFFDD400) : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                hasVotes ? rating.toStringAsFixed(1) : 'No ratings yet',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: hasVotes ? 20 : 15,
                  fontWeight: FontWeight.w900,
                  color: hasVotes ? Colors.black : Colors.grey,
                ),
              ),
              if (hasVotes) ...[
                const SizedBox(width: 8),
                Text(
                  '· $votesLabel VOTES',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2F2F),
                  ),
                ),
              ],
            ],
          ),
          if (!hasVotes) ...[
            const SizedBox(height: 4),
            const Text(
              'Be the first local to vote',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00693E),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Social Row with Labels ─────────────────────────────────
  Widget _buildSocialRow(String? website, String? instagram, String? phone) {
    final items = <Map<String, dynamic>>[];
    if (website != null) items.add({'icon': Icons.language, 'label': 'WEBSITE', 'onTap': () {}});
    if (instagram != null) items.add({'icon': Icons.alternate_email, 'label': 'INSTAGRAM', 'onTap': () {}});
    if (phone != null) items.add({'icon': Icons.phone_outlined, 'label': 'CALL US', 'onTap': () {}});

    return Row(
      children: items.expand((item) {
        final idx = items.indexOf(item);
        return [
          InkWell(
            onTap: item['onTap'] as VoidCallback,
            highlightColor: Colors.transparent,
            splashColor: const Color(0xFF00FC9B).withOpacity(0.3),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
                  ),
                  child: Icon(item['icon'] as IconData, color: Colors.black, size: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2F2F),
                  ),
                ),
              ],
            ),
          ),
          if (idx < items.length - 1) const SizedBox(width: 16),
        ];
      }).toList(),
    );
  }

  // ── Gallery ────────────────────────────────────────────────
  List<Widget> _buildGallery(place, BuildContext context) {
    var gallery = place.gallery as List?;

    // Show mock photos if gallery is null/empty
    if (gallery == null || gallery.isEmpty) {
      final mockUrls = [
        'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=400&h=300&fit=crop',
        'https://images.unsplash.com/photo-1442512595331-e89e30ea369e?w=400&h=300&fit=crop',
        'https://images.unsplash.com/photo-1514432324607-2e467f4af445?w=400&h=300&fit=crop',
        'https://images.unsplash.com/photo-1459925985917-f1db0ab26ba9?w=400&h=300&fit=crop',
        'https://images.unsplash.com/photo-1493857671505-72967e2e2760?w=400&h=300&fit=crop',
      ];
      return mockUrls
          .take(5)
          .toList()
          .asMap()
          .entries
          .expand((e) => [
                _imageCard(e.value, e.key.isEven ? -0.015 : 0.015),
                if (e.key < mockUrls.length - 1) const SizedBox(width: 16),
              ])
          .toList();
    }

    if (gallery.isNotEmpty) {
      return gallery
          .take(5)
          .toList()
          .asMap()
          .entries
          .expand((e) => [
                _imageCard(e.value.image as String, e.key.isEven ? -0.015 : 0.015),
                if (e.key < gallery.length - 1) const SizedBox(width: 16),
              ])
          .toList();
    }

    return [
      SizedBox(
        width: MediaQuery.of(context).size.width - 24,
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.camera_alt_outlined, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'NO PHOTOS YET',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Be the first to drop your shots from here',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11,
                color: Color(0xFF00693E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Reviews ────────────────────────────────────────────────
  Widget _buildReviews(PlacesController c, int placeId) {
    if (c.isReviewsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF00693E), strokeWidth: 3)),
      );
    }

    var reviews = c.reviews;

    // Show mock reviews if empty
    if (reviews == null || reviews.isEmpty) {
      return _buildMockReviewsList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 36, color: Colors.grey),
            const SizedBox(height: 10),
            const Text(
              'NO ONE HAS SHARED THEIR VIBE YET',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Be the first local to drop a review',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _onVoteTap(placeId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
                ),
                child: const Text(
                  'DROP THE FIRST REVIEW',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final avatarColors = [
      const Color(0xFF00693E),
      const Color(0xFF6D5A00),
      const Color(0xFF1A237E),
      const Color(0xFF880E4F),
    ];

    return Column(
      children: List.generate(reviews.length, (i) {
        final r = reviews[i];
        final name = (r.userName?.isNotEmpty == true ? r.userName! : 'CITIZEN_${r.userId}').toUpperCase();
        final comment = r.comment ?? '';
        return Padding(
          padding: EdgeInsets.only(
            left: i.isEven ? 12 : 0,
            right: i.isOdd ? 12 : 0,
            bottom: i < reviews.length - 1 ? 16 : 0,
          ),
          child: _reviewCard(
            name,
            '${r.rating} ★ · ${_timeAgo(r.createdAt)}',
            comment,
            avatarColors[i % avatarColors.length],
            isNew: i == 0,
          ),
        );
      }),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }

  Widget _sectionHeader(String title) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF00693E), width: 3)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _imageCard(String url, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
        ),
        child: CustomImage(image: url, fit: BoxFit.cover),
      ),
    );
  }

  Widget _reviewCard(String name, String sub, String review, Color avatarColor,
      {String? rank, bool isNew = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 14,
                                fontWeight: FontWeight.w900)),
                        Text(sub.toUpperCase(),
                            style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (rank != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDD400),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text('RANK: $rank',
                          style: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('"$review"',
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.4)),
            ],
          ),
        ),
        if (isNew)
          Positioned(
            top: -10,
            right: -10,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Text('NEW ENTRY',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  // ── Mock Reviews Helper ────────────────────────────────────
  Widget _buildMockReviewsList() {
    final mockReviews = [
      {
        'userName': 'Ahmed Hassan',
        'userId': 123,
        'rating': 4.5,
        'comment': 'Amazing vibes and perfect coffee! The atmosphere is unmatched in Maadi.',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'userName': 'Sara Mohamed',
        'userId': 456,
        'rating': 5.0,
        'comment': 'Best spot in Maadi! Highly recommend for meetings and hangouts.',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'userName': 'Karim Farah',
        'userId': 789,
        'rating': 4.0,
        'comment': 'Cool place, great for studying and working. Quiet and focused.',
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      },
    ];

    final avatarColors = [
      const Color(0xFF00693E),
      const Color(0xFF6D5A00),
      const Color(0xFF1A237E),
      const Color(0xFF880E4F),
    ];

    return Column(
      children: List.generate(mockReviews.length, (i) {
        final r = mockReviews[i];
        final name = (r['userName'] as String?)?.isNotEmpty == true
            ? (r['userName'] as String).toUpperCase()
            : 'CITIZEN_${r['userId']}';
        final comment = r['comment'] as String? ?? '';
        final createdAt = r['createdAt'] as DateTime?;
        return Padding(
          padding: EdgeInsets.only(
            left: i.isEven ? 12 : 0,
            right: i.isOdd ? 12 : 0,
            bottom: i < mockReviews.length - 1 ? 16 : 0,
          ),
          child: _reviewCard(
            name,
            '${r['rating']} ★ · ${_timeAgo(createdAt)}',
            comment,
            avatarColors[i % avatarColors.length],
            isNew: i == 0,
          ),
        );
      }),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    const double dashWidth = 8, dashSpace = 5;
    double distance = 0;

    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(pathMetric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
