import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_courier/core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/secure_storage_service.dart';
import '../data/models/delivery_areas_models.dart';
import '../data/delivery_areas_service.dart';

abstract class DeliveryAreasState {
  const DeliveryAreasState();
}

class DeliveryAreasInitial extends DeliveryAreasState {}

class DeliveryAreasLoading extends DeliveryAreasState {}

class GovernoratesLoaded extends DeliveryAreasState {
  final List<Governorate> governorates;
  final Map<String, SelectedAreaWithDetails> tempSelectedAreas;
  final List<SelectedArea> currentlySelectedAreas;

  const GovernoratesLoaded({
    required this.governorates,
    this.tempSelectedAreas = const {},
    this.currentlySelectedAreas = const [],
  });

  GovernoratesLoaded copyWith({
    List<Governorate>? governorates,
    Map<String, SelectedAreaWithDetails>? tempSelectedAreas,
    List<SelectedArea>? currentlySelectedAreas,
  }) {
    return GovernoratesLoaded(
      governorates: governorates ?? this.governorates,
      tempSelectedAreas: tempSelectedAreas ?? this.tempSelectedAreas,
      currentlySelectedAreas:
          currentlySelectedAreas ?? this.currentlySelectedAreas,
    );
  }
}

class AreasLoaded extends DeliveryAreasState {
  final Governorate governorate;
  final List<Area> areas;
  final Map<String, SelectedAreaWithDetails> tempSelectedAreas;

  const AreasLoaded({
    required this.governorate,
    required this.areas,
    required this.tempSelectedAreas,
  });

  AreasLoaded copyWith({
    Governorate? governorate,
    List<Area>? areas,
    Map<String, SelectedAreaWithDetails>? tempSelectedAreas,
  }) {
    return AreasLoaded(
      governorate: governorate ?? this.governorate,
      areas: areas ?? this.areas,
      tempSelectedAreas: tempSelectedAreas ?? this.tempSelectedAreas,
    );
  }
}

class SelectedAreasLoaded extends DeliveryAreasState {
  final List<SelectedArea> selectedAreas;

  const SelectedAreasLoaded(this.selectedAreas);
}

class DeliveryAreasSaving extends DeliveryAreasState {}

class DeliveryAreasSaved extends DeliveryAreasState {
  final List<SelectedArea> savedAreas;

  const DeliveryAreasSaved(this.savedAreas);
}

class DeliveryAreasError extends DeliveryAreasState {
  final String message;

