import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tawreedat_courier/features/notifications/data/notification_settings_model.dart';
import 'package:tawreedat_courier/features/notifications/manager/notification_settings_cubit.dart';

class MockDio extends Mock implements Dio {}

final _settings = NotificationSettings(
  newOrders: true,
  offerUpdates: false,
  badgeUpdates: true,
  pushEnabled: true,
  allowAdminNotification: false,
);

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
  });

  // ── Model tests ────────────────────────────────────────────────────────────

  group('NotificationSettings model', () {
    test('fromJson maps all fields', () {
      final s = NotificationSettings.fromJson({
        'new_orders': true,
        'offer_updates': false,
        'badge_updates': true,
        'push_enabled': true,
        'allow_admin_notification': false,
      });
      expect(s.newOrders, isTrue);
      expect(s.offerUpdates, isFalse);
      expect(s.allowAdminNotification, isFalse);
    });

    test('fromJson uses defaults when fields are absent', () {
      final s = NotificationSettings.fromJson({});
      expect(s.newOrders, isTrue);
      expect(s.pushEnabled, isTrue);
    });

    test('toJson round-trips correctly', () {
      final json = _settings.toJson();
      expect(json['new_orders'], _settings.newOrders);
      expect(json['offer_updates'], _settings.offerUpdates);
      expect(json['push_enabled'], _settings.pushEnabled);
    });

    test('copyWith overrides only specified fields', () {
      final updated = _settings.copyWith(newOrders: false);
      expect(updated.newOrders, isFalse);
      expect(updated.offerUpdates, _settings.offerUpdates);
    });
  });

  // ── Cubit tests ────────────────────────────────────────────────────────────

  group('NotificationSettingsCubit', () {
    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'loadSettings emits Loading then Loaded on success',
      build: () {
        when(() => mockDio.get(any())).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/notification/get-settings'),
              statusCode: 200,
              data: {
                'data': {
                  'new_orders': true,
                  'offer_updates': false,
                  'badge_updates': true,
                  'push_enabled': true,
                  'allow_admin_notification': false,
                }
              },
            ));
        return NotificationSettingsCubit(dio: mockDio);
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<NotificationSettingsLoading>(),
        isA<NotificationSettingsLoaded>(),
      ],
      verify: (cubit) {
        final state = cubit.state as NotificationSettingsLoaded;
        expect(state.settings.newOrders, isTrue);
        expect(state.settings.offerUpdates, isFalse);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'loadSettings emits Loading then Error on failure',
      build: () {
        when(() => mockDio.get(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/notification/get-settings'),
            message: 'Network error',
          ),
        );
        return NotificationSettingsCubit(dio: mockDio);
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<NotificationSettingsLoading>(),
        isA<NotificationSettingsError>(),
      ],
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'updateSetting emits Updating then Loaded on success',
      build: () {
        when(() => mockDio.patch(any(), data: any(named: 'data')))
            .thenAnswer((_) async => Response(
                  requestOptions:
                      RequestOptions(path: '/notification/update-settings'),
                  statusCode: 200,
                  data: {'success': true},
                ));
        return NotificationSettingsCubit(dio: mockDio);
      },
      act: (cubit) => cubit.updateSetting(_settings),
      expect: () => [
        isA<NotificationSettingsUpdating>(),
        isA<NotificationSettingsLoaded>(),
      ],
      verify: (cubit) {
        final state = cubit.state as NotificationSettingsLoaded;
        expect(state.settings, isA<NotificationSettings>());
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'updateSetting emits Updating then Error on failure',
      build: () {
        when(() => mockDio.patch(any(), data: any(named: 'data'))).thenThrow(
          DioException(
            requestOptions:
                RequestOptions(path: '/notification/update-settings'),
            message: 'Server error',
          ),
        );
        return NotificationSettingsCubit(dio: mockDio);
      },
      act: (cubit) => cubit.updateSetting(_settings),
      expect: () => [
        isA<NotificationSettingsUpdating>(),
        isA<NotificationSettingsError>(),
      ],
    );
  });
}
