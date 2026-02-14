import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_location_picker/map_location_picker.dart';
import 'package:tawreedat_go/core/widgets/custom_button.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/utils/constants.dart';
import '../../../l10n/app_localizations.dart';

/// Standalone map screen for selecting a location with search and visual picking
class MapLocationPickerScreen extends StatefulWidget {
  final String? initialLat;
  final String? initialLong;
  final String? initialAddress;

  const MapLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLong,
    this.initialAddress,
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final initialLat = widget.initialLat != null
        ? double.tryParse(widget.initialLat!) ?? 30.0444
        : 30.0444;
    final initialLong = widget.initialLong != null
        ? double.tryParse(widget.initialLong!) ?? 31.2357
        : 31.2357;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickOnMaps),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: MapLocationPicker(
        config: MapLocationPickerConfig(
          apiKey: AppConstants.googleMapsApiKey,
          initialPosition: LatLng(initialLat, initialLong),
          initialZoom: 15.0,
          language: l10n.localeName,
          searchBarBuilder: (context, searchBar) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, left: 12, right: 12),
              child: SizedBox(
                width: double.infinity, // Full width
                height: 56, // Taller height (default is ~40)
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

          bottomCardBuilder:
              (
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Address text
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
                              style: TextStyle(
                                fontSize: 16,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Your custom confirm button
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
              // Immediately return the selected location
              Navigator.pop(context, {
                'latitude': result.geometry?.location.lat.toString() ?? '',
                'longitude': result.geometry?.location.lng.toString() ?? '',
                'address': result.formattedAddress ?? '',
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
