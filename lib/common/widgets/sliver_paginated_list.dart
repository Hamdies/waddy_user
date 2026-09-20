import 'package:flutter/material.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Sliver counterpart to [PaginatedListView].
///
/// The box version renders its page as `Column(children: stores.map(...))`,
/// which builds every card the moment the list is laid out. Inside a home
/// screen that is itself one big `Column`, that meant the whole catalogue —
/// cards, images, shadows and all — was constructed in the first frame and
/// rebuilt on every controller update, however far below the fold it sat.
///
/// This builds through `SliverList.builder`, so the viewport decides what
/// exists. The pagination behaviour is deliberately identical: same trigger
/// (scrolled to `maxScrollExtent`), same page bookkeeping, same trailing
/// spinner — only the laziness differs.
class SliverPaginatedList extends StatefulWidget {
  final ScrollController scrollController;
  final Future<void> Function(int? offset) onPaginate;
  final int? totalSize;
  final int? offset;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final int itemsPerPage;
  final bool enabledPagination;

  /// Padding applied around the list body only — the spinner keeps its own
  /// centring, and a bottom reserve belongs on the footer so it sits below the
  /// spinner rather than between it and the last card.
  final EdgeInsetsGeometry padding;

  /// Extra space under the footer. The dashboard's bottom nav is a `Stack`
  /// overlay rather than a `bottomNavigationBar`, so nothing subtracts its
  /// height from the scroll view and a terminal list has to reserve it.
  final double bottomReserve;

  const SliverPaginatedList({
    super.key,
    required this.scrollController,
    required this.onPaginate,
    required this.totalSize,
    required this.offset,
    required this.itemCount,
    required this.itemBuilder,
    this.itemsPerPage = 10,
    this.enabledPagination = true,
    this.padding = EdgeInsets.zero,
    this.bottomReserve = 0,
  });

  @override
  State<SliverPaginatedList> createState() => _SliverPaginatedListState();
}

class _SliverPaginatedListState extends State<SliverPaginatedList> {
  int? _offset;
  late List<int?> _offsetList;
  bool _isLoading = false;

  /// Held so it can be detached in dispose.
  ///
  /// The controller here is owned by the home screen and outlives this widget,
  /// so an anonymous closure would leak: every module switch or remount would
  /// add another listener that runs on each scroll frame and holds a dead
  /// State alive. Same reasoning as [PaginatedListView].
  late final VoidCallback _scrollListener;

  @override
  void initState() {
    super.initState();
    _offset = 1;
    _offsetList = <int?>[1];

    _scrollListener = () {
      if (!mounted || !widget.scrollController.hasClients) return;
      final ScrollPosition position = widget.scrollController.position;
      if (position.pixels >= position.maxScrollExtent &&
          widget.totalSize != null &&
          !_isLoading &&
          widget.enabledPagination) {
        _paginate();
      }
    };
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<void> _paginate() async {
    final int pageSize = (widget.totalSize! / widget.itemsPerPage).ceil();
    if (_offset! < pageSize && !_offsetList.contains(_offset! + 1)) {
      setState(() {
        _offset = _offset! + 1;
        _offsetList.add(_offset);
        _isLoading = true;
      });
      await widget.onPaginate(_offset);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } else if (_isLoading) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offset != null) {
      _offset = widget.offset;
      _offsetList = <int?>[
        for (int index = 1; index <= widget.offset!; index++) index,
      ];
    }

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverPadding(
          padding: widget.padding,
          sliver: SliverList.builder(
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomReserve),
            child: Center(
              child: Padding(
                padding:
                    _isLoading
                        ? const EdgeInsets.all(Dimensions.paddingSizeSmall)
                        : EdgeInsets.zero,
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const SizedBox(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
