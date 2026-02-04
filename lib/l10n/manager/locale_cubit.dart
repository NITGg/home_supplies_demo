import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'locale_state.dart';

class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit() : super(LocaleState(const Locale('ar')));

  void toggleLocale() {
    final newLocale = state.locale.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    emit(LocaleState(newLocale));
  }

  void setLocale(Locale locale) {
    emit(LocaleState(locale));
  }
}
