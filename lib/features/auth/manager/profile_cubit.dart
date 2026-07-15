import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/auth/manager/profile_states.dart';

import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../data/models/user_profile_model.dart';
import '../data/models/vehicles_model.dart';
import '../data/repositories/profile_repository.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _repository;
  UserProfileModel? _currentProfile;
  List<VehicleModel> _availableVehicles = [];

  ProfileCubit(this._repository) : super(ProfileInitial());

  /// Prevents "emit after close" errors from async work that completes
  /// after the cubit has been closed (e.g. widget disposed mid-request).
  @override
  void emit(ProfileState state) {
    if (!isClosed) super.emit(state);
  }

  UserProfileModel? get currentProfile => _currentProfile;
  List<VehicleModel> get availableVehicles => _availableVehicles;

  String? get currentVehiclePricePerKm =>
      _currentProfile?.courier.vehicleType?.pricePerKm;

  int? get currentVehicleId => _currentProfile?.courier.vehicleType?.id;

  double? get currentVehiclePricePerKmValue {
    final raw = currentVehiclePricePerKm;
    if (raw == null) return null;
    return double.tryParse(raw);
  }

  String? get currentVehicleMinDeliveryFee =>
      _currentProfile?.courier.vehicleType?.minDeliveryFee;
  double? get currentVehicleMinDeliveryFeeValue {
    final raw = currentVehicleMinDeliveryFee;
    if (raw == null) return null;
    return double.tryParse(raw);
  }

  String? get currentVehicleWalletLimit =>
      _currentProfile?.courier.vehicleType?.totalFines;
  double? get currentVehicleWalletLimitValue {
    final raw = currentVehicleWalletLimit;
    if (raw == null) return null;
    return double.tryParse(raw);
  }

  String? get currentVehicleDeliveryFeeRatio =>
      _currentProfile?.courier.vehicleType?.deliveryFeeRatio;
  double? get currentVehicleDeliveryFeeRatioValue {
    final raw = currentVehicleDeliveryFeeRatio;
    if (raw == null) return null;
    return double.tryParse(raw);
  }

  // ── FETCH PROFILE ──────────────────────────────────────────────────────────

  Future<void> fetchProfile() async {
    emit(ProfileLoading());
    try {
      final result = await _repository.getProfile();
      final profile = result.data.user;
      _currentProfile = profile;
      await LocaleManager.syncFromProfile(profile.lang);
      if (!isClosed) emit(ProfileLoaded(profile: profile));
    } on DioException catch (e) {
      dLog('ProfileCubit fetchProfile DioException: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit fetchProfile error: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  // ── FETCH AVAILABLE VEHICLES ───────────────────────────────────────────────

  Future<void> fetchAvailableVehicles() async {
    try {
      final result = await _repository.fetchAvailableVehicles();
      _availableVehicles = result.vehicles;
      if (!isClosed) emit(VehiclesLoaded(vehicles: result.vehicles));
    } on DioException catch (e) {
      dLog('ProfileCubit fetchAvailableVehicles DioException: $e');
      if (!isClosed) emit(VehiclesFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit fetchAvailableVehicles error: $e');
      if (!isClosed) emit(VehiclesFailure(extractErrorMessage(e)));
    }
  }

  // ── UPDATE PROFILE ─────────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? fullName,
    String? gender,
    String? vehicleId,
    String? vehiclePlate,
    String? extraPhones,
  }) async {
    emit(ProfileLoading());
    try {
      final result = await _repository.updateProfile(
        fullName: fullName,
        gender: gender,
        vehicleId: vehicleId,
        vehiclePlate: vehiclePlate,
        extraPhones: extraPhones,
      );
      await fetchProfile();
      if (!isClosed) emit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      dLog('ProfileCubit updateProfile DioException: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit updateProfile error: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  // ── UPDATE DOCUMENTS ───────────────────────────────────────────────────────
  //
  // Each document is now sent as separate front + back files, matching the
  // API fields:  national_id_photo_front / national_id_photo_back
  //              vehicle_license_front   / vehicle_license_back
  //              courier_license_front   / courier_license_back

  Future<void> updateDocuments({
    File? personalPhoto,
    // National ID
    File? nationalIdPhotoFront,
    File? nationalIdPhotoBack,
    // Vehicle license
    File? vehicleLicenseFront,
    File? vehicleLicenseBack,
    // Courier license
    File? courierLicenseFront,
    File? courierLicenseBack,
    // Criminal record
    File? criminalRecord,
  }) async {
    emit(ProfileLoading());
    try {
      final result = await _repository.updateDocuments(
        personalPhoto: personalPhoto,
        nationalIdPhotoFront: nationalIdPhotoFront,
        nationalIdPhotoBack: nationalIdPhotoBack,
        vehicleLicenseFront: vehicleLicenseFront,
        vehicleLicenseBack: vehicleLicenseBack,
        courierLicenseFront: courierLicenseFront,
        courierLicenseBack: courierLicenseBack,
        criminalRecord: criminalRecord,
      );
      await fetchProfile();
      if (!isClosed) emit(ProfileUpdateSuccess(message: result.message));
    } on DioException catch (e) {
      dLog('ProfileCubit updateDocuments DioException: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e, stackTrace) {
      dLog('ProfileCubit updateDocuments error: $e\n$stackTrace');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  // ── CHANGE PHONE ───────────────────────────────────────────────────────────

  Future<void> requestChangePhone({required String newPhone}) async {
    emit(ProfileLoading());
    try {
      final oldPhone = _currentProfile?.phone;
      await _repository.requestChangePhone(newPhone: newPhone, currentPhone: oldPhone);
      if (!isClosed) {
        emit(ProfileChangePhoneOtpSent(newPhone: newPhone, oldPhone: oldPhone));
      }
    } on DioException catch (e) {
      dLog('ProfileCubit requestChangePhone DioException: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit requestChangePhone error: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  Future<void> verifyChangePhone({
    required String newPhone,
    required String newOtp,
    String? oldPhone,
    String? oldOtp,
  }) async {
    emit(ProfileLoading());
    try {
      final result = await _repository.verifyChangePhone(
        newPhone: newPhone,
        newOtp: newOtp,
        oldPhone: oldPhone,
        oldOtp: oldOtp,
      );
      await fetchProfile();
      if (!isClosed) emit(ProfileChangePhoneSuccess(message: result.message));
    } on DioException catch (e) {
      dLog('ProfileCubit verifyChangePhone DioException: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit verifyChangePhone error: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  Future<void> resendChangePhoneOtp({
    required String newPhone,
    String? oldPhone,
  }) async {
    try {
      final result = await _repository.resendChangePhoneOtp(
        newPhone: newPhone,
        oldPhone: oldPhone,
      );
      if (!isClosed) emit(ProfileChangePhoneOtpResent(message: result.message));
    } on DioException catch (e) {
      dLog('ProfileCubit resendChangePhoneOtp DioException: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    } catch (e) {
      dLog('ProfileCubit resendChangePhoneOtp error: $e');
      if (!isClosed) emit(ProfileFailure(extractErrorMessage(e)));
    }
  }

  void reset() => emit(ProfileInitial());
}