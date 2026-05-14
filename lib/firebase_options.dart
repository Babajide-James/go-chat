import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'env/env.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _options;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _options;
      case TargetPlatform.iOS:
        return _options;
      case TargetPlatform.macOS:
        return _options;
      case TargetPlatform.windows:
        return _options;
      case TargetPlatform.linux:
        return _options;
      default:
        return _options;
    }
  }

  static final FirebaseOptions _options = FirebaseOptions(
    apiKey: Env.firebaseApiKey,
    appId: Env.firebaseAppId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    projectId: Env.firebaseProjectId,
    storageBucket: Env.firebaseStorageBucket,
  );
}
