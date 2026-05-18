
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../../../../core/utils/api_client.dart';
import '../../../core/utils/logger.dart';
import '../data/models/ad_model.dart';
import 'ad_state.dart';

class AdsCubit extends Cubit<AdsState> {
  final Dio _dio = ApiClient.instance.dio;

  AdsCubit() : super(AdsInitial());

  Future<void> getHomeAds() async {
    if (!isClosed) {
      emit(AdsLoading());
    }
    try {
      dLog("loading ADS");
      final now = DateTime.now().toIso8601String().split('T')[0];
      final response = await _dio.get(
        '/ads',
        queryParameters: {'limit': 3, 'ad_type': 'BANNER', 'sort': 'priority'},
      );
      dLog('ads response : $response');

      final data = AdsResponse.fromJson(response.data);

      final response2 = await _dio.get(
        '/ads',
        queryParameters: {'ad_type': 'POPUP'},
      );
      final data2 = AdsResponse.fromJson(response2.data);
      final response3 = await _dio.get(
        '/ads',
        queryParameters: {'ad_type': 'SPLASH', 'sort': 'priority'},
      );
      final data3 = AdsResponse.fromJson(response3.data);
      if (!isClosed) {
        emit(
          AdsSuccess(
            homeAds: data.ads,
            popupAds: data2.ads,
            feedAds: data3.ads,
          ),
        );
      }
      dLog('ads popups : ${response2.toString()}');
    } catch (e) {
      dLog('ads error : $e');
      if (!isClosed) {
        emit(AdsFailure(e.toString()));
      }
    }
  }
}
