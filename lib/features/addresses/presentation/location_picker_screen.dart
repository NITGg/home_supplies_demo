import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_location_picker/map_location_picker.dart';
import 'package:tawreedat_go/core/widgets/custom_button.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/utils/area_boundry_validator.dart';
import '../../../core/utils/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final String? initialLat;
  final String? initialLong;
  final String? initialAddress;
  final Map<String, dynamic>? areaBoundaries;

  const MapLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLong,
    this.initialAddress,
    this.areaBoundaries,
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late final double _initialLat;
  late final double _initialLong;

  @override
  void initState() {
    super.initState();
    // Hide floating button so it doesn't intercept map gestures
    // Defer notifier update to after the current build frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingButton.value = false;
    });    if (widget.initialLat != null && widget.initialLong != null) {
      _initialLat  = double.tryParse(widget.initialLat!)  ?? 30.0444;
      _initialLong = double.tryParse(widget.initialLong!) ?? 31.2357;
    } else if (widget.areaBoundaries != null) {
      final c = AreaBoundaryValidator.centroid(widget.areaBoundaries!);
      _initialLat  = c?.lat ?? 30.0444;
      _initialLong = c?.lng ?? 31.2357;
    } else {
      _initialLat  = 30.0444;
      _initialLong = 31.2357;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickOnMaps),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: MapLocationPicker(
        config: MapLocationPickerConfig(
          apiKey: AppConstants.googleMapsApiKey,
          initialPosition: LatLng(_initialLat, _initialLong),
          initialZoom: 15.0,
          language: l10n.localeName,
          searchBarBuilder: (context, searchBar) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, left: 12, right: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: searchBar,
                ),
              ),
            );
          },
          bottomCardBuilder: (
              context,
              geoResult,
              results,
              address,
              isLoading,
              onNext,
              searchBar,
              ) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.kSecondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          address,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 16,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCustomButton(
                    onPressed: onNext,
                    text: l10n.confirm,
                  ),
                ],
              ),
            );
          },
          onNext: (GeocodingResult? result) {
            if (result != null) {
              Navigator.pop(context, {
                'latitude':  result.geometry?.location.lat.toString() ?? '',
                'longitude': result.geometry?.location.lng.toString() ?? '',
                'address':   result.formattedAddress ?? '',
              });
            }
          },
          floatingControlsColor: AppColors.kSecondaryColor,
          floatingControlsIconColor: Colors.white,
          initialMapType: MapType.normal,
          myLocationButtonEnabled: true,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
          compassEnabled: true,
          noAddressFoundText: l10n.noData,
          fabTooltip: l10n.useCurrentLocation,
        ),
        searchConfig: SearchConfig(
          apiKey: AppConstants.googleMapsApiKey,
          searchHintText: l10n.searchFor,
        ),
        geoCodingConfig: GeoCodingConfig(
          apiKey: AppConstants.googleMapsApiKey,
          language: l10n.localeName,
        ),
      ),
    );
  }
}