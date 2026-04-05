import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('No Firebase options for this platform');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCrIHo81l9BjqZOhhnKX29y5vTsrShfxqo',
    // from Firebase Console
    appId: '1:574537141674:ios:cdc34c2a3739f1faddafd3',
    // 1:xxx:ios:xxx
    messagingSenderId: '574537141674',
    projectId: 'tawreedat-go',
    iosBundleId: 'com.nit.tawreedat.go',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCrIHo81l9BjqZOhhnKX29y5vTsrShfxqo',
    // from Firebase Console
    appId: '1:574537141674:android:aa40d62c10c00df0ddafd3',
    // 1:xxx:ios:xxx
    messagingSenderId: '574537141674',
    projectId: 'tawreedat-go',
  );
}
