import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/spots_round.dart';
import 'package:waddy_app/features/places/widgets/place_gallery_viewer.dart';
import 'package:waddy_app/features/places/widgets/place_vote_action.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

// ── WADDI Spots design tokens ───────────────────────────────────
// Single source of truth is `Spots` (spots_theme.dart); these are local
// aliases so the screen reads the same shorthand it always has.
const _mint = Spots.mint;
const _teal = Spots.teal;
const _panel = Spots.panel;
const _ink = Spots.ink;
const _ink2 = Spots.ink2;
const _ink3 = Spots.ink3;
const _paper = Spots.paper;
const _paper2 = Spots.paperWarm; // the shared warm surface, not a local one
const _border = Spots.border;
const _green = Spots.green;
const _bg = Spots.canvas;

const _fontDisplay = AppConstants.displayFontFamily;
const _fontBody = AppConstants.fontFamily;

class PlaceDetailsScreen extends StatefulWidget {
  final int placeId;

  /// The spot as the tapped list already knew it. Present for every in-app
  /// open, absent for deep links and notification opens.
  ///
  /// The list payload carries everything above the fold — title, cover,
  /// rating, votes, category, address — so handing it over lets the screen
  /// paint on the first frame and lets the detail fetch fill in the rest
  /// (gallery, hours, links) underneath, instead of holding a full-screen
  /// skeleton over data the previous screen was already displaying.
  final Place? initialPlace;

