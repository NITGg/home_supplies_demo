import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/secure_storage_service.dart';

part 'locale_state.dart';

class LocaleCubit extends Cubit<LocaleState> {
  final SecureStorageService _storage;

  LocaleCubit(this._storage)
      : super(LocaleState(const Locale('ar'))) {
    _loadSavedLocale();
  }

  /// Load saved locale
  Future<void> _loadSavedLocale() async {
    final savedLocale = await _storage.getLocale();

    if (savedLocale != null) {
      emit(LocaleState(Locale(savedLocale)));
    }
  }

  /// Toggle and save
  Future<void> toggleLocale() async {
    final newLocale =
    state.locale.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');

    await _storage.saveLocale(newLocale.languageCode);

    emit(LocaleState(newLocale));
  }

  /// Set and save
  Future<void> setLocale(Locale locale) async {
    await _storage.saveLocale(locale.languageCode);

    emit(LocaleState(locale));
  }
}
