import 'dart:async';

import 'package:cycle_ready/src/features/coaching/application/coach_reminder_controller.dart';
import 'package:cycle_ready/src/features/notifications/data/supabase_push_token_repository.dart';
import 'package:cycle_ready/src/features/notifications/domain/push_message.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pushNotificationServiceProvider = Provider((ref) {
  return PushNotificationService(
    messaging: FirebaseMessaging.instance,
    tokens: SupabasePushTokenRepository(Supabase.instance.client),
    showForeground: (message) =>
        ref.read(coachReminderServiceProvider).showCloudNotification(
              id: message.id,
              title: message.title,
              body: message.body,
              route: message.route,
            ),
  );
});

class PushNotificationService {
  PushNotificationService({
    required this.messaging,
    required this.tokens,
    required this.showForeground,
  });

  final FirebaseMessaging messaging;
  final SupabasePushTokenRepository tokens;
  final Future<void> Function(PushMessage message) showForeground;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> initializeFirebase() async {
    if (!isSupported) return false;
    await Firebase.initializeApp();
    return true;
  }

  Future<void> start({required void Function(String route) openRoute}) async {
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) await tokens.register(token);
    _tokenSubscription = messaging.onTokenRefresh.listen(tokens.register);
    _messageSubscription = FirebaseMessaging.onMessage.listen((remote) {
      showForeground(_message(remote));
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((remote) {
      openRoute(_message(remote).route);
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null) openRoute(_message(initial).route);
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
  }

  PushMessage _message(RemoteMessage remote) => PushMessage.fromData({
        ...remote.data,
        'title': remote.notification?.title ?? remote.data['title'],
        'body': remote.notification?.body ?? remote.data['body'],
        'notification_id': remote.messageId ?? remote.data['notification_id'],
      });
}