  const PlaceDetailsScreen({
    super.key,
    required this.placeId,
    this.initialPlace,
  });

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<PlacesController>();
    // Seeded synchronously, before the first build: going through the
    // post-frame callback would still have flashed one skeleton frame.
    if (widget.initialPlace != null) {
      c.seedPlaceDetails(widget.initialPlace!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final c = Get.find<PlacesController>();
    // Reviews and vote status no longer queue behind the details call — they
    // fill different parts of the page and have no reason to be sequential.
    final details = c.getPlaceDetails(widget.placeId);
    c.getPlaceReviews(widget.placeId);
    if (AuthHelper.isLoggedIn()) c.getVoteStatus(widget.placeId);
    await details;
  }

  void _onVoteTap(int placeId) => openVoteSheet(placeId);

  void _onReviewTap(int placeId) => openReviewSheet(placeId);

  void _onUnvoteTap(int placeId) => unvotePlace(placeId);

  Future<void> _onFavoriteTap(PlacesController c, int placeId) async {
    // Soft wall: guest gets the phone→OTP sheet in place, favourite applies on
    // success. See docs/guest_mode_plan.md (auth-wall matrix).
    GuestGate.requireAccount(
      () => c.toggleFavorite(placeId),
      reason: 'place_favourite',
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      showCustomSnackBar('failed_to_open_link'.tr, isError: true);
    }
  }

  void _openWebsite(String website) {
    var url = website.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    _launch(url);
  }

  void _openInstagram(String handle) {
    var h = handle.trim();
    if (h.startsWith('http')) {
      _launch(h);
    } else {
      _launch('https://instagram.com/${h.replaceAll('@', '')}');
    }
  }

  void _openDirections(double? lat, double? lng) {
    if (lat == null || lng == null) {
      showCustomSnackBar('location_not_available'.tr, isError: true);
      return;
    }
    _launch('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idDetails,
      builder: (c) {
        final place = c.placeDetails;

        if (place == null) {
          if (c.isDetailsLoading) return const _DetailsSkeleton();
          return _errorScaffold(c);
        }

        return Scaffold(
          backgroundColor: _bg,
          bottomNavigationBar: _voteBar(context, c, place),
          // A CustomScrollView, not a SingleChildScrollView + Column: the
          // latter built and laid out the gallery, the embedded map and every
          // review card on the first frame and on every rebuild. Slivers build
          // as they approach the viewport. Same move as `G-03` on the grocery
          // store screen. See `S-05`.
          body: SafeArea(
            top: false,
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // The fixed sections stay eager — they are above the fold and
                // a hero that builds lazily is a hero that flashes.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(context, c, place),
                      const SizedBox(height: Spots.s32),
                      _statsOrPitch(place),

                      // A heading over a lone em-dash is worse than no
                      // heading: it promises a description and delivers
                      // punctuation.
                      if (place.description?.isNotEmpty == true)
                        _section(
                          title: 'about'.tr,
                          child: Text(
                            place.description!,
                            style: const TextStyle(
                              fontFamily: _fontBody,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.55,
                              color: _ink2,
                            ),
                          ),
                        ),

                      _photosSection(context, place),

                      _findThemSection(place),
                    ],
                  ),
                ),

                // Its own builder, so appending a page of reviews cannot
                // repaint the cover photo or re-inflate the GoogleMap above.
                GetBuilder<PlacesController>(
                  id: PlacesController.idReviews,
                  builder: (rc) => _reviewsSliver(context, rc, place.id),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: Spots.s32)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Error / offline ────────────────────────────────────────────
  Widget _errorScaffold(PlacesController c) {
    // The screen used to blame the network for every failure. A spot that was
    // delisted returns 404, and telling that user to check their connection
    // sends them to fight their wifi over a page that will never load.
    final int? status = c.detailsErrorStatus;
    final bool isMissing = status == 404 || status == 403;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _teal),
          tooltip: 'back'.tr,
          onPressed: () => Get.back(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMissing ? Icons.search_off_rounded : Icons.wifi_off_rounded,
              size: 42,
              color: _ink3,
            ),
            const SizedBox(height: Spots.s12),
            Text(
              isMissing ? 'spot_not_available'.tr : 'no_internet_connection'.tr,
              style: const TextStyle(
                fontFamily: _fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _ink3,
              ),
            ),
            const SizedBox(height: Spots.s16),
            // Retrying a 404 just fails again — offer the only move that works.
            _neoButton(
              onTap: isMissing ? () => Get.back() : _loadData,
              color: _mint,
              child: Text(
                displayCaps(isMissing ? 'go_back'.tr : 'retry'.tr),
                style: const TextStyle(
                  fontFamily: _fontDisplay,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _teal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────
  Widget _hero(BuildContext context, PlacesController c, Place place) {
    final topPad = MediaQuery.of(context).padding.top;
    final String cover = place.coverImage ?? place.image ?? '';
    final bool sameArt = cover.isNotEmpty && cover == (place.image ?? '');
    final zoneLine =
        place.zone?.displayName ?? place.zone?.name ?? place.address;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover image
        Container(
          height: 290 + topPad,
          width: double.infinity,
          color: Colors.black,
          child: CustomImage(image: cover, fit: BoxFit.cover),
        ),
        // Scrim
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                // The top stop was 0x1A — effectively clear — which left the
                // back/save buttons unprotected while the title below sat on
                // the dark end. Lifting it to 0x59 shades the status-bar strip
                // enough for white controls to read, without washing out the
                // photo's midtones.
                colors: [
                  Color(0xF210312E),
                  Color(0x6610312E),
                  Color(0x2610312E),
                  Color(0x5910312E),
                ],
                stops: [0.0, 0.45, 0.78, 1.0],
              ),
            ),
          ),
        ),

        // Top nav — back / favorite
        Positioned(
          top: topPad + 14,
          left: 14,
          right: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _heroNavButton(
                onTap: () => Get.back(),
                semanticLabel: 'back'.tr,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              _heroNavButton(
                onTap: () => _onFavoriteTap(c, place.id),
                semanticLabel:
                    (place.isFavorited ?? false)
                        ? 'remove_from_favourite'.tr
                        : 'add_to_favourite'.tr,
                child: Icon(
                  (place.isFavorited ?? false)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // Info block (category / name / zone)
        // Right inset clears the badge row (logo 64 + gutter + breathing room)
        // so a long title wraps instead of running under it. The titles pill
        // sits above the title's last line, not beside it, so it isn't part
        // of this reservation.
        Positioned(
          left: Spots.gutter,
          right: 92,
          bottom: Spots.s16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.categoryName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spots.s12,
                    vertical: Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    color: _mint,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusExtraLarge,
                    ),
                  ),
                  child: Text(
                    place.categoryName!.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: _fontDisplay,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: _teal,
                    ),
                  ),
                ),
              const SizedBox(height: Spots.s8),
              Text(
                place.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: _fontDisplay,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  height: 0.92,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              if (zoneLine != null && zoneLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1, right: 4),
                      child: SpotsGlyph(SpotsMark.pin, size: 12, color: _teal),
                    ),
                    Expanded(
                      child: Text(
                        zoneLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _mint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Logo badge.
        //
        // Was `bottom: -22` on a 60px badge inside a `Clip.none` stack, so it
        // hung 22px past the hero's edge and landed on whatever the body drew
        // first — colliding with the stat row / pitch card below. It also went
        // unclipped, so a square logo squared off its own rounded corners.
        // Now it sits inside the hero, on the gutter, above the scrim.
        Positioned(
          right: Spots.gutter,
          bottom: Spots.s16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Titles read as one unit — cup, count, done — instead of a
              // floating trophy at the other end of the hero that the eye had
              // to associate with this place on its own.
              if (place.titlesCount > 0) ...[
                _titlesPill(place.titlesCount),
                if (!sameArt) const SizedBox(width: Spots.s8),
              ],
              // When the cover IS the logo (common for chains whose only
              // artwork is their mark), the badge repeats the same image at
              // two sizes on one screen. Show it once.
              if (!sameArt) _logoBadge(place),
            ],
          ),
        ),
      ],
    );
  }

  /// Cup + count, read as one unit: "6× champion".
  Widget _titlesPill(int titles) {
    return Semantics(
      label: '$titles× ${'titles'.tr}',
      excludeSemantics: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Spots.s8),
        decoration: BoxDecoration(
          color: _mint,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: Colors.white, width: Spots.borderThin),
          boxShadow: Spots.shadow(dx: 3, dy: 3, color: Spots.teal900),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpotsTrophyGlyph(size: 26),
            const SizedBox(width: 3),
            Text(
              '$titles×',
              style: const TextStyle(
                fontFamily: _fontDisplay,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                height: 1,
                letterSpacing: -0.3,
                color: _teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The merchant mark, filling its frame edge to edge.
  ///
  /// Was 56px with the image letterboxed inside it, so a wide logo floated in
  /// a field of white and read as a placeholder rather than a brand.
  Widget _logoBadge(Place place) {
    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Colors.white, width: Spots.borderThick),
        // Was a 15px-blur drop shadow — the one soft shadow in a system whose
        // whole premise is hard, zero-blur offsets.
        boxShadow: Spots.shadow(dx: 3, dy: 3, color: Spots.teal900),
      ),
      child: CustomImage(
        image: place.image ?? '',
        fit: BoxFit.cover,
        width: 64,
        height: 64,
      ),
    );
  }

  Widget _heroNavButton({
    required VoidCallback onTap,
    required Widget child,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            // Was 0x73 (~45%). A cover photo is user-supplied, so the corner
            // behind these buttons can be any colour at all — here it's the
            // Costa roundel, and the chevron disappeared into it. 0xD9 (~85%)
            // separates the control from the photo whatever the photo is.
            color: const Color(0xD9134E4A),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: Colors.white, width: Spots.borderThin),
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Quick stats / new-spot pitch ───────────────────────────────
  //
  // A spot with no votes, no rating and no rank renders the stat row as
  // `0 / — / —`: three boxes of null in the heaviest border weight on the
  // screen, directly under the hero, telling the user "nothing happens here".
  // Two em-dashes are not data, and `— IN CAFES` isn't even a sentence — the
  // label assumes a rank sits above it. When there is nothing to report, the
  // space is better spent explaining the game the user is being asked to play.
  Widget _statsOrPitch(Place place) {
    final bool hasAnyStat =
        place.votesCount > 0 || place.rating > 0 || place.rank != null;
    return hasAnyStat ? _quickStatRow(place) : _newSpotPitch(place);
  }

  /// Shown in place of an all-empty stat row: what a vote is, and when the
  /// round closes. The deadline comes from [SpotsRound] so this card can never
  /// state a different lock time than the countdown elsewhere in the app.
  Widget _newSpotPitch(Place place) {
    final left = SpotsRound.remaining();
    final bool closed = left == Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spots.gutter),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: _mint,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: _border, width: Spots.borderThick),
          boxShadow: Spots.shadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SpotsGlyph(SpotsMark.flame, size: 16, color: _teal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayCaps('no_votes_yet_headline'.tr),
                    style: const TextStyle(
                      fontFamily: _fontDisplay,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1,
                      letterSpacing: -0.2,
                      color: _teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              closed
                  ? 'new_spot_pitch_closed'.tr
                  : 'new_spot_pitch'.trParams({'time': SpotsRound.short(left)}),
              style: const TextStyle(
                fontFamily: _fontBody,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: _teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStatRow(Place place) {
    final votes = place.votesCount;
    final votesLabel =
        votes >= 1000
            ? '${(votes / 1000).toStringAsFixed(1)}K'
            : votes.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spots.gutter),
      child: Row(
        children: [
          _statBox(value: votesLabel, sub: displayCaps('votes'.tr)),
          const SizedBox(width: 10),
          _statBox(
            value: place.rating > 0 ? place.rating.toStringAsFixed(1) : '—',
            valueSuffix: place.rating > 0 ? '★' : null,
            sub: displayCaps('rating'.tr),
          ),
          const SizedBox(width: 10),
          // Only claim a category placing when there *is* one. Rendering
          // `— / IN CAFES` splits a value across a label that presumes it,
          // and reads as a broken sentence rather than "not ranked yet".
          _statBox(
            value: place.rank != null ? '#${place.rank}' : '—',
            sub: displayCaps(
              place.rank != null && place.categoryName != null
                  ? '${'in'.tr} ${place.categoryName!}'
                  : place.rank != null
                  ? 'rank'.tr
                  : 'unranked'.tr,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required String value,
    String? valueSuffix,
    required String sub,
  }) {
    return Expanded(
      // Read as one fact ("0 votes") rather than two stray fragments — the
      // value and its label are separate Text nodes in the same box.
      child: Semantics(
        label: '$value $sub',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: _paper2,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: _border, width: Spots.borderThick),
          ),
          child: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontFamily: _fontDisplay,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1,
                    color: _teal,
                  ),
                  children:
                      valueSuffix != null
                          ? [
                            TextSpan(
                              text: ' $valueSuffix',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _green,
                              ),
                            ),
                          ]
                          : null,
                ),
              ),
              const SizedBox(height: Spots.s4),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _fontBody,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 0.4,
                  color: _ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photos ─────────────────────────────────────────────────────
  Widget _photosSection(BuildContext context, Place place) {
    final gallery = place.gallery;
    if (gallery == null || gallery.isEmpty) {
      return _section(
        title: 'photos'.tr,
        child: _emptyBox(
          icon: Icons.camera_alt_outlined,
          title: 'no_photos_yet'.tr,
          sub: 'be_the_first_to_drop_your_shots'.tr,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spots.gutter,
            Spots.sectionGap,
            Spots.gutter,
            0,
          ),
          child: _sectionTitle('photos'.tr),
        ),
        const SizedBox(height: Spots.s16),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(
              Spots.gutter,
              2,
              Spots.gutter,
              4,
            ),
            itemCount: gallery.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spots.s12),
            itemBuilder: (_, i) {
              // The last thumbnail carries the total, because the strip clips
              // it mid-photo and that bleed is otherwise the only signal that
              // more exist.
              final bool isLast = i == gallery.length - 1;
              return _PressableButton(
                onTap: () => openPlaceGallery(gallery, i),
                child: Container(
                  width: 148,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    border: Border.all(
                      color: _border,
                      width: Spots.borderThick,
                    ),
                    boxShadow: Spots.shadow(),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'place_photo_${gallery[i].id}',
                        child: CustomImage(
                          image: gallery[i].image,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isLast && gallery.length > 1)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _mint,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusSmall,
                              ),
                              border: Border.all(color: _border, width: 2),
                            ),
                            child: Text(
                              '${gallery.length}',
                              style: const TextStyle(
                                fontFamily: _fontDisplay,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: _teal,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Find them (socials) ────────────────────────────────────────
  Widget _findThemSection(Place place) {
    final rows = <Widget>[];

    if (place.instagram != null && place.instagram!.isNotEmpty) {
      rows.add(
        _socialRow(
          icon: Icons.camera_alt_rounded,
          label: _instagramLabel(place.instagram!),
          sub: 'instagram'.tr,
          onTap: () => _openInstagram(place.instagram!),
        ),
      );
    }
    if (place.website != null && place.website!.isNotEmpty) {
      // Merchants routinely put a social profile in the `website` field, so
      // the row rendered `Website / https://instagram.com/1980.coffee/?hl=…`:
      // wrong label, and a raw truncated URL where every other row shows a
      // human string. Name the destination instead of printing its address.
      final site = _describeLink(place.website!);
      // ...and when BOTH fields hold the same Instagram profile, that produced
      // two identical rows pointing at one destination.
      final bool duplicateOfInstagram =
          site.isInstagram &&
          place.instagram != null &&
          place.instagram!.isNotEmpty;
      if (!duplicateOfInstagram) {
        rows.add(
          _socialRow(
            icon: site.icon,
            label: site.label,
            sub: site.sub,
            onTap:
                () =>
                    site.isInstagram
                        ? _openInstagram(place.website!)
                        : _openWebsite(place.website!),
          ),
        );
      }
    }
    if (place.phone != null && place.phone!.isNotEmpty) {
      rows.add(
        _socialRow(
          icon: Icons.call_rounded,
          label: 'call_us'.tr,
          sub: place.phone!,
          onTap: () => _launch('tel:${place.phone}'),
        ),
      );
    }
    rows.add(
      _socialRow(
        icon: Icons.near_me_rounded,
        label: 'get_directions'.tr,
        sub: place.address ?? place.zone?.displayName ?? '',
        onTap: () => _openDirections(place.lat, place.lng),
      ),
    );

    final bool hasCoords = place.lat != null && place.lng != null;

    return _section(
      title: 'find_them'.tr,
      child: Column(
        children: [
          // A lite-mode map preview: built long ago, never mounted, so the
          // screen showed a text address where a picture of the place on a
          // street already existed.
          if (hasCoords) ...[_map(place), const SizedBox(height: Spots.s16)],
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: Spots.s8),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Reads a URL and reports what it actually points at, so the row can name
  /// the destination ("@1980.coffee / Instagram") rather than print it.
  _LinkDescriptor _describeLink(String url) {
    final u = url.trim().toLowerCase();
    if (u.contains('instagram.com')) {
      return _LinkDescriptor(
        icon: Icons.camera_alt_rounded,
        label: _instagramLabel(url),
        sub: 'instagram'.tr,
        isInstagram: true,
      );
    }
    if (u.contains('facebook.com') || u.contains('fb.me')) {
      return _LinkDescriptor(
        icon: Icons.facebook_rounded,
        label: 'facebook'.tr,
        sub: _prettyHost(url),
      );
    }
    if (u.contains('tiktok.com')) {
      return _LinkDescriptor(
        icon: Icons.music_note_rounded,
        label: 'tiktok'.tr,
        sub: _prettyHost(url),
      );
    }
    return _LinkDescriptor(
      icon: Icons.language_rounded,
      label: 'website'.tr,
      sub: _prettyHost(url),
    );
  }

  /// `https://www.example.com/menu?ref=x` → `example.com`. A bare host reads
  /// as a place you can go; a full URL with a query string reads as debug
  /// output.
  String _prettyHost(String url) {
    var raw = url.trim();
    if (!raw.startsWith('http')) raw = 'https://$raw';
    final host = Uri.tryParse(raw)?.host ?? '';
    if (host.isEmpty) return url.trim();
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String _instagramLabel(String handle) {
    final h = handle.trim();
    if (h.startsWith('http')) {
      // Was `h.split('/').last`, which on the extremely common
      // `instagram.com/Starbucks/?hl=en` returned the QUERY STRING — the row
      // rendered "@?hl=en". Parse the URL properly and take the first real
      // path segment, which is the handle.
      final uri = Uri.tryParse(h);
      final seg =
          uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
      if (seg.isNotEmpty) return '@${seg.first}';
      return '@${h.replaceAll('@', '')}';
    }
    return h.startsWith('@') ? h : '@$h';
  }

  Widget _socialRow({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium,
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: Spots.card(radius: Dimensions.radiusDefault),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _paper2,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                border: Border.all(color: _border, width: Spots.borderThin),
              ),
              child: Icon(icon, size: 19, color: _teal),
            ),
            const SizedBox(width: Spots.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _fontDisplay,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: _fontBody,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: _ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '→',
              style: TextStyle(
                fontFamily: _fontDisplay,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: _teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────
  /// Only mounted when the spot has coordinates, so the old Cairo-centre
  /// fallbacks are gone: a map silently centred on the wrong city is worse
  /// than no map.
  Widget _map(Place place) {
    final target = LatLng(place.lat!, place.lng!);
    return GestureDetector(
      // Lite mode renders a static tile that swallows gestures without acting
      // on them, so the whole preview becomes one button to the real thing.
      onTap: () => _openDirections(place.lat, place.lng),
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: _border, width: Spots.borderThick),
          boxShadow: Spots.shadow(),
        ),
        clipBehavior: Clip.hardEdge,
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: target, zoom: 15),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                scrollGesturesEnabled: false,
                liteModeEnabled: true,
                markers: {
                  Marker(markerId: const MarkerId('place'), position: target),
                },
              ),
              // Google's own POI labels render in magenta and full-saturation
              // road colours that belong to no part of this palette, and they
              // shout louder than the pin they surround. A light teal wash
              // knocks them back so our marker stays the subject; lite mode
              // gives no style JSON to do this properly.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Spots.canvas.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reviews ────────────────────────────────────────────────────
  /// The reviews block, as slivers.
  ///
  /// Was an eager `for` loop inside a `Column` inside a `SingleChildScrollView`
  /// — so every review already loaded was rebuilt whenever another page
  /// arrived, along with the hero and the map above it. The cards are now a
  /// `SliverList.builder`, and the header, composer button and footer are
  /// their own small adapters around it. See `S-05`.
  Widget _reviewsSliver(BuildContext context, PlacesController c, int placeId) {
    final reviews = c.reviews;

    // First page in flight with nothing to show yet.
    if (c.isReviewsLoading && (reviews == null || reviews.isEmpty)) {
      return SliverToBoxAdapter(
        child: _section(
          title: 'what_locals_say'.tr,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeExtraLarge,
            ),
            child: Center(
              child: CircularProgressIndicator(color: _teal, strokeWidth: 3),
            ),
          ),
        ),
      );
    }

    if (reviews == null || reviews.isEmpty) {
      return SliverToBoxAdapter(
        child: _section(
          title: 'what_locals_say'.tr,
          child: _emptyBox(
            icon: Icons.chat_bubble_outline,
            title: 'no_reviews_yet'.tr,
            sub: 'be_the_first_local_to_review'.tr,
            cta: 'drop_the_first_review'.tr,
            onCta: () => _onReviewTap(placeId),
          ),
        ),
      );
    }

    // Deterministic per-reviewer tint, drawn from the Spots palette rather
    // than Material's stock indigo/pink, which appear nowhere else here.
    const avatarColors = [_teal, Spots.panel, Spots.teal900, Spots.ink2];

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _section(
            title: 'what_locals_say'.tr,
            // With reviews present the empty state's CTA is gone, so this is
            // the only way to add one — without it, reviewing is reachable
            // exactly once per spot, by whoever gets there first.
            child: _neoButton(
              onTap: () => _onReviewTap(placeId),
              color: c.voteStatus?.hasReviewed == true ? _paper2 : _paper,
              fullWidth: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    c.voteStatus?.hasReviewed == true
                        ? Icons.edit_outlined
                        : Icons.rate_review_outlined,
                    color: _teal,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayCaps(
                      c.voteStatus?.hasReviewed == true
                          ? 'edit_your_review'.tr
                          : 'write_a_review'.tr,
                    ),
                    style: const TextStyle(
                      fontFamily: _fontDisplay,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Spots.gutter,
            Spots.s16,
            Spots.gutter,
            0,
          ),
          sliver: SliverList.separated(
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: Spots.s12),
            itemBuilder:
                (_, i) => _reviewCard(
                  reviews[i],
                  avatarColors[i % avatarColors.length],
                ),
          ),
        ),

        if (c.hasMoreReviews)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spots.gutter,
                Spots.s16,
                Spots.gutter,
                0,
              ),
              child: InkWell(
                onTap:
                    c.isLoadingMoreReviews
                        ? null
                        : () => c.getPlaceReviews(
                          placeId,
                          offset: c.nextReviewsPage,
                        ),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeMedium,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _paper2,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    border: Border.all(color: _border, width: Spots.borderThin),
                  ),
                  // `isReviewsLoading` covers the first page only, so this
                  // spinner branch was unreachable — the button showed its
                  // label for the whole round trip. `isLoadingMoreReviews` is
                  // the flag the controller keeps for exactly this.
                  child:
                      c.isLoadingMoreReviews
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _teal,
                            ),
                          )
                          : Text(
                            'load_more_reviews'.tr.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: _fontDisplay,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: _teal,
                            ),
                          ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reviewCard(review, Color avatarColor) {
    final name =
        review.userName?.isNotEmpty == true
            ? review.userName!.toString()
            : 'a_local'.tr;
    final comment = review.comment ?? '';

    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: Spots.card(radius: Dimensions.radiusDefault),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  border: Border.all(color: _border, width: Spots.borderThin),
                ),
                child:
                    (review.userImage != null &&
                            (review.userImage as String).isNotEmpty)
                        ? CustomImage(
                          image: review.userImage,
                          fit: BoxFit.cover,
                        )
                        : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
              ),
              const SizedBox(width: Spots.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: _fontDisplay,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${review.rating} ★ · ${_timeAgo(review.createdAt)}',
                      style: const TextStyle(
                        fontFamily: _fontBody,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: _ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: Spots.s12),
            Text(
              '"$comment"',
              style: const TextStyle(
                fontFamily: _fontBody,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.45,
                color: _ink2,
              ),
            ),
          ],
          if (review.imageUrl != null &&
              (review.imageUrl as String).isNotEmpty) ...[
            const SizedBox(height: Spots.s12),
            Container(
              height: 120,
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                border: Border.all(color: _border, width: Spots.borderThin),
              ),
              child: CustomImage(image: review.imageUrl, fit: BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    // Was three hardcoded English suffixes ('mo ago' / 'd ago' / 'h ago')
    // sitting next to a translated 'just_now' — half the ladder localised.
    if (diff.inDays > 30) {
      return 'months_ago_count'.trParams({
        'count': '${(diff.inDays / 30).floor()}',
      });
    }
    if (diff.inDays > 0) {
      return 'days_ago_count'.trParams({'count': '${diff.inDays}'});
    }
    if (diff.inHours > 0) {
      return 'hours_ago_count'.trParams({'count': '${diff.inHours}'});
    }
    return 'just_now'.tr;
  }

  // ── Vote bar (dark panel) ──────────────────────────────────────
  Widget _voteBar(BuildContext context, PlacesController c, Place place) {
    final votes = place.votesCount;
    final votesLabel =
        votes >= 1000
            ? '${(votes / 1000).toStringAsFixed(1)}K'
            : votes.toString();

    // Whether *this user* has backed *this spot* — the bar previously looked
    // identical before and after voting, so the one thing the user most needs
    // to know here was the one thing it never said.
    final bool hasVoted = c.voteStatus?.hasVoted ?? false;
    final Duration left = SpotsRound.remaining();
    final bool closed = left == Duration.zero;

    // Second line: the round stakes, not a restatement of the vote count
    // sitting directly above it.
    final String subLine =
        closed
            ? 'round_closed'.tr
            : hasVoted
            ? 'your_vote_is_here'.tr
            : 'time_left_in_round'.trParams({'time': SpotsRound.short(left)});

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(
          top: BorderSide(color: _border, width: Spots.borderThick),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$votesLabel ${votes == 1 ? 'vote_one'.tr : 'votes'.tr}',
                  style: const TextStyle(
                    fontFamily: _fontDisplay,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayCaps(subLine),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontBody,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.4,
                    color: closed ? _ink3 : _mint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spots.s12),
          _PressableButton(
            // Backed already? The button is now UNVOTE and must actually
            // unvote. Routing it into the review sheet made the one control
            // labelled with a state also be the control that can't change it.
            onTap:
                () => hasVoted ? _onUnvoteTap(place.id) : _onVoteTap(place.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 26,
                vertical: Dimensions.paddingSizeMedium,
              ),
              decoration: BoxDecoration(
                color: hasVoted ? _paper : _mint,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(color: _border, width: Spots.borderThin),
                // A mint shadow under a mint button is invisible: the press
                // animation had nothing to collapse into. Teal, like every
                // other shadow in the system.
                boxShadow: Spots.shadow(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasVoted) ...[
                    const Icon(Icons.check, size: 16, color: _teal),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    displayCaps(hasVoted ? 'unvote'.tr : 'vote'.tr),
                    style: const TextStyle(
                      fontFamily: _fontDisplay,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.3,
                      color: _teal,
                    ),
                  ),
                  if (!hasVoted) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '→',
                      style: TextStyle(
                        fontFamily: _fontDisplay,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: _teal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared building blocks ─────────────────────────────────────
  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spots.gutter,
        Spots.sectionGap,
        Spots.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          const SizedBox(height: Spots.s12),
          child,
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: _fontDisplay,
        fontWeight: FontWeight.w900,
        fontSize: 18,
        height: 0.95,
        letterSpacing: -0.3,
        color: _ink,
      ),
    );
  }

  Widget _emptyBox({
    required IconData icon,
    required String title,
    required String sub,
    String? cta,
    VoidCallback? onCta,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 26,
        horizontal: Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: _paper2,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: _border, width: Spots.borderThick),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: _ink3),
          const SizedBox(height: Spots.s8),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _fontDisplay,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: _ink2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _fontBody,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: _ink3,
            ),
          ),
          if (cta != null && onCta != null) ...[
            const SizedBox(height: Spots.s16),
            _neoButton(
              onTap: onCta,
              color: _mint,
              child: Text(
                cta.toUpperCase(),
                style: const TextStyle(
                  fontFamily: _fontDisplay,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: _teal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _neoButton({
    required VoidCallback onTap,
    required Color color,
    required Widget child,
    bool fullWidth = false,
  }) {
    return _PressableButton(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeLarge,
          vertical: Dimensions.paddingSizeMedium,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: _border, width: Spots.borderThin),
          boxShadow: Spots.shadow(),
        ),
        child: child,
      ),
    );
  }
}

/// What a link points at: the icon, the human label, and the quiet sub-line.
class _LinkDescriptor {
  const _LinkDescriptor({
    required this.icon,
    required this.label,
    required this.sub,
    this.isInstagram = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool isInstagram;
}

/// Neubrutalist press: element slides into its own shadow.
class _PressableButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _PressableButton({required this.onTap, required this.child});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(_down ? 2 : 0, _down ? 2 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Loading state shaped like the real screen (hero, stat row, two sections)
/// instead of a bare centred spinner.
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpotsSkeleton(
              height: 260 + MediaQuery.of(context).padding.top,
              radius: 0,
            ),
            const SizedBox(height: Spots.s24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Spots.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: SpotsSkeleton(height: 68)),
                      SizedBox(width: Spots.s12),
                      Expanded(child: SpotsSkeleton(height: 68)),
                      SizedBox(width: Spots.s12),
                      Expanded(child: SpotsSkeleton(height: 68)),
                    ],
                  ),
                  SizedBox(height: Spots.s32),
                  SpotsSkeleton(height: 18, width: 120, radius: Spots.radiusSm),
                  SizedBox(height: Spots.s12),
                  SpotsSkeleton(height: 92),
                  SizedBox(height: Spots.s32),
                  SpotsSkeleton(height: 18, width: 160, radius: Spots.radiusSm),
                  SizedBox(height: Spots.s12),
                  SpotsSkeleton(height: 92),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
