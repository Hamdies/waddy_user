import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/location/domain/models/prediction_model.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class CairoLocationSearchWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final String? pickedAddress;

  const CairoLocationSearchWidget({
    super.key,
    required this.mapController,
    required this.pickedAddress,
  });

  @override
  State<CairoLocationSearchWidget> createState() =>
      _CairoLocationSearchWidgetState();
}

class _CairoLocationSearchWidgetState extends State<CairoLocationSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PredictionModel> _predictions = [];
  bool _isSearching = false;
  bool _showResults = false;

  /// Places Autocomplete is billed per request and `onChanged` fires on every
  /// keystroke, so an un-debounced field spent a request per character AND
  /// raced its own responses — a slow reply for "Ma" could land after "Maadi"
  /// and repopulate the list with staler predictions.
  Timer? _debounce;

  /// Fences the in-flight request against its own reply, the same way
  /// `LocationController._positionRequestId` does for position lookups. Only
  /// the newest query is allowed to write to `_predictions`.
  int _searchRequestId = 0;

  static const Duration _debounceDelay = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      // Invalidate any in-flight reply so a late response cannot repopulate
      // a list the user has just cleared.
      _searchRequestId++;
      setState(() {
        _predictions = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    // Show the spinner immediately so the field acknowledges the keystroke,
    // even though the request itself waits for the debounce window.
    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    _debounce = Timer(_debounceDelay, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final int requestId = ++_searchRequestId;

    // Bias toward Egypt rather than pinning to Cairo. The old query appended
    // ', Cairo, Egypt' to every search, so a user in Alexandria, Giza or
    // Mansoura searching their own street got Cairo-biased results for an
    // address that was never in Cairo. Location bias below (lat/lng of the
    // current pin) already does the "near me" work properly.
    final scopedQuery = '$query, Egypt';

    // Get current position for location bias (priority to near locations)
    final locationController = Get.find<LocationController>();
    final currentPosition = locationController.position;

    final predictions = await locationController.searchLocation(
      context,
      scopedQuery,
      latitude: currentPosition.latitude != 0 ? currentPosition.latitude : null,
      longitude:
          currentPosition.longitude != 0 ? currentPosition.longitude : null,
    );

    // A reply from a superseded query must not overwrite newer predictions.
    if (mounted && requestId == _searchRequestId) {
      setState(() {
        _predictions = predictions;
        _isSearching = false;
      });
    }
  }

  void _onSuggestionSelected(PredictionModel suggestion) {
    Get.find<LocationController>().setLocation(
      suggestion.placeId,
      suggestion.description,
      widget.mapController,
    );
    _searchController.clear();
    _focusNode.unfocus();
    setState(() {
      _predictions = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      // The field and its dropdown fill whatever width the parent gives them.
      // The default (center) shrink-wraps to content, which since this widget
      // moved into an Expanded beside the back button would have sized the
      // field to its hint text instead of the row.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search input field
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.streetAddress,
            onChanged: _onSearchChanged,
            onTap: () {
              if (_searchController.text.isNotEmpty) {
                setState(() => _showResults = true);
              }
            },
            decoration: InputDecoration(
              // `.tr` returns the key itself when a translation is missing, so
              // it is never empty and the old English fallback was unreachable.
              hintText: 'search_location'.tr,
              // inkLight (4.59:1), not grey.shade400 — that was #BDBDBD on
              // white, i.e. 1.88:1, which fails AA for text and the 3:1 floor
              // for non-text UI. Placeholder text is the label for an empty
              // field; if it cannot be read, the field has no label.
              hintStyle: waddyRegular.copyWith(color: WaddyColors.inkLight),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Theme.of(context).primaryColor,
                size: 22,
                semanticLabel: 'search_location'.tr,
              ),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        // Names the control for screen readers; an icon-only
                        // button announced as just "button" is unusable.
                        tooltip: 'clear'.tr,
                        onPressed: () {
                          _debounce?.cancel();
                          _searchRequestId++;
                          _searchController.clear();
                          setState(() {
                            _predictions = [];
                            _showResults = false;
                            _isSearching = false;
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: WaddyColors.inkLight,
                          size: 20,
                        ),
                      )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeDefault,
              ),
            ),
            style: waddyMedium.copyWith(color: WaddyColors.ink),
          ),
        ),

        // Search results dropdown
        if (_showResults && (_predictions.isNotEmpty || _isSearching))
          Container(
            margin: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child:
                  _isSearching
                      ? const Padding(
                        padding: EdgeInsets.all(Dimensions.paddingSizeLarge),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeSmall,
                        ),
                        itemCount: _predictions.length,
                        separatorBuilder:
                            (context, index) => const Divider(
                              height: 1,
                              color: WaddyColors.divider,
                              // Aligns under the description text: 16 leading
                              // pad + 36 icon box + 12 gap = 64. The old 56
                              // was hand-computed and missed by 8pt.
                              indent: 64,
                            ),
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return Semantics(
                            button: true,
                            label: prediction.description ?? '',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onSuggestionSelected(prediction),
                                child: Container(
                                  // A single-line prediction measured ~42pt,
                                  // under the 48pt touch floor. The row is the
                                  // primary way to accept a search result, so
                                  // it cannot be the smallest target on screen.
                                  constraints: const BoxConstraints(
                                    minHeight: Dimensions.minTapTarget,
                                  ),
                                  alignment: AlignmentDirectional.centerStart,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Dimensions.paddingSizeDefault,
                                    vertical: Dimensions.paddingSizeSmall,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          color: Theme.of(context).primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeMedium,
                                      ),
                                      Expanded(
                                        child: Text(
                                          prediction.description ?? '',
                                          style: waddyMedium.copyWith(
                                            color: WaddyColors.ink,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
      ],
    );
  }
}
