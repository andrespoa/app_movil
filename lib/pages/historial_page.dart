import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../widgets/app_drawer.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  String ipServidor = "";
  List<Map<String, dynamic>> registros = [];
  List<Map<String, dynamic>> registrosFiltrados = [];
  bool cargando = true;
  String? errorMsg;

  // Filtro: si rangeStart/rangeEnd son nulos -> sin filtro (usar todo lo disponible)
  DateTime? rangeStart;
  DateTime? rangeEnd;

  Timer? _autoRefreshTimer;

  // quick filter selection index: 0 = none, 1 = 24h, 2 = 7d, 3 = 30d, 4 = custom
  int selectedQuick = 0;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ipServidor = prefs.getString('server_ip') ?? '';
    });
    await _obtenerHistorial();
    _setupAutoRefresh();
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    // Si hay un filtro aplicado (rangeStart != null) hacemos auto-refresh cada 30s
    if (rangeStart != null || rangeEnd != null || selectedQuick != 0) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _obtenerHistorial();
      });
    }
  }

  Future<void> _obtenerHistorial() async {
    if (ipServidor.isEmpty) {
      setState(() {
        cargando = false;
        errorMsg = "⚠️ Configura la IP del servidor en Ajustes";
      });
      return;
    }

    setState(() {
      cargando = true;
      errorMsg = null;
    });

    try {
      // Intentamos primero la ruta con /api/historial y si falla usamos /historial
      Uri url = Uri.parse("http://$ipServidor/api/historial");
      http.Response response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        url = Uri.parse("http://$ipServidor/historial");
        response = await http.get(url).timeout(const Duration(seconds: 6));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Aseguramos formato: lista de mapas
        List<Map<String, dynamic>> list = [];
        if (data is List) {
          for (final item in data) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }
        // ordenamos por fecha descendente (si hay campo fecha/fecha_hora)
        list.sort((a, b) {
          DateTime da = _parseFecha(a);
          DateTime db = _parseFecha(b);
          return db.compareTo(da);
        });

        setState(() {
          registros = list;
          _aplicarFiltro(); // actualiza registrosFiltrados
          cargando = false;
        });
      } else {
        setState(() {
          cargando = false;
          errorMsg = "Error del servidor (${response.statusCode})";
        });
      }
    } on TimeoutException {
      setState(() {
        cargando = false;
        errorMsg = "Tiempo de espera agotado al conectar con el servidor";
      });
    } on SocketException {
      setState(() {
        cargando = false;
        errorMsg = "No se pudo conectar (verifica IP y red)";
      });
    } catch (e) {
      setState(() {
        cargando = false;
        errorMsg = "Error inesperado: $e";
      });
    }
  }

  DateTime _parseFecha(Map<String, dynamic> item) {
    // Soportamos varias claves: 'fecha_hora', 'fecha', 'created_at', o ISO string
    final keys = ['fecha_hora', 'fecha', 'created_at', 'time'];
    for (final k in keys) {
      if (item.containsKey(k) && item[k] != null) {
        try {
          // Puede venir en ISO o en formato 'YYYY-MM-DD HH:MM:SS'
          final raw = item[k].toString();
          // Primero intento parse ISO
          final dt = DateTime.tryParse(raw);
          if (dt != null) return dt;
          // Si contiene espacio entre fecha y hora, intentar parse como yyyy-MM-dd HH:mm:ss
          final parts = raw.split(' ');
          if (parts.length >= 2) {
            final date = parts[0];
            final time = parts[1];
            final composed = "$date $time";
            // DateTime.parse may fail; intentar manual
            return DateTime.parse(raw.replaceAll(' ', 'T'));
          }
        } catch (_) {}
      }
    }
    // Si no hay campo reconocible, intentamos inferir desde 'id' como fallback
    return DateTime.now();
  }

  void _aplicarFiltro() {
    // Si no hay registros, limpiamos
    if (registros.isEmpty) {
      setState(() {
        registrosFiltrados = [];
      });
      return;
    }

    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;

    if (selectedQuick == 1) {
      end = now;
      start = now.subtract(const Duration(hours: 24));
    } else if (selectedQuick == 2) {
      end = now;
      start = now.subtract(const Duration(days: 7));
    } else if (selectedQuick == 3) {
      end = now;
      start = now.subtract(const Duration(days: 30));
    } else if (selectedQuick == 4 && rangeStart != null && rangeEnd != null) {
      start = rangeStart!;
      end = rangeEnd!;
    } else {
      // sin filtro -> usar todo
      setState(() {
        registrosFiltrados = List<Map<String, dynamic>>.from(registros);
      });
      return;
    }

    final filtered = registros.where((item) {
      final dt = _parseFecha(item);
      return dt.isAfter(start.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // Orden descendente (más reciente primero)
    filtered.sort((a, b) => _parseFecha(b).compareTo(_parseFecha(a)));

    setState(() {
      registrosFiltrados = filtered;
    });
  }

  // Stats: max/min/avg para temperatura y humedad
  Map<String, double> _calcularStats() {
    double maxTemp = double.negativeInfinity;
    double minTemp = double.infinity;
    double sumTemp = 0;
    int countTemp = 0;

    double maxHum = double.negativeInfinity;
    double minHum = double.infinity;
    double sumHum = 0;
    int countHum = 0;

    for (final item in registrosFiltrados) {
      final tRaw = item['temperatura'] ?? item['temp'] ?? item['temperature'];
      final hRaw = item['humedad'] ?? item['hum'] ?? item['humidity'];

      final t = (tRaw != null) ? double.tryParse(tRaw.toString()) : null;
      final h = (hRaw != null) ? double.tryParse(hRaw.toString()) : null;

      if (t != null) {
        if (t > maxTemp) maxTemp = t;
        if (t < minTemp) minTemp = t;
        sumTemp += t;
        countTemp++;
      }
      if (h != null) {
        if (h > maxHum) maxHum = h;
        if (h < minHum) minHum = h;
        sumHum += h;
        countHum++;
      }
    }

    return {
      'maxTemp': countTemp > 0 ? maxTemp : 0,
      'minTemp': countTemp > 0 ? minTemp : 0,
      'avgTemp': countTemp > 0 ? (sumTemp / countTemp) : 0,
      'maxHum': countHum > 0 ? maxHum : 0,
      'minHum': countHum > 0 ? minHum : 0,
      'avgHum': countHum > 0 ? (sumHum / countHum) : 0,
    };
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365)); // hasta 1 año atrás
    final initial = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: rangeStart != null && rangeEnd != null
          ? DateTimeRange(start: rangeStart!, end: rangeEnd!)
          : initial,
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark()), child: child!);
      },
    );

    if (picked != null) {
      setState(() {
        rangeStart = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        rangeEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        selectedQuick = 4;
      });
      _aplicarFiltro();
      _setupAutoRefresh();
    }
  }

  Future<void> _exportCSVAndShare() async {
    if (registrosFiltrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar")));
      return;
    }

    // Cabeceras
    final headers = ['fecha', 'temperatura', 'humedad'];
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final row in registrosFiltrados) {
      final dt = _parseFecha(row).toIso8601String();
      final temp = row['temperatura'] ?? row['temp'] ?? '';
      final hum = row['humedad'] ?? row['hum'] ?? '';
      buffer.writeln('$dt,$temp,$hum');
    }

    final csv = buffer.toString();

    // Guardar en archivo temporal y usar share_plus para compartir
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/historial_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'Historial de lecturas (exportado)');
  }

  Widget _buildQuickFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickButton("24h", 1),
        _quickButton("7d", 2),
        _quickButton("30d", 3),

        ElevatedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.calendar_today, color: Colors.tealAccent),
          label: const Text(
            "Calendario",
            style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E2C),
            side: const BorderSide(color: Colors.tealAccent, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        ),
      ],
    );
  }


  Widget _quickButton(String label, int index) {
    final selected = selectedQuick == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              selectedQuick = index;
              // limpiar custom range cuando seleccionamos quick
              if (index != 4) {
                rangeStart = null;
                rangeEnd = null;
              }
              _aplicarFiltro();
              _setupAutoRefresh();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: selected ? Colors.teal : Colors.grey[800],
          ),
          child: Text(label),
        ),
      ),
    );
  }

  // Construye la gráfica con fl_chart (dos líneas)
  Widget _buildChart() {
    if (registrosFiltrados.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text("No hay datos para mostrar", style: TextStyle(color: Colors.white70))),
      );
    }

    // tomamos max 50 puntos (o menos) y los ordenamos asc por tiempo para la gráfica
    final points = registrosFiltrados.reversed.toList(); // invertimos: más antiguo -> más reciente
    final maxPoints = points.length;
    final tempSpots = <FlSpot>[];
    final humSpots = <FlSpot>[];
    for (int i = 0; i < maxPoints; i++) {
      final row = points[i];
      final t = double.tryParse((row['temperatura'] ?? row['temp'] ?? 0).toString()) ?? 0.0;
      final h = double.tryParse((row['humedad'] ?? row['hum'] ?? 0).toString()) ?? 0.0;
      tempSpots.add(FlSpot(i.toDouble(), t));
      humSpots.add(FlSpot(i.toDouble(), h));
    }

    final stats = _calcularStats();

    return Column(
      children: [
        // tarjetas de estadisticas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statCard("Temp max", "${(stats['maxTemp'] ?? 0).toStringAsFixed(1)} °C", Colors.orange),
            _statCard("Temp avg", "${(stats['avgTemp'] ?? 0).toStringAsFixed(1)} °C", Colors.tealAccent),
            _statCard("Hum max", "${(stats['maxHum'] ?? 0).toStringAsFixed(1)} %", Colors.blue),

            _statCard("Temp min", "${(stats['minTemp'] ?? 0).toStringAsFixed(1)} °C", Colors.redAccent),
            _statCard("Hum min", "${(stats['minHum'] ?? 0).toStringAsFixed(1)} %", Colors.lightBlueAccent),
            _statCard("Hum avg", "${(stats['avgHum'] ?? 0).toStringAsFixed(1)} %", Colors.greenAccent),

          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              backgroundColor: Colors.transparent,
              gridData: FlGridData(show: true, horizontalInterval: 5),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (maxPoints <= 4) ? 1 : (maxPoints / 4),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                      final dt = _parseFecha(points[idx]).toLocal();
                      final label = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
                      return Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10));
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              minY: 0,
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: tempSpots,
                  isCurved: true,
                  color: Colors.orangeAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: humSpots,
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161621),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (registrosFiltrados.isEmpty) {
      return const Center(child: Text("No hay lecturas para mostrar", style: TextStyle(color: Colors.white70)));
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: registrosFiltrados.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (context, i) {
        final item = registrosFiltrados[i];
        final dt = _parseFecha(item).toLocal();
        final fechaStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        final temp = item['temperatura'] ?? item['temp'] ?? '-';
        final hum = item['humedad'] ?? item['hum'] ?? '-';
        return ListTile(
          leading: const Icon(Icons.thermostat, color: Colors.orangeAccent),
          title: Text("T: $temp °C  •  H: $hum %", style: const TextStyle(color: Colors.white)),
          subtitle: Text(fechaStr, style: const TextStyle(color: Colors.white70)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _obtenerHistorial();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCSVAndShare,
          ),
        ],
      ),
      drawer: appDrawer(context, currentRoute: '/historial'),
      backgroundColor: const Color(0xFF0F111A),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: cargando
            ? const Center(child: CircularProgressIndicator())
            : errorMsg != null
            ? Center(child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent)))
            : Column(
          children: [
            const SizedBox(height: 6),
            _buildQuickFilters(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildChart(),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161621),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Últimas lecturas", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildTable(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
