import 'dart:developer';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/utils/area_boundry_validator.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/widgets/text_form.dart';
import '../../../l10n/app_localizations.dart';

import '../data/models/address_model.dart';
import '../data/models/governorate_model.dart';
import '../manager/address_cubit.dart';
import '../manager/address_states.dart';
import '../manager/governorate_cubit.dart';
import '../manager/governorate_states.dart';
import '../util/location_auto_detector.dart';
import 'location_picker_screen.dart';

class AddressFormBottomSheet extends StatefulWidget {
  final Address? address;

  /// When true  → save to server, show name + default fields.
  /// When false → return address object only, hide name + default fields.
  final bool saveAddress;
  final bool isPickup;

  /// When true → on open, silently detect device GPS, match to an area by
  /// boundary, fill the form, and call [_submit] automatically.
  /// Falls back gracefully if permission is denied or no area is matched.
  final bool autoDetect; // ← new field

  const AddressFormBottomSheet({
    super.key,
    this.address,
    this.saveAddress = true,
    this.isPickup = false,
    this.autoDetect = false, // ← new param
  });

  @override
  State<AddressFormBottomSheet> createState() => _AddressFormBottomSheetState();
}

class _AddressFormBottomSheetState extends State<AddressFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _detailedAddressController;
  late TextEditingController _latController;
  late TextEditingController _longController;

  late final GovernorateCubit _governorateCubit;
  GovernoratesResponse? _governoratesResponse;
  String? _pickedAdministrativeArea;
  String? _pickedGovernorate;
  int? _selectedAreaId;
  bool _isDefault = false;
  bool _hasLocation = false;

  // ── true while auto-detect is running, shows a loading overlay ──────────
  bool _autoDetecting = false; // ← new flag

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.address?.name ?? 'المنزل',
    );
    _detailedAddressController = TextEditingController(
      text: widget.address?.detailedAddress,
    );
    _latController = TextEditingController(text: widget.address?.addressLat);
    _longController = TextEditingController(text: widget.address?.addressLong);
    _selectedAreaId = widget.address?.areaId;
    _isDefault = widget.address?.isDefault ?? false;
    _hasLocation =
        _latController.text.isNotEmpty && _longController.text.isNotEmpty;

    _governorateCubit = GovernorateCubit()..loadGovernorates();

    // ── Start auto-detect once governorates finish loading ─────────────────
    // IMPORTANT: we assign _governoratesResponse HERE from the emitted state,
    // not in the BlocListener. The BlocListener runs after the first frame
    // builds, but .then() fires immediately after the stream emits — so
    // _governoratesResponse would still be null if we relied on BlocListener.
    if (widget.autoDetect) {
      _governorateCubit.stream
          .firstWhere((s) => s is GovernoratesLoaded || s is GovernorateError)
          .then((state) {
            if (state is GovernoratesLoaded) {
              // Assign directly — don't wait for BlocListener to do it.
              _governoratesResponse = state.response;
            }
            if (mounted) _tryAutoDetect();
          });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailedAddressController.dispose();
    _latController.dispose();
    _longController.dispose();
    _governorateCubit.close();
    super.dispose();
  }

  // ── NEW: auto-detect ─────────────────────────────────────────────────────

  /// Silently detects device GPS, matches it to a service area by boundary,
  /// fills the form exactly as [_pickLocationFromMap] would, then calls
  /// [_submit]. All existing validations in [_submit] still run untouched.
  ///
  /// Aborts quietly when:
  ///   • GPS permission is denied  (LocationService shows its own dialogs)
  ///   • Geocoding fails
  ///   • The pin is outside every known area boundary AND has no name match
  Future<void> _tryAutoDetect() async {
    if (!mounted || _governoratesResponse == null) {
      dLog(
        'AddressFormBottomSheet: auto-detect skipped — not mounted or no governorates',
      );
      return;
    }

    setState(() => _autoDetecting = true);
    dLog('AddressFormBottomSheet: auto-detect starting');

    try {
      final l10n = AppLocalizations.of(context)!;

      final result = await LocationAutoDetector.detect(
        context: context,
        language: l10n.localeName,
      );

      if (result == null || !mounted) {
        dLog('AddressFormBottomSheet: auto-detect — no result, aborting');
        return;
      }

      final lat = double.tryParse(result['latitude']!);
      final lng = double.tryParse(result['longitude']!);

      if (lat == null || lng == null) {
        dLog(
          'AddressFormBottomSheet: auto-detect — unparseable lat/lng, aborting',
        );
        return;
      }

      final allAreas = _governoratesResponse!.governorates
          .expand((g) => g.areas)
          .toList();

      // ── Step A: boundary scan (most reliable with a real GPS coordinate) ─
      Area? matchedArea = allAreas.firstWhereOrNull(
        (area) => AreaBoundaryValidator.isPointInArea(
          lat: lat,
          lng: lng,
          boundaries: area.boundaries,
        ),
      );

      if (matchedArea != null) {
        dLog(
          'AddressFormBottomSheet: auto-detect — boundary match: id=${matchedArea.id} name=${matchedArea.name}',
        );
      }

      // ── Step B: name-match fallback (mirrors _submit Step 1 & 2) ─────────
      if (matchedArea == null) {
        final pickedAdmin = result['administrativeArea'] ?? '';
        if (pickedAdmin.isNotEmpty) {
          final pickedNorm = pickedAdmin.toLowerCase().replaceAll(' ', '');
          matchedArea = allAreas.firstWhereOrNull((a) {
            final nameAr = a.nameAr.toLowerCase().replaceAll(' ', '');
            final nameEn = a.name.toLowerCase().replaceAll(' ', '');
            return nameAr.contains(pickedNorm) ||
                pickedNorm.contains(nameAr) ||
                nameEn.contains(pickedNorm) ||
                pickedNorm.contains(nameEn);
          });
          if (matchedArea != null) {
            dLog(
              'AddressFormBottomSheet: auto-detect — name match fallback: id=${matchedArea.id}',
            );
          }
        }
      }

      if (matchedArea == null) {
        dLog(
          'AddressFormBottomSheet: auto-detect — no area match, letting user pick manually',
        );
        return; // sheet stays open, user selects area manually
      }

      if (!mounted) return;

      // ── Populate form exactly as _pickLocationFromMap does ────────────────
      setState(() {
        _selectedAreaId = matchedArea!.id;
        _latController.text = result['latitude']!;
        _longController.text = result['longitude']!;
        _pickedAdministrativeArea = result['administrativeArea'];
        _pickedGovernorate = result['governorate'];
        if (_detailedAddressController.text.isEmpty) {
          _detailedAddressController.text = result['address'] ?? '';
        }
        _hasLocation = true;
      });

      dLog(
        'AddressFormBottomSheet: auto-detect — form filled, calling _submit',
      );

      // Defer so the widget tree rebuilds with the new state first,
      // ensuring the DropdownButtonFormField reflects _selectedAreaId.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit();
      });
    } finally {
      if (mounted) setState(() => _autoDetecting = false);
    }
  }

  // ── existing ─────────────────────────────────────────────────────────────

  /// Opens the map picker. Called automatically when an area is selected.
  Future<void> _pickLocationFromMap() async {
    Map<String, dynamic>? areaBoundaries;
    if (_selectedAreaId != null && _governoratesResponse != null) {
      areaBoundaries = _governoratesResponse!
          .findAreaById(_selectedAreaId!)
          ?.boundaries;
    }

    final result = await Navigator.of(context, rootNavigator: true)
        .push<Map<String, String>>(
          MaterialPageRoute(
            builder: (_) => MapLocationPickerScreen(
              initialLat: _latController.text.isEmpty
                  ? null
                  : _latController.text,
              initialLong: _longController.text.isEmpty
                  ? null
                  : _longController.text,
              initialAddress: _detailedAddressController.text.isEmpty
                  ? null
                  : _detailedAddressController.text,
              areaBoundaries: areaBoundaries,
            ),
          ),
        );

    if (result != null && mounted) {
      setState(() {
        _latController.text = result['latitude'] ?? '';
        _longController.text = result['longitude'] ?? '';
        _pickedAdministrativeArea = result['administrativeArea'];
        _pickedGovernorate = result['governorate'];
        log(
          '📍 Location picked: ${result['administrativeArea']} - area selected : ${_governoratesResponse?.findAreaById(_selectedAreaId!)?.nameAr}',
        );

        if (_detailedAddressController.text.isEmpty &&
            result['address'] != null &&
            result['address']!.isNotEmpty) {
          _detailedAddressController.text = result['address']!;
        }

        _hasLocation =
            _latController.text.isNotEmpty && _longController.text.isNotEmpty;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedAreaId == null) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.pleaseSelectArea,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      if (_latController.text.trim().isEmpty ||
          _longController.text.trim().isEmpty) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.pleaseSelectLocation,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // ── Validation ──────────────────────────────────────────────────────
      if (_governoratesResponse != null && _selectedAreaId != null) {
        final area = _governoratesResponse!.findAreaById(_selectedAreaId!);

        dLog('🗺️ Validation start');
        dLog('   selectedAreaId : $_selectedAreaId');
        log(
          '   area found     : ${area != null ? "yes (id=${area.id}, name=${area.name})" : "NO"}',
        );

        if (area != null) {
          final lat = double.tryParse(_latController.text.trim());
          final lng = double.tryParse(_longController.text.trim());

          dLog('   pin lat    : $lat');
          dLog('   pin lng    : $lng');

          if (lat != null && lng != null) {
            // ── Step 1: Name check against selected area ──────────────────
            bool nameMatches = false;

            if (_pickedAdministrativeArea != null &&
                _pickedAdministrativeArea!.isNotEmpty) {
              final pickedNormalized = _pickedAdministrativeArea!
                  .toLowerCase()
                  .replaceAll(' ', '');
              final areaNameAr = area.nameAr.toLowerCase().replaceAll(' ', '');
              final areaNameEn = area.name.toLowerCase().replaceAll(' ', '');

              final matchesAr =
                  areaNameAr.contains(pickedNormalized) ||
                  pickedNormalized.contains(areaNameAr);
              final matchesEn =
                  areaNameEn.contains(pickedNormalized) ||
                  pickedNormalized.contains(areaNameEn);

              nameMatches = matchesAr || matchesEn;

              dLog('   Step 1 — name check:');
              log(
                '   picked     : "$_pickedAdministrativeArea" → "$pickedNormalized"',
              );
              dLog('   nameAr     : "$areaNameAr" → matches: $matchesAr');
              dLog('   nameEn     : "$areaNameEn" → matches: $matchesEn');
              dLog('   nameMatches: $nameMatches');
              dLog('   governorate: $_pickedGovernorate');
            } else {
              log(
                '   Step 1 — name check: skipped (no administrativeArea from map)',
              );
            }

            // ── Step 2: If name didn't match, search ALL areas for a match ─
            if (!nameMatches &&
                _pickedAdministrativeArea != null &&
                _pickedAdministrativeArea!.isNotEmpty) {
              log(
                '   Step 2 — searching all areas for a name match with "$_pickedAdministrativeArea"',
              );

              final pickedNormalized = _pickedAdministrativeArea!
                  .toLowerCase()
                  .replaceAll(' ', '');

              final allAreas = _governoratesResponse!.governorates
                  .expand((g) => g.areas)
                  .toList();

              final matchedArea = allAreas.firstWhereOrNull((a) {
                final nameAr = a.nameAr.toLowerCase().replaceAll(' ', '');
                final nameEn = a.name.toLowerCase().replaceAll(' ', '');
                return nameAr.contains(pickedNormalized) ||
                    pickedNormalized.contains(nameAr) ||
                    nameEn.contains(pickedNormalized) ||
                    pickedNormalized.contains(nameEn);
              });

              if (matchedArea != null) {
                log(
                  '✅ Step 2 — found matching area: id=${matchedArea.id}, name=${matchedArea.name}',
                );
                setState(() => _selectedAreaId = matchedArea.id);
                nameMatches = true;
              } else {
                log(
                  '   Step 2 — no area name match found, falling back to boundary check',
                );
              }
            }

            // ── Step 3: Boundary check (only if name still didn't match) ──
            if (!nameMatches) {
              dLog('   Step 3 — boundary check');
              dLog('   boundaries : ${area.boundaries}');

              final isInside = AreaBoundaryValidator.isPointInArea(
                lat: lat,
                lng: lng,
                boundaries: area.boundaries,
              );

              dLog('   isInside   : $isInside');

              if (!isInside) {
                dLog('🚫 Rejected — name mismatch AND outside boundaries');
                context.read<AddressCubit>().createAddressUnAvailableRequest(
                  widget.isPickup,
                  _longController.text.trim(),
                  _latController.text.trim(),
                  _detailedAddressController.text.trim(),
                  _pickedAdministrativeArea ?? area.name,
                  _pickedGovernorate ?? '',
                );
                Fluttertoast.showToast(
                  msg: AppLocalizations.of(context)!.addressOutsideArea,
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
                return;
              }

              dLog('✅ Pin is inside boundaries — accepted');
            } else {
              dLog('✅ Name matched — skipping boundary check');
            }

            dLog('✅ Validation passed — proceeding to save');
          } else {
            dLog('⚠️ Could not parse lat/lng — skipping validation');
          }
        } else {
          dLog('⚠️ Area not found — skipping validation');
          log(
            '   available ids: ${_governoratesResponse!.governorates.expand((g) => g.areas).map((a) => a.id).toList()}',
          );
        }
      } else {
        log(
          '⚠️ Validation skipped — governoratesResponse=${_governoratesResponse != null ? "loaded" : "NULL"}, selectedAreaId=$_selectedAreaId',
        );
      }

      // ── Build address object ──────────────────────────────────────────────
      final address = Address(
        id: widget.address?.id,
        areaId: _selectedAreaId!,
        name: widget.saveAddress
            ? (_nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim())
            : null,
        addressLat: _latController.text.trim(),
        addressLong: _longController.text.trim(),
        detailedAddress: _detailedAddressController.text.trim(),
        isDefault: widget.saveAddress ? _isDefault : true,
      );

      if (widget.saveAddress) {
        if (widget.address != null) {
          context.read<AddressCubit>().updateAddress(
            widget.address!.id!,
            address,
          );
        } else {
          context.read<AddressCubit>().createAddress(address);
        }
      } else {
        Navigator.pop(context, address);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName == 'ar';

    return MultiBlocListener(
      listeners: [
        BlocListener<AddressCubit, AddressState>(
          listener: (context, state) {
            if (state is AddressOperationSuccess) {
              Navigator.pop(context, state.address);
            } else if (state is AddressError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
        BlocListener<GovernorateCubit, GovernorateState>(
          bloc: _governorateCubit,
          listener: (context, state) {
            if (state is GovernoratesLoaded) {
              _governoratesResponse = state.response;
            }
          },
        ),
      ],
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Stack(
            // ← wrap in Stack for overlay
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.address != null
                                  ? l10n.edit
                                  : l10n.detailedAddress,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Form
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // ── Address Name (only when saving) ────────────────
                            if (widget.saveAddress) ...[
                              AppTextFormField(
                                controller: _nameController,
                                label: l10n.addressNameOptional,
                                hintText: l10n.addressNameHint,
                                validator: (value) {
                                  if (value != null && value.trim().isEmpty) {
                                    return l10n.required;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── Area Selection ─────────────────────────────────
                            BlocBuilder<GovernorateCubit, GovernorateState>(
                              bloc: _governorateCubit,
                              builder: (context, state) {
                                if (state is GovernorateLoading) {
                                  return const Center(
                                    child: LoadingScreen(
                                      isOne: true,
                                      asWidget: true,
                                    ),
                                  );
                                }

                                if (state is GovernorateError) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            state.message,
                                            style: TextStyle(
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _governorateCubit
                                              .loadGovernorates(),
                                          child: Text(l10n.retry),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (state is GovernoratesLoaded) {
                                  final areas = state.response.allAreas;

                                  if (areas.isEmpty) {
                                    return Text(
                                      l10n.noAreasAvailable,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    );
                                  }

                                  return DropdownButtonFormField<int>(
                                    // ── key forces the dropdown to rebuild when
                                    //    _selectedAreaId is set by auto-detect ──
                                    key: ValueKey(_selectedAreaId),
                                    initialValue: _selectedAreaId,
                                    decoration: InputDecoration(
                                      labelText: l10n.selectArea,
                                      labelStyle: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: AppColors.kPrimaryColor,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.location_city,
                                      ),
                                    ),
                                    items: areas.map((area) {
                                      final governorate = state.response
                                          .getGovernorateForArea(area.id);
                                      return DropdownMenuItem(
                                        value: area.id,
                                        child: Text(
                                          '${governorate?.getLocalizedName(isArabic) ?? ''} - ${area.getLocalizedName(isArabic)}',
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedAreaId = value;
                                        // Reset location when area changes so the
                                        // map opens centred on the new area.
                                        _latController.clear();
                                        _longController.clear();
                                        _detailedAddressController.clear();
                                        _hasLocation = false;
                                        _pickedAdministrativeArea = null;
                                        _pickedGovernorate = null;
                                      });
                                      // Auto-launch map picker after selecting area
                                      if (value != null) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                              (_) => _pickLocationFromMap(),
                                            );
                                      }
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return l10n.pleaseSelectArea;
                                      }
                                      return null;
                                    },
                                  );
                                }

                                return const SizedBox();
                              },
                            ),
                            const SizedBox(height: 16),

                            // ── Detailed Address (read-only, filled by map) ────
                            if (_detailedAddressController.text.isNotEmpty) ...[
                              AppTextFormField(
                                enabled: false,
                                controller: _detailedAddressController,
                                label: l10n.detailedAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n.required;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── Location status indicator ──────────────────────
                            if (_hasLocation)
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 600),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                        8,
                                        0,
                                        8,
                                        10,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            color: Colors.green.shade700,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green.shade700,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            l10n.locationObtained,
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // ── Hint when no location yet ──────────────────────
                            if (!_hasLocation && _selectedAreaId != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.locationRequired,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ── Re-pick button (shown only after first pick) ────
                            if (_hasLocation && _selectedAreaId != null) ...[
                              const SizedBox(height: 8),
                              AppCustomButton(
                                isSecondary: true,
                                onPressed: _pickLocationFromMap,
                                text: l10n.pickOnMaps,
                              ),
                            ],

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ── Submit Button ───────────────────────────────────────────
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: widget.saveAddress
                            ? BlocBuilder<AddressCubit, AddressState>(
                                builder: (context, state) {
                                  final isLoading = state is AddressLoading;
                                  return AppCustomButton(
                                    shake:
                                        _hasLocation && _selectedAreaId != null,
                                    onPressed: isLoading ? () {} : _submit,
                                    text: widget.address != null
                                        ? l10n.updateAddress
                                        : l10n.addAddress,
                                    isLoading: isLoading,
                                  );
                                },
                              )
                            : AppCustomButton(
                                onPressed: _submit,
                                text: l10n.useThisAddress,
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Auto-detect loading overlay ─────────────────────────────
              // Shown while GPS + geocoding are in flight.
              // Covers the sheet so the user can't tap anything mid-detect.
              if (_autoDetecting)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l10n.gettingLocation, // ← add this l10n key
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
