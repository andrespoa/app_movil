import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Inicializa el servicio
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Muestra la notificación local
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'alertas_channel',
      'Alertas Sensor',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID único
      title,
      body,
      platformDetails,
    );

    await _saveNotification(title, body);
  }

  /// Guarda notificación en historial local
  static Future<void> _saveNotification(String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final String timestamp =
    DateTime.now().toLocal().toString().split('.')[0]; // sin milisegundos
    final notification = {
      "title": title,
      "body": body,
      "time": timestamp,
    };

    final String? stored = prefs.getString('notificaciones');
    List<dynamic> list = stored != null ? jsonDecode(stored) : [];

    list.insert(0, notification); // añade al inicio
    if (list.length > 30) list = list.sublist(0, 30); // máximo 30 registros

    await prefs.setString('notificaciones', jsonEncode(list));
  }

  /// Obtiene el historial guardado
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('notificaciones');
    if (stored == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(stored));
  }

  /// Limpia todas las notificaciones guardadas
  static Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notificaciones');
  }
}
