import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        'expiry_channel',
        'Expiry Alerts',
        channelDescription: 'Notifications for expiring and expired items',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      );

  NotificationDetails get _notificationDetails => NotificationDetails(
        android: _androidDetails,
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> scheduleItemNotification({
    required int id,
    required String itemName,
    required DateTime expiryDate,
    required int reminderDays,
    required TimeOfDay notificationTime,
  }) async {
    final DateTime notifyDate = expiryDate.subtract(
      Duration(days: reminderDays),
    );

    final DateTime scheduledDateTime = DateTime(
      notifyDate.year,
      notifyDate.month,
      notifyDate.day,
      notificationTime.hour,
      notificationTime.minute,
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      print("⚠️ Notification time already passed for $itemName");
      return;
    }

    // ✅ Use tz.local which is now set to Asia/Kolkata
    final tz.TZDateTime tzScheduled = tz.TZDateTime.from(
      scheduledDateTime,
      tz.local,
    );

    String title;
    String body;

    if (reminderDays == 0) {
      title = "⚠️ $itemName Expires Today!";
      body = "$itemName expires today. Please use or discard it.";
    } else if (reminderDays == 1) {
      title = "⚠️ $itemName Expires Tomorrow!";
      body = "$itemName expires tomorrow. Don't forget!";
    } else {
      title = "🕐 $itemName Expiring Soon";
      body = "$itemName expires in $reminderDays days on "
          "${expiryDate.day}/${expiryDate.month}/${expiryDate.year}.";
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print("✅ Notification scheduled for $itemName at $scheduledDateTime");
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(id, title, body, _notificationDetails);
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  static int docIdToNotificationId(String docId) {
    return docId.hashCode.abs();
  }
}