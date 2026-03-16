/// App-wide constants.
///
/// The Google Maps API key is injected at **compile time** via `--dart-define`
/// so it never lives in source control.
///
/// Run / build commands:
///   flutter run  --dart-define=MAPS_API_KEY=AIza...
///   flutter build apk --dart-define=MAPS_API_KEY=AIza...
///
/// In VS Code add to .vscode/launch.json:
///   "args": ["--dart-define=MAPS_API_KEY=AIza..."]
///
/// In Android Studio add to Run > Edit Configurations > Additional run args.
///
/// For CI/CD (GitHub Actions example):
///   flutter build apk --dart-define=MAPS_API_KEY=${{ secrets.MAPS_API_KEY }}
library;

class AppConstants {
  AppConstants._();

  /// Google Maps / Places / Geocoding API key.
  /// Supplied via --dart-define=MAPS_API_KEY=... at build time.
  static const String googleMapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: '', // empty string fails loudly in debug rather than silently
  );
}