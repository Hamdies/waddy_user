import 'package:flutter/material.dart';
import 'package:waddy_app/util/dimensions.dart';

class PaginatedListView extends StatefulWidget {
  final ScrollController scrollController;
  final Function(int? offset) onPaginate;
  final int? totalSize;
  final int? offset;
  final Widget itemView;
  final bool enabledPagination;
  final bool reverse;
  final int itemsPerPage;
  const PaginatedListView({
    super.key,
    required this.scrollController,
    required this.onPaginate,
    required this.totalSize,
    required this.offset,
    required this.itemView,
    this.enabledPagination = true,
    this.reverse = false,
    this.itemsPerPage = 10,
  });

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  int? _offset;
  late List<int?> _offsetList;
  bool _isLoading = false;

  /// Held so it can be removed in dispose.
  ///
  /// The listener used to be an anonymous closure, which made it impossible
  /// to detach — and the controller here is almost always owned by an
  /// ancestor (the home screen's `_scrollController`) that outlives this
  /// widget. Every module switch or remount added another live closure to a
  /// controller that never went away, and each one ran on every scroll frame
  /// holding a dead State alive.
  late final VoidCallback _scrollListener;

  @override
  void initState() {
    super.initState();

    _offset = 1;
    _offsetList = [1];

    _scrollListener = () {
      if (!mounted || !widget.scrollController.hasClients) return;
      if (widget.scrollController.position.pixels ==
              widget.scrollController.position.maxScrollExtent &&
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

  void _paginate() async {
    int pageSize = (widget.totalSize! / widget.itemsPerPage).ceil();
    if (_offset! < pageSize && !_offsetList.contains(_offset! + 1)) {
      setState(() {
        _offset = _offset! + 1;
        _offsetList.add(_offset);
        _isLoading = true;
      });
      await widget.onPaginate(_offset);
      setState(() {
        _isLoading = false;
      });
    } else {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offset != null) {
      _offset = widget.offset;
      _offsetList = [];
      for (int index = 1; index <= widget.offset!; index++) {
        _offsetList.add(index);
      }
    }

    return Column(
      children: [
        widget.reverse ? const SizedBox() : widget.itemView,

        Center(
          child: Padding(
            padding:
                (_isLoading)
                    ? const EdgeInsets.all(Dimensions.paddingSizeSmall)
                    : EdgeInsets.zero,
            child:
                _isLoading
                    ? const CircularProgressIndicator()
                    : const SizedBox(),
          ),
        ),

        widget.reverse ? widget.itemView : const SizedBox(),
      ],
    );
  }
}
