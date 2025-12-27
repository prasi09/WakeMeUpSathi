import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);
  }

  static Future<void> showAlert() async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'destination_alert',
      'Destination Alert',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'Destination Nearby 🚍',
      'You are close to your drop location',
      details,
    );
  }
}
