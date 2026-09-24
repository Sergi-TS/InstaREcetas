import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // For iOS, you typically need DarwinInitializationSettings
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> scheduleExpirationNotification({
    required int id,
    required String itemName,
    required DateTime expirationDate,
  }) async {
    // Calcular 2 días antes de la caducidad a las 10:00 AM
    DateTime notificationTime = expirationDate.subtract(const Duration(days: 2));
    notificationTime = DateTime(notificationTime.year, notificationTime.month, notificationTime.day, 10, 0);

    // Si la fecha ya ha pasado, no la programamos
    if (notificationTime.isBefore(DateTime.now())) {
      // Podríamos avisar hoy mismo o no hacer nada, por ahora no hacemos nada si ya pasó el margen
      return;
    }

    final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'fridge_expiration_channel',
      'Alertas de Caducidad',
      channelDescription: 'Avisos cuando un ingrediente está a punto de caducar',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails darwinPlatformChannelSpecifics = DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: '¡Ojo con la caducidad!',
      body: 'Tu ingrediente "$itemName" caduca en 2 días.',
      scheduledDate: scheduledDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
