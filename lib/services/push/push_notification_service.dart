import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static String? _registeredUserId;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static String? _registeredUserForToken;
  static bool _firebaseInitialized = false;

  static bool get isEnabled => _firebaseInitialized;

  static Future<void> initializeForCurrentPlatform() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _firebaseInitialized) {
      return;
    }
    await Firebase.initializeApp();
    _firebaseInitialized = true;
  }

  static Future<void> registerDevice({
    required SupabaseClient client,
    required String userId,
  }) async {
    if (!isEnabled || kIsWeb) return;
    _registeredUserId = userId;
    if (_registeredUserForToken == userId) return;

    final messaging = FirebaseMessaging.instance;
    // FCM HTTP v1 requires the registration token rather than the Firebase Installation ID.
    // ignore: deprecated_member_use
    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
      (token) {
        final currentUserId = _registeredUserId;
        if (currentUserId == null) return;
        unawaited(
          _saveToken(client, currentUserId, token).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            debugPrint('Could not update the owner push token: $error');
          }),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Push registration failed: $error');
      },
    );
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    // FCM HTTP v1 requires the registration token, not the Firebase Installation ID.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token == null) {
      throw StateError('Firebase did not provide an FCM registration token.');
    }
    await _saveToken(client, userId, token);
    _registeredUserForToken = userId;
  }

  static Future<void> _saveToken(
    SupabaseClient client,
    String userId,
    String token,
  ) async {
    await client.from('user_push_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
  }
}
