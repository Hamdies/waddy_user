import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/util/styles.dart';

/// Full-screen, pinch-zoomable gallery for a spot's photos.
///
/// The thumbnails on the details screen wear the system's pressable costume —
/// 3px border plus a hard offset shadow, exactly like the Find Them rows and
/// the vote button — but had no tap handler at all. Users poke them, get
/// nothing, and learn to distrust the affordance everywhere else on the page.
/// This is the destination that costume was promising.
void openPlaceGallery(List<PlaceImage> gallery, int initialIndex) {
  if (gallery.isEmpty) return;
  Get.to(
    () => _PlaceGalleryViewer(gallery: gallery, initialIndex: initialIndex),
    opaque: false,
    fullscreenDialog: true,
  );
}

class _PlaceGalleryViewer extends StatefulWidget {
  const _PlaceGalleryViewer({
    required this.gallery,
    required this.initialIndex,
  });

  final List<PlaceImage> gallery;
  final int initialIndex;

  @override
  State<_PlaceGalleryViewer> createState() => _PlaceGalleryViewerState();
}

class _PlaceGalleryViewerState extends State<_PlaceGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Spots.ink,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.gallery.length,
            onPageChanged: (i) => setState(() => _index = i),
            backgroundDecoration: const BoxDecoration(color: Spots.ink),
            loadingBuilder:
                (_, __) => const Center(
                  child: CircularProgressIndicator(
                    color: Spots.mint,
                    strokeWidth: 3,
                  ),
                ),
            builder:
                (_, i) => PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(widget.gallery[i].image),
                  // Zoom out to the whole photo, in far enough to read a menu
                  // board — past that it's just pixels.
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: 'place_photo_${widget.gallery[i].id}',
                  ),
                ),
          ),

          // Close — mirrors the hero's nav buttons so the way out is where the
          // way in was.
          Positioned(
            top: top + 14,
            left: 14,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Get.back(),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Spots.teal.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(Spots.radiusMd),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Counter — the details strip clips the last thumbnail, which is the
          // only hint more photos exist; this says how many.
          if (widget.gallery.length > 1)
            Positioned(
              top: top + 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spots.s12,
                  vertical: Spots.s8,
                ),
                decoration: BoxDecoration(
                  color: Spots.mint,
                  borderRadius: BorderRadius.circular(Spots.radiusMd),
                  border: Border.all(color: Spots.border, width: 2.5),
                ),
                child: Text(
                  '${_index + 1}/${widget.gallery.length}',
                  style: waddyDisplayFace(13, color: Spots.teal),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
