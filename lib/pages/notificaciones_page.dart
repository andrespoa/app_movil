import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/notification_service.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  List<Map<String, dynamic>> notificaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    final data = await NotificationService.getNotifications();
    setState(() {
      notificaciones = data;
    });
  }

  Future<void> _limpiarNotificaciones() async {
    await NotificationService.clearNotifications();
    setState(() {
      notificaciones = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notificaciones"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _limpiarNotificaciones,
          ),
        ],
      ),
      drawer: appDrawer(context, currentRoute: '/notificaciones'),
      body: notificaciones.isEmpty
          ? const Center(
        child: Text("No hay notificaciones aún 💤"),
      )
          : ListView.builder(
        itemCount: notificaciones.length,
        itemBuilder: (context, index) {
          final item = notificaciones[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.teal),
              title: Text(item["title"] ?? ""),
              subtitle: Text("${item["body"]}\n🕒 ${item["time"]}"),
            ),
          );
        },
      ),
    );
  }
}
