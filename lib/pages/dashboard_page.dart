import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../widgets/sensor_gauge.dart';
import '../widgets/app_drawer.dart';
import '../services/notification_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String ipServidor = "";
  String puertoServidor = "5000";

  double temperatura = 0.0;
  double humedad = 0.0;

  // 🔥 UMBRALES CONFIGURABLES
  double tempMax = 30.0;
  double humMin = 30.0;
  double humMax = 90.0;

  bool notificacionesActivas = true;

  bool cargando = true;
  String? errorMsg;

  Timer? _timer;

  // Anti-spam
  bool tempAlertShown = false;
  bool humAlertShown = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// ✅ Cargar IP + Puerto + Umbrales + Notificaciones
  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();

    ipServidor = prefs.getString('server_ip') ?? "";
    puertoServidor = prefs.getString('server_port') ?? "5000";

    tempMax = prefs.getDouble('temp_max') ?? 30.0;
    humMin = prefs.getDouble('hum_min') ?? 30.0;
    humMax = prefs.getDouble('hum_max') ?? 90.0;

    notificacionesActivas = prefs.getBool('notif_activas') ?? true;

    if (!mounted) return;

    setState(() {});

    if (ipServidor.isNotEmpty) {
      await _obtenerDatos();

      // 🔄 Actualizar cada 10s
      _timer =
          Timer.periodic(const Duration(seconds: 10), (_) => _obtenerDatos());
    } else {
      setState(() => cargando = false);
    }
  }

  /// ✅ Obtener datos del servidor Flask
  Future<void> _obtenerDatos() async {
    final url = Uri.parse("http://$ipServidor:$puertoServidor/api/ultimo");

    try {
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final nuevaTemp = (data["temperatura"] ?? 0).toDouble();
        final nuevaHum = (data["humedad"] ?? 0).toDouble();

        setState(() {
          temperatura = nuevaTemp;
          humedad = nuevaHum;
          cargando = false;
          errorMsg = null;
        });

        _verificarUmbrales(nuevaTemp, nuevaHum);
      } else {
        setState(() {
          cargando = false;
          errorMsg = "⚠️ Error del servidor (${response.statusCode})";
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        errorMsg = "⚠️ No se pudo conectar con el servidor";
      });
    }
  }

  /// ✅ Verificación de umbrales con ANTI-SPAM
  void _verificarUmbrales(double nuevaTemp, double nuevaHum) {
    if (!notificacionesActivas) return;

    // 🔥 Temperatura
    if (nuevaTemp > tempMax && !tempAlertShown) {
      NotificationService.showNotification(
        title: "⚠️ Temperatura Alta",
        body: "La temperatura alcanzó ${nuevaTemp.toStringAsFixed(1)} °C "
            "(máx $tempMax °C)",
      );
      tempAlertShown = true;
    } else if (nuevaTemp <= tempMax) {
      tempAlertShown = false;
    }

    // 💧 Humedad fuera de rango
    if ((nuevaHum < humMin || nuevaHum > humMax) && !humAlertShown) {
      NotificationService.showNotification(
        title: "💧 Humedad fuera de rango",
        body:
        "Humedad: ${nuevaHum.toStringAsFixed(1)} %  (min $humMin – max $humMax)",
      );
      humAlertShown = true;
    } else if (nuevaHum >= humMin && nuevaHum <= humMax) {
      humAlertShown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget contenido;

    if (cargando) {
      contenido = const Center(child: CircularProgressIndicator());
    } else if (ipServidor.isEmpty) {
      contenido = const Center(
        child: Text(
          "⚠️ Configura primero la dirección IP en Ajustes",
          style: TextStyle(color: Colors.white70),
        ),
      );
    } else if (errorMsg != null) {
      contenido = Center(
        child: Text(
          errorMsg!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
      );
    } else {
      contenido = RefreshIndicator(
        onRefresh: _obtenerDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SensorGauge(
                titulo: "Temperatura",
                valor: temperatura,
                unidad: "°C",
                tipo: "temperatura",
                maxValue: 50,
              ),
              const SizedBox(height: 20),

              SensorGauge(
                titulo: "Humedad",
                valor: humedad,
                unidad: "%",
                tipo: "humedad",
                maxValue: 100,
              ),

              const SizedBox(height: 30),
              Text(
                "Última actualización: ${DateTime.now().toLocal().toString().split('.')[0]}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.teal,
      ),
      drawer: appDrawer(context, currentRoute: '/'),
      body: contenido,
      backgroundColor: const Color(0xFF0F111A),
    );
  }
}
