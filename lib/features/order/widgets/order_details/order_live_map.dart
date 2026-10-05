import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/helper/marker_helper.dart';
import 'package:waddy_app/helper/rider_camera.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';

/// The full-bleed map behind the order screen once the rider is close
/// (LT-02/03/04).
///
/// Two markers — the rider's helmet and a home pin — and nothing between
/// them. A new fix arrives about every 10 s; the rider glides there over
/// roughly the same time, so it reads as one continuous ride instead of hops.
/// The camera fits both points and re-fits only when the rider has moved on
/// enough to matter. Once the user pans the map themselves it stops following
/// until they tap recentre.
class OrderLiveMap extends StatefulWidget {
  final LatLng rider;
  final LatLng home;

  /// Map area hidden under the status bar and the sheet; the camera frames
  /// the points inside what is left.
  final EdgeInsets insets;

  const OrderLiveMap({
    super.key,
    required this.rider,
    required this.home,
    required this.insets,
  });

  @override
  State<OrderLiveMap> createState() => _OrderLiveMapState();
}

class _OrderLiveMapState extends State<OrderLiveMap>
    with SingleTickerProviderStateMixin {
  /// Hides Google's own business and transit pins, which otherwise compete
  /// with ours.
  static const String _quietStyle = '''[
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.attraction", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]''';

  /// A jump longer than this is a GPS glitch or a stale fix, not a ride;
  /// snap instead of sliding the rider across the city.
  static const double _maxGlideMeters = 2000;

  /// Just under the 10 s between fixes, so the rider is still moving when
  /// the next one lands.
  static const Duration _glideTime = Duration(milliseconds: 9500);

  /// Each marker move crosses the platform channel; ~12 a second is smooth
  /// at street zoom without flooding it.
  static const int _glideFrameMs = 80;

  /// Re-fit the camera once the rider has moved this far since the last fit.
  static const double _refitMeters = 60;

  GoogleMapController? _controller;
  late final AnimationController _glide;
  late LatLng _from;
  late LatLng _to;
  LatLng _shown = const LatLng(0, 0);
  final Stopwatch _sinceFrame = Stopwatch()..start();

  /// Where the rider was when the camera last framed.
  LatLng? _framedAt;

  /// True while the camera moves because we asked it to.
  bool _cameraOurs = false;

  /// The user has panned or zoomed; stop auto-framing until recentre.
  bool _userMoved = false;

  static Future<BitmapDescriptor>? _homeDraw;
  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _homeIcon;

  @override
  void initState() {
    super.initState();
    _from = _to = _shown = widget.rider;
    _glide = AnimationController(vsync: this, duration: _glideTime)
      ..addListener(_onGlide);
    _homeDraw ??= _homePin();
    MarkerHelper.riderMarker().then((icon) {
      if (mounted) setState(() => _riderIcon = icon);
    });
    _homeDraw!.then((icon) {
      if (mounted) setState(() => _homeIcon = icon);
    });
  }

  @override
  void didUpdateWidget(covariant OrderLiveMap old) {
    super.didUpdateWidget(old);
    if (widget.insets != old.insets) _frame(force: true);
    if (widget.rider == _to) return;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion ||
        RiderCamera.meters(_shown, widget.rider) > _maxGlideMeters) {
      _glide.stop();
      // A rebuild follows didUpdateWidget; no setState needed.
      _from = _to = _shown = widget.rider;
    } else {
      _from = _shown;
      _to = widget.rider;
      _glide.forward(from: 0);
    }
    _frame();
  }

  void _onGlide() {
    final bool last = _glide.value >= 1;
    if (!last && _sinceFrame.elapsedMilliseconds < _glideFrameMs) return;
    _sinceFrame.reset();
    final double t = _glide.value;
    setState(() {
      _shown = LatLng(
        _from.latitude + (_to.latitude - _from.latitude) * t,
        _from.longitude + (_to.longitude - _from.longitude) * t,
      );
    });
  }

  @override
  void dispose() {
    _glide.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Frames rider and home together. Skipped while the user is looking
  /// around, and while the rider hasn't moved far since the last fit.
  void _frame({bool animate = true, bool force = false}) {
    final GoogleMapController? c = _controller;
    if (c == null || (_userMoved && !force)) return;
    final LatLng? at = _framedAt;
    if (!force &&
        at != null &&
        RiderCamera.meters(at, widget.rider) < _refitMeters) {
      return;
    }
    _framedAt = widget.rider;
    _cameraOurs = true;
    final CameraUpdate update = RiderCamera.frame(widget.rider, widget.home);
    animate ? c.animateCamera(update) : c.moveCamera(update);
  }

  void _recentre() {
    setState(() => _userMoved = false);
    _frame(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_homeIcon != null)
        Marker(
          markerId: const MarkerId('home'),
          position: widget.home,
          icon: _homeIcon!,
          // The pin's tip sits on the address.
          anchor: const Offset(0.5, 1),
        ),
      if (_riderIcon != null)
        Marker(
          markerId: const MarkerId('rider'),
          position: _shown,
          icon: _riderIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1,
        ),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.rider,
              zoom: 16,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(
              11,
              RiderCamera.maxZoom,
            ),
            padding: widget.insets,
            style: _quietStyle,
            markers: markers,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            onCameraMoveStarted: () {
              if (!_cameraOurs && !_userMoved) {
                setState(() => _userMoved = true);
              }
            },
            onCameraIdle: () => _cameraOurs = false,
            onMapCreated: (c) {
              _controller = c;
              // The first frame lands framed, without a camera fly-in.
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _frame(animate: false, force: true),
              );
            },
          ),
        ),
        PositionedDirectional(
          end: Dimensions.paddingSizeDefault,
          bottom: widget.insets.bottom + Dimensions.paddingSizeDefault,
          child: AnimatedScale(
            scale: _userMoved ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Semantics(
              button: true,
              label: 'od_map_recentre'.tr,
              child: Material(
                color: WaddyColors.surface,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: WaddyColors.ink.withValues(alpha: 0.3),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recentre,
                  child: const SizedBox(
                    width: Dimensions.minTapTarget,
                    height: Dimensions.minTapTarget,
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 22,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Marker artwork ───────────────────────────────────────────────────────
  // Drawn once per app run and shared by every order screen.

  /// An ink teardrop with a white house glyph and a soft ground shadow at its
  /// tip, rendered at 3× and handed to the map at logical size.
  static Future<BitmapDescriptor> _homePin() async {
    const double dpr = 3;
    const double head = 34; // disc diameter
    const double tail = 12; // disc bottom → tip
    const double width = head + 8;
    const double height = head + tail + 4;
    const double px = width * dpr;
    const double py = height * dpr;
    const double r = head / 2 * dpr;
    const Offset c = Offset(px / 2, (4 + head / 2) * dpr);
    const Offset tip = Offset(px / 2, (4 + head + tail) * dpr - 2 * dpr);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Ground shadow under the tip.
    canvas.drawOval(
      Rect.fromCenter(center: tip, width: 12 * dpr, height: 4 * dpr),
      Paint()
        ..color = WaddyColors.ink.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5 * dpr),
    );

    final Path pin =
        Path()
          ..addOval(Rect.fromCircle(center: c, radius: r))
          ..moveTo(c.dx - r * 0.55, c.dy + r * 0.8)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(c.dx + r * 0.55, c.dy + r * 0.8)
          ..close();
    canvas.drawPath(
      pin.shift(const Offset(0, 1.5 * dpr)),
      Paint()
        ..color = WaddyColors.ink.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3 * dpr),
    );
    canvas.drawPath(pin, Paint()..color = WaddyColors.ink);

    const IconData glyph = Icons.home_outlined;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          fontSize: head * 0.6 * dpr,
          color: WaddyColors.surface,
        ),
      ),
    )..layout();
    painter.paint(canvas, c - Offset(painter.width / 2, painter.height / 2));

    final ui.Image image = await recorder.endRecording().toImage(
      px.round(),
      py.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }
}
