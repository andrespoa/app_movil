import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/historial_page.dart';
import 'pages/notificaciones_page.dart';
import 'pages/configuracion_page.dart';
import 'pages/splash_page.dart';          // ✅ Splash Page
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();   // ✅ Notificaciones listas
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Dashboard',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        primaryColor: Colors.teal,
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        cardColor: const Color(0xFF1C1E29),
      ),

      // ✅ Ahora la app inicia en la pantalla de carga
      initialRoute: '/splash',

      routes: {
        '/splash': (context) => const SplashPage(),
        '/': (context) => const DashboardPage(),
        '/historial': (context) => const HistorialPage(),
        '/notificaciones': (context) => const NotificacionesPage(),
        '/configuracion': (context) => const ConfiguracionPage(),
      },
    );
  }
}
