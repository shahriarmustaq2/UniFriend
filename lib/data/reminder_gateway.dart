import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/reminder_plan.dart';

/// Schedules notifications on the device. An interface so the rest of the app
/// can be tested without a phone.
abstract class ReminderGateway {
  bool get isSupported;

  /// Routes of notifications the student tapped, including the one that launched
  /// the app.
  Stream<String> get tappedRoutes;

  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> replaceAll(List<PlannedReminder> plan);
  Future<void> cancelAll();
  Future<void> showTest();
}

class LocalReminderGateway implements ReminderGateway {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController.broadcast();
  Future<void>? _ready;

  static const _classChannel = AndroidNotificationDetails(
    'classes',
    'Classes',
    channelDescription: 'Before each class in your routine',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _deadlineChannel = AndroidNotificationDetails(
    'deadlines',
    'Deadlines',
    channelDescription: 'Before an assignment is due or an exam',
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Stream<String> get tappedRoutes => _taps.stream;

  @override
  Future<void> initialize() => _ready ??= _initialize();

  Future<void> _initialize() async {
    if (!isSupported) return;

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // Schedules are built from exact instants, so they still fire on time.
      debugPrint('Could not read the device time zone: $error');
    }

    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: darwin,
        macOS: darwin,
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null) _taps.add(route);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final route = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && route != null) {
      // On the next turn, so a listener attached right after this still hears it.
      scheduleMicrotask(() => _taps.add(route));
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!isSupported) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    return await macos?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {
    await initialize();
    if (!isSupported) return;
    await _plugin.cancelAll();

    var id = 0;
    for (final reminder in plan) {
      await _plugin.zonedSchedule(
        id: id++,
        title: reminder.title,
        body: reminder.body,
        payload: reminder.route,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
        notificationDetails: NotificationDetails(
          android: reminder.kind == ReminderKind.classSlot
              ? _classChannel
              : _deadlineChannel,
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
        ),
        // Inexact, because exact alarms need a permission students would have to
        // grant in system settings. Android may deliver these a few minutes late.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    if (isSupported) await _plugin.cancelAll();
  }

  @override
  Future<void> showTest() async {
    await initialize();
    if (!isSupported) return;
    await _plugin.show(
      id: 9999,
      title: 'Reminders are working',
      body: 'This is how UniFriend will remind you.',
      notificationDetails: const NotificationDetails(
        android: _classChannel,
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }
}
