import '../data/models/ad_model.dart';

abstract class AdsState {}

class AdsInitial extends AdsState {}

class AdsLoading extends AdsState {}

class AdsSuccess extends AdsState {
  final List<AdModel> homeAds;
  final List<AdModel> popupAds;

  AdsSuccess({required this.homeAds, required this.popupAds});
}

class AdsFailure extends AdsState {
  final String error;

  AdsFailure(this.error);
}
