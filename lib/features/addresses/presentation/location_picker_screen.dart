import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_location_picker/map_location_picker.dart';
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
  String? _selectedAddress;
  double? _selectedLat;
  double? _selectedLng;
  bool _barVisible = false;

  bool get _hasSelection => _selectedLat != null && _selectedLng != null;

  void _hideBar() => setState(() => _barVisible = false);

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
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ── Tap-outside dismissal layer ──────────────────────────────────
          // Only active when the bar is visible; transparent so the map
          // stays fully interactive when the bar is hidden.
          if (_barVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideBar,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

          // ── Map picker ───────────────────────────────────────────────────
          MapLocationPicker(
            config: MapLocationPickerConfig(
              apiKey: AppConstants.googleMapsApiKey,
              initialPosition: LatLng(initialLat, initialLong),
              initialZoom: 15.0,
              language: l10n.localeName,

              onNext: (GeocodingResult? result) {
                if (result != null) {
                  setState(() {
                    _selectedLat = result.geometry?.location.lat;
                    _selectedLng = result.geometry?.location.lng;
                    _selectedAddress = result.formattedAddress;
                    _barVisible = true; // reveal bar on every new pin
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
            ),

            geoCodingConfig: GeoCodingConfig(
              apiKey: AppConstants.googleMapsApiKey,
              language: l10n.localeName,
            ),
          ),

          // ── Animated confirm bar ─────────────────────────────────────────
          // Slides up from off-screen when a location is picked,
          // slides back down when tapping outside.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _barVisible ? 0 : -300,
            child: GestureDetector(
              // Absorb taps so they don't reach the dismiss layer above
              onTap: () {},
              child: _ConfirmAddressBar(
                address: _selectedAddress,
                onConfirm: _hasSelection
                    ? () => Navigator.pop(context, {
                  'latitude': _selectedLat.toString(),
                  'longitude': _selectedLng.toString(),
                  'address': _selectedAddress ?? '',
                })
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar — address preview + confirm button
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmAddressBar extends StatelessWidget {
  final String? address;
  final VoidCallback? onConfirm;

  const _ConfirmAddressBar({
    this.address,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Address preview
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.kSecondaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on,
                  color: AppColors.kSecondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  address != null && address!.isNotEmpty
                      ? address!
                      : l10n.pickOnMaps,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                l10n.confirm,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}