  const DeliveryAreasError(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cubit
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryAreasCubit extends Cubit<DeliveryAreasState> {
  final DeliveryAreasService _service;

  static int get maxAreaSelections =>
      AppSettings.courier_max_selected_areas ?? 2;

  final Map<String, Area> _cachedAreas = {};
  List<Governorate> _governorates = [];
  Map<String, SelectedAreaWithDetails> _tempSelectedAreas = {};

  DeliveryAreasCubit(this._service) : super(DeliveryAreasInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed.
  @override
  void emit(DeliveryAreasState state) {
    if (!isClosed) super.emit(state);
  }

  Future<void> loadGovernorates() async {
    if (!isClosed) emit(DeliveryAreasLoading());
    try {
      final governorates = await _service.getGovernorates();
      final currentlySelected = await _service.getSelectedAreas();

      final Map<String, SelectedAreaWithDetails> tempSelectedAreas = {};
      for (var selected in currentlySelected) {
        final key = '${selected.area.governorateId}_${selected.areaId}';
        tempSelectedAreas[key] = SelectedAreaWithDetails(
          governorateId: selected.area.governorateId,
          areaId: selected.areaId,
          name: selected.area.name,
          nameAr: selected.area.nameAr,
        );
      }

      if (!isClosed) {
        _governorates = governorates;
        _tempSelectedAreas = tempSelectedAreas;
        emit(
          GovernoratesLoaded(
            governorates: governorates,
            tempSelectedAreas: tempSelectedAreas,
            currentlySelectedAreas: currentlySelected,
          ),
        );
      }
    } catch (e) {
      dLog('Error loading governorates: $e');
      emit(DeliveryAreasError(extractErrorMessage(e)));
    }
  }

  void backToGovernorates() {
    emit(
      GovernoratesLoaded(
        governorates: _governorates,
        tempSelectedAreas: _tempSelectedAreas,
      ),
    );
  }

  Future<void> loadAreasByGovernorate(int governorateId) async {
    final currentState = state;
    Map<String, SelectedAreaWithDetails> tempSelectedAreas = {};

    if (currentState is GovernoratesLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    } else if (currentState is AreasLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    }

    if (!isClosed) emit(DeliveryAreasLoading());
    try {
      final result = await _service.getAreasByGovernorate(governorateId);
      final areas = result['areas'] as List<Area>;

      for (var area in areas) {
        _cachedAreas['${governorateId}_${area.id}'] = area;
      }

      // Remove previously selected areas that no longer exist in the API response
      final availableAreaIds = areas.map((a) => a.id).toSet();
      final validatedSelection = Map<String, SelectedAreaWithDetails>.from(
        tempSelectedAreas,
      )..removeWhere(
            (key, value) =>
        value.governorateId == governorateId &&
            !availableAreaIds.contains(value.areaId),
      );

      // Sync internal cache if anything was pruned
      if (validatedSelection.length != tempSelectedAreas.length) {
        _tempSelectedAreas = validatedSelection;
      }

      if (!isClosed) {
        emit(
          AreasLoaded(
            governorate: result['governorate'] as Governorate,
            areas: areas,
            tempSelectedAreas: validatedSelection,
          ),
        );
      }
    } catch (e) {
      dLog('Error loading areas: $e');
      if (!isClosed) emit(DeliveryAreasError(extractErrorMessage(e)));
    }
  }

  Future<void> loadSelectedAreas() async {
    if (!isClosed) emit(DeliveryAreasLoading());
    try {
      final selectedAreas = await _service.getSelectedAreas();
      if (selectedAreas.isNotEmpty) {
        await SecureStorageService().setDeliveryAreasShown();
      }
      if (!isClosed) emit(SelectedAreasLoaded(selectedAreas));
    } catch (e) {
      dLog('Error loading selected areas: $e');
      if (!isClosed) emit(DeliveryAreasError(extractErrorMessage(e)));
    }
  }

  void toggleAreaSelection(int governorateId, int areaId) {
    final currentState = state;
    if (currentState is! AreasLoaded) return;

    final key = '${governorateId}_$areaId';
    final updatedSelection = Map<String, SelectedAreaWithDetails>.from(
      currentState.tempSelectedAreas,
    );

    if (updatedSelection.containsKey(key)) {
      // Always allow deselection regardless of limit
      updatedSelection.remove(key);
    } else {
      // Block adding if AT OR ABOVE limit — covers old accounts already over limit
      if (updatedSelection.length >= maxAreaSelections) return;

      // Only clear a different governorate's selections if we're within the limit
      final existingGovId = updatedSelection.values.isNotEmpty
          ? updatedSelection.values.first.governorateId
          : null;
      if (existingGovId != null && existingGovId != governorateId) {
        updatedSelection.clear();
      }

      final area = currentState.areas.firstWhere(
            (a) => a.id == areaId,
        orElse: () => _cachedAreas[key]!,
      );

      updatedSelection[key] = SelectedAreaWithDetails(
        governorateId: governorateId,
        areaId: areaId,
        name: area.name,
        nameAr: area.nameAr,
      );
    }

    _tempSelectedAreas = updatedSelection;
    emit(currentState.copyWith(tempSelectedAreas: updatedSelection));
  }

  Future<void> saveSelectedAreas() async {
    final currentState = state;

    Map<String, SelectedAreaWithDetails> tempSelectedAreas = {};
    if (currentState is AreasLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    } else if (currentState is GovernoratesLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    }

    if (!isClosed) emit(DeliveryAreasSaving());
    try {
      final selectedAreasList = tempSelectedAreas.values
          .map((e) => e.toRequest())
          .toList();

      final savedAreas = await _service.updateSelectedAreas(selectedAreasList);

      if (!isClosed) emit(DeliveryAreasSaved(savedAreas));
    } catch (e) {
      dLog('Error saving selected areas: $e');
      if (!isClosed) emit(DeliveryAreasError(extractErrorMessage(e)));
    }
  }
}
