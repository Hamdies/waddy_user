import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/domain/models/prediction_model.dart';

class CairoLocationSearchWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final String? pickedAddress;

  const CairoLocationSearchWidget({
    super.key,
    required this.mapController,
    required this.pickedAddress,
  });

  @override
  State<CairoLocationSearchWidget> createState() => _CairoLocationSearchWidgetState();
}

class _CairoLocationSearchWidgetState extends State<CairoLocationSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PredictionModel> _predictions = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    // Append "Cairo, Egypt" to restrict search to Cairo
    final cairoQuery = '$query, Cairo, Egypt';
    
    // Get current position for location bias (priority to near locations)
    final locationController = Get.find<LocationController>();
    final currentPosition = locationController.position;
    
    final predictions = await locationController.searchLocation(
      context,
      cairoQuery,
      latitude: currentPosition.latitude != 0 ? currentPosition.latitude : null,
      longitude: currentPosition.longitude != 0 ? currentPosition.longitude : null,
    );

    if (mounted) {
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
      children: [
        // Search input field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
              hintText: 'search_location'.tr.isNotEmpty ? 'search_location'.tr : 'Search location...',
              hintStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Theme.of(context).primaryColor,
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _predictions = [];
                          _showResults = false;
                        });
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Search results dropdown
        if (_showResults && (_predictions.isNotEmpty || _isSearching))
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(20),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _predictions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 56,
                      ),
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _onSuggestionSelected(prediction),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.location_on_outlined,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      prediction.description ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                        fontWeight: FontWeight.w500,
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
                        );
                      },
                    ),
            ),
          ),
      ],
    );
  }
}
