import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notification service — used to tell someone their publication
/// finished (or failed) without needing to keep watching the screen,
/// and to remind them when a Time Capsule of theirs reaches its
/// opening date.
///
/// This is NOT a true background-service solution (see the earlier
/// conversation about why that's a bigger, platform-specific
/// undertaking). The publish-result notification fires from the same
/// polling loop that already runs while the publish flow screen is
/// open — works reliably while the app is foregrounded or briefly
/// backgrounded, but won't fire if the OS has fully suspended the app
/// after a long time away. The capsule-opening reminder is different:
/// it's scheduled with the OS itself (zonedSchedule) the moment the
/// capsule is opened/remembered in the app, so it can fire later even
/// if the app isn't running at all — standard OS-level alarm
/// scheduling, not something this app has to stay alive for.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    await _plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showPublishResult({required bool success, required String title, required String body}) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      'benchpad_publish',
      'Publish results',
      channelDescription: 'Tells you when a BenchPad publication finishes.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      success ? 1 : 2,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Schedules a reminder for the morning (9:00 local time) of a
  /// capsule's opening date. Silently does nothing if the date is
  /// today or already in the past — nothing to remind about by then.
  /// [notificationId] should be stable per-capsule (e.g. derived from
  /// its access key) so re-scheduling the same capsule replaces the
  /// old reminder instead of piling up duplicates.
  Future<void> scheduleCapsuleOpening({required int notificationId, required String title, required String body, required DateTime openingDate}) async {
    if (!_initialized) await init();
    final location = tz.local;
    final scheduled = tz.TZDateTime(location, openingDate.year, openingDate.month, openingDate.day, 9);
    if (!scheduled.isAfter(tz.TZDateTime.now(location))) return;

    const androidDetails = AndroidNotificationDetails(
      'benchpad_capsule_opening',
      'Capsule opening reminders',
      channelDescription: 'Tells you when one of your Time Capsules reaches its opening date.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
