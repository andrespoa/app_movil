import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_drawer.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _tempMaxController = TextEditingController();
  final _humMinController = TextEditingController();
  final _humMaxController = TextEditingController();

  bool notificacionesActivas = true;
  bool modoOscuro = true;
  bool conectado = false;
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _tempMaxController.dispose();
    _humMinController.dispose();
    _humMaxController.dispose();
    super.dispose();
  }

  /// ✅ Cargar configuración guardada
  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? '';
      _portController.text = prefs.getString('server_port') ?? '5000';

      _tempMaxController.text =
          (prefs.getDouble('temp_max') ?? 30.0).toString();

      _humMinController.text =
          (prefs.getDouble('hum_min') ?? 30.0).toString();

      _humMaxController.text =
          (prefs.getDouble('hum_max') ?? 90.0).toString();

      notificacionesActivas =
          prefs.getBool('notif_activas') ?? true;

      modoOscuro = prefs.getBool('modo_oscuro') ?? true;
    });
  }

  /// ✅ Guardar configuración
  Future<void> _guardarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('server_ip', _ipController.text.trim());
    await prefs.setString('server_port', _portController.text.trim());

    await prefs.setDouble('temp_max',
        double.tryParse(_tempMaxController.text) ?? 30.0);

    await prefs.setDouble('hum_min',
        double.tryParse(_humMinController.text) ?? 30.0);

    await prefs.setDouble('hum_max',
        double.tryParse(_humMaxController.text) ?? 90.0);

    await prefs.setBool('notif_activas', notificacionesActivas);
    await prefs.setBool('modo_oscuro', modoOscuro);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Configuración guardada")),
    );
  }

  /// ✅ Probar conexión con servidor Flask
  Future<void> _probarConexion() async {
    setState(() => cargando = true);

    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    final url = Uri.parse("http://$ip:$port/api/ultimo");

    try {
      final response =
      await http.get(url).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => conectado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🌐 Conexión exitosa con el servidor")),
        );
      } else {
        setState(() => conectado = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "⚠️ Error del servidor (${response.statusCode})")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => conectado = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No se pudo conectar con el servidor")),
      );
    } finally {
      if (!mounted) return;
      setState(() => cargando = false);
    }
  }

  /// ✅ Borrar TODO local
  Future<void> _borrarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _cargarConfiguracion();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🧹 Datos locales borrados")),
    );
  }

  /// ✅ Restaurar valores por defecto
  Future<void> _restablecerValores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await prefs.setDouble('temp_max', 30.0);
    await prefs.setDouble('hum_min', 30.0);
    await prefs.setDouble('hum_max', 90.0);
    await prefs.setBool('notif_activas', true);
    await prefs.setBool('modo_oscuro', true);

    if (!mounted) return;

    _cargarConfiguracion();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🔄 Configuración restablecida")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración"),
        backgroundColor: Colors.teal,
      ),
      drawer: appDrawer(context, currentRoute: '/configuracion'),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =======================
          // 🔗 Conexión con servidor
          // =======================
          const Text(
            "🔗 Conexión con el servidor",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
                labelText: "Dirección IP del servidor"),
          ),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
                labelText: "Puerto (por defecto 5000)"),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            icon: const Icon(Icons.wifi_tethering),
            label: const Text("Probar conexión"),
            onPressed: _probarConexion,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(
                conectado ? Icons.cloud_done : Icons.cloud_off,
                color: conectado
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                conectado ? "Conectado" : "Desconectado",
                style: TextStyle(
                    color: conectado
                        ? Colors.greenAccent
                        : Colors.redAccent),
              ),
            ],
          ),

          const Divider(height: 30, color: Colors.white24),

          // =======================
          // 🌡️ Umbrales
          // =======================
          const Text(
            "🌡️ Umbrales de alerta",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _tempMaxController,
            decoration: const InputDecoration(
                labelText: "Temperatura máxima (°C)"),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _humMinController,
            decoration: const InputDecoration(
                labelText: "Humedad mínima (%)"),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _humMaxController,
            decoration: const InputDecoration(
                labelText: "Humedad máxima (%)"),
            keyboardType: TextInputType.number,
          ),

          const Divider(height: 30, color: Colors.white24),

          // =======================
          // 🔔 Notificaciones
          // =======================
          const Text(
            "🔔 Notificaciones",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent),
          ),

          SwitchListTile(
            title: const Text("Activar notificaciones"),
            value: notificacionesActivas,
            onChanged: (v) =>
                setState(() => notificacionesActivas = v),
          ),

          const Divider(height: 30, color: Colors.white24),

          // =======================
          // 🎨 Apariencia
          // =======================
          const Text(
            "🎨 Apariencia",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent),
          ),

          SwitchListTile(
            title: const Text("Modo oscuro"),
            value: modoOscuro,
            onChanged: (v) =>
                setState(() => modoOscuro = v),
          ),

          const Divider(height: 30, color: Colors.white24),

          // =======================
          // ✅ Botones
          // =======================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Guardar"),
                onPressed: _guardarConfiguracion,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text("Restablecer"),
                onPressed: _restablecerValores,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.delete_forever,
                  color: Colors.redAccent),
              label: const Text(
                "Borrar datos locales",
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: _borrarDatos,
            ),
          ),
        ],
      ),
    );
  }
}
