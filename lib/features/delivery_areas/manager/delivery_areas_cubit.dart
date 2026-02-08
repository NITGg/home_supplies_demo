import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/delivery_areas_models.dart';
import '../data/delivery_areas_service.dart';
import 'dart:developer';

// States
abstract class DeliveryAreasState {
  const DeliveryAreasState();
}

class DeliveryAreasInitial extends DeliveryAreasState {}

class DeliveryAreasLoading extends DeliveryAreasState {}

class GovernoratesLoaded extends DeliveryAreasState {
  final List<Governorate> governorates;
  final Map<String, AreaSelectionRequest> tempSelectedAreas;
  final List<SelectedArea> currentlySelectedAreas;

  const GovernoratesLoaded({
    required this.governorates,
    this.tempSelectedAreas = const {},
    this.currentlySelectedAreas = const [],
  });

  GovernoratesLoaded copyWith({
    List<Governorate>? governorates,
    Map<String, AreaSelectionRequest>? tempSelectedAreas,
    List<SelectedArea>? currentlySelectedAreas,
  }) {
    return GovernoratesLoaded(
      governorates: governorates ?? this.governorates,
      tempSelectedAreas: tempSelectedAreas ?? this.tempSelectedAreas,
      currentlySelectedAreas: currentlySelectedAreas ?? this.currentlySelectedAreas,
    );
  }
}

class AreasLoaded extends DeliveryAreasState {
  final Governorate governorate;
  final List<Area> areas;
  final Map<String, AreaSelectionRequest> tempSelectedAreas;

  const AreasLoaded({
    required this.governorate,
    required this.areas,
    required this.tempSelectedAreas,
  });

  AreasLoaded copyWith({
    Governorate? governorate,
    List<Area>? areas,
    Map<String, AreaSelectionRequest>? tempSelectedAreas,
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

// Cubit
class DeliveryAreasCubit extends Cubit<DeliveryAreasState> {
  final DeliveryAreasService _service;

  DeliveryAreasCubit(this._service) : super(DeliveryAreasInitial());

  Future<void> loadGovernorates() async {
    emit(DeliveryAreasLoading());
    try {
      final governorates = await _service.getGovernorates();
      final currentlySelected = await _service.getSelectedAreas();

      // Initialize tempSelectedAreas with currently selected areas
      final Map<String, AreaSelectionRequest> tempSelectedAreas = {};
      for (var selected in currentlySelected) {
        final key = '${selected.area.governorateId}_${selected.areaId}';
        tempSelectedAreas[key] = AreaSelectionRequest(
          governorateId: selected.area.governorateId,
          areaId: selected.areaId,
        );
      }

      emit(GovernoratesLoaded(
        governorates: governorates,
        tempSelectedAreas: tempSelectedAreas,
        currentlySelectedAreas: currentlySelected,
      ));
    } catch (e) {
      log('Error loading governorates: $e');
      emit(DeliveryAreasError('Failed to load governorates: ${e.toString()}'));
    }
  }

  Future<void> loadAreasByGovernorate(int governorateId) async {
    final currentState = state;
    Map<String, AreaSelectionRequest> tempSelectedAreas = {};

    if (currentState is GovernoratesLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    } else if (currentState is AreasLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    }

    // Clear selections that don't belong to this governorate (single governorate selection)
    tempSelectedAreas.removeWhere((key, value) =>
    value.governorateId != governorateId
    );

    emit(DeliveryAreasLoading());
    try {
      final result = await _service.getAreasByGovernorate(governorateId);

      emit(AreasLoaded(
        governorate: result['governorate'] as Governorate,
        areas: result['areas'] as List<Area>,
        tempSelectedAreas: tempSelectedAreas,
      ));
    } catch (e) {
      log('Error loading areas: $e');
      emit(DeliveryAreasError('Failed to load areas: ${e.toString()}'));
    }
  }

  Future<void> loadSelectedAreas() async {
    emit(DeliveryAreasLoading());
    try {
      final selectedAreas = await _service.getSelectedAreas();
      emit(SelectedAreasLoaded(selectedAreas));
    } catch (e) {
      log('Error loading selected areas: $e');
      emit(DeliveryAreasError('Failed to load selected areas: ${e.toString()}'));
    }
  }

  void toggleAreaSelection(int governorateId, int areaId) {
    final currentState = state;

    if (currentState is AreasLoaded) {
      final key = '${governorateId}_$areaId';
      final updatedSelection = Map<String, AreaSelectionRequest>.from(
        currentState.tempSelectedAreas,
      );

      if (updatedSelection.containsKey(key)) {
        updatedSelection.remove(key);
      } else {
        updatedSelection[key] = AreaSelectionRequest(
          governorateId: governorateId,
          areaId: areaId,
        );
      }

      emit(currentState.copyWith(tempSelectedAreas: updatedSelection));
    }
  }

  Future<void> saveSelectedAreas() async {
    final currentState = state;

    Map<String, AreaSelectionRequest> tempSelectedAreas = {};

    if (currentState is AreasLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    } else if (currentState is GovernoratesLoaded) {
      tempSelectedAreas = currentState.tempSelectedAreas;
    }

    emit(DeliveryAreasSaving());
    try {
      final selectedAreasList = tempSelectedAreas.values.toList();
      final savedAreas = await _service.updateSelectedAreas(selectedAreasList);
      emit(DeliveryAreasSaved(savedAreas));
    } catch (e) {
      log('Error saving selected areas: $e');
      emit(DeliveryAreasError('Failed to save selected areas: ${e.toString()}'));
    }
  }
}