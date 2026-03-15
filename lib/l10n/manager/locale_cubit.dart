import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/manager/auth_cubit.dart';

import '../../core/utils/secure_storage_service.dart';
import '../../features/auth/data/repositories/profile_repository.dart';

part 'locale_state.dart';

class LocaleCubit extends Cubit<LocaleState> {
  final SecureStorageService _storage;
  ProfileRepository? profileRepository;

  LocaleCubit(this._storage) : super(LocaleState(const Locale('ar'))) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final savedLocale = await _storage.getLocale();
    if (savedLocale != null) {
      emit(LocaleState(Locale(savedLocale)));
    }
  }

  /// Called on profile fetch — updates local locale to match profile, no backend call.
  Future<void> syncFromProfile(String lang) async {
    final locale = Locale(lang.toLowerCase());
    if (state.locale == locale) return;
    await _storage.saveLocale(locale.languageCode);
    emit(LocaleState(locale));
    log('LocaleCubit: locale synced from profile → ${locale.languageCode}');
  }

  /// Called when the user manually toggles locale — persists and updates profile.
  Future<void> toggleLocale() async {
    final newLocale = state.locale.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');

    await _storage.saveLocale(newLocale.languageCode);
    emit(LocaleState(newLocale));

    try {
      await profileRepository?.updateProfile(lang: newLocale.languageCode.toUpperCase(), token: kAuthtoken);
      log('LocaleCubit: profile lang updated → ${newLocale.languageCode}');
    } catch (e) {
      log('LocaleCubit: failed to update profile lang: $e');
    }
  }
}

class LocaleManager {
  static late LocaleCubit cubit;

  static Future<void> toggleLocale() => cubit.toggleLocale();

  static Future<void> syncFromProfile(String lang) =>
      cubit.syncFromProfile(lang);

  static String get currentLocale => cubit.state.locale.languageCode;

  static bool get isArabic => cubit.state.locale.languageCode == 'ar';

  static bool get isEnglish => cubit.state.locale.languageCode == 'en';
}
