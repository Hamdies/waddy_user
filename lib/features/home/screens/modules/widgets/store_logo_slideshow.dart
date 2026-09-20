import 'dart:async';
import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Cycles through store logos on its own timer so only this tile rebuilds —
/// the parent module screen must never rebuild for the slideshow.
class StoreLogoSlideshow extends StatefulWidget {
  final List<Store> stores;
  final double size;
  final Widget fallback;

  const StoreLogoSlideshow({
    super.key,
    required this.stores,
    required this.fallback,
    this.size = 66,
  });

  @override
  State<StoreLogoSlideshow> createState() => _StoreLogoSlideshowState();
}

class _StoreLogoSlideshowState extends State<StoreLogoSlideshow>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stores.isEmpty) return widget.fallback;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: CustomImage(
        key: ValueKey<int>(_index % widget.stores.length),
        image: widget.stores[_index % widget.stores.length].logoFullUrl ?? '',
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
