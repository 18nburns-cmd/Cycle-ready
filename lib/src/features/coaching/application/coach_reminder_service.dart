import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CoachReminderSettings {
  const CoachReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class CoachReminderService {
  CoachReminderService({
    FlutterLocalNotificationsPlugin? notifications,
    FlutterSecureStorage? storage,
  })  : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _notificationId = 2030;
  static const _enabledKey = 'coachReminderEnabled';
  static const _hourKey = 'coachReminderHour';
  static const _minuteKey = 'coachReminderMinute';

  final FlutterLocalNotificationsPlugin _notifications;
  final FlutterSecureStorage _storage;
  bool _initialized = false;

  Future<void> initialize(
      {required void Function(String route) openRoute}) async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // timezone defaults to UTC if the device identifier cannot be resolved.
      // Scheduling still works; the next app start will try again.
    }
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_cycle_ready'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          openRoute(response.payload ?? '/coach'),
    );
    _initialized = true;
    final launch = await _notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      openRoute(launch?.notificationResponse?.payload ?? '/coach');
    }
  }

  Future<CoachReminderSettings> load() async {
    final enabled = await _storage.read(key: _enabledKey) == 'true';
    return CoachReminderSettings(
      enabled: enabled,
      hour: int.tryParse(await _storage.read(key: _hourKey) ?? '') ?? 20,
      minute: int.tryParse(await _storage.read(key: _minuteKey) ?? '') ?? 30,
    );
  }

  Future<bool> enable({
    required int hour,
    required int minute,
  }) async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final allowed = await android?.requestNotificationsPermission() ?? true;
    if (!allowed) return false;
    await _save(enabled: true, hour: hour, minute: minute);
    await _schedule(hour: hour, minute: minute);
    return true;
  }

  Future<void> disable() async {
    await _notifications.cancel(id: _notificationId);
    final current = await load();
    await _save(
      enabled: false,
      hour: current.hour,
      minute: current.minute,
    );
  }

  Future<void> updateTime({required int hour, required int minute}) async {
    final current = await load();
    await _save(enabled: current.enabled, hour: hour, minute: minute);
    if (current.enabled) await _schedule(hour: hour, minute: minute);
  }

  Future<void> restoreSchedule() async {
    final settings = await load();
    if (settings.enabled) {
      await _schedule(hour: settings.hour, minute: settings.minute);
    }
  }

  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> showRecovery({
    required String activityId,
    required String rideTitle,
    required String body,
  }) async {
    final allowed = await requestPermission();
    if (!allowed) return;
    await _notifications.show(
      id: 3000 + (activityId.hashCode & 0x0FFFFFFF),
      title: 'Recovery fuel after $rideTitle',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'post_ride_recovery',
          'Post-ride recovery',
          channelDescription:
              'Nutrition and hydration guidance after completed training',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.recommendation,
        ),
      ),
      payload: '/nutrition',
    );
  }

  Future<void> _schedule({required int hour, required int minute}) async {
    await _notifications.cancel(id: _notificationId);
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _notifications.zonedSchedule(
      id: _notificationId,
      title: 'Your CycleReady coach is ready',
      body: 'Review today’s training, recovery, fuel and tomorrow’s focus.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_coach',
          'Daily coaching',
          channelDescription: 'Evening training and recovery coaching reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/coach',
    );
  }

  Future<void> _save({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await Future.wait([
      _storage.write(key: _enabledKey, value: enabled.toString()),
      _storage.write(key: _hourKey, value: hour.toString()),
      _storage.write(key: _minuteKey, value: minute.toString()),
    ]);
  }
}
