import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class SensorGauge extends StatelessWidget {
  final String titulo;
  final double valor;
  final String unidad;
  final String tipo; // "temperatura" o "humedad"
  final double maxValue;

  const SensorGauge({
    super.key,
    required this.titulo,
    required this.valor,
    required this.unidad,
    required this.tipo,
    required this.maxValue,
  });

  /// 🔹 Determina color dinámico según tipo y valor
  Color getDynamicColor(double v) {
    if (tipo.toLowerCase() == "temperatura") {
      if (v < 20) return Colors.blueAccent;
      if (v < 30) return Colors.orangeAccent;
      return Colors.redAccent;
    } else if (tipo.toLowerCase() == "humedad") {
      if (v < 30) return Colors.lightBlueAccent;
      if (v < 70) return Colors.blueAccent;
      return Colors.indigo;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = getDynamicColor(valor);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161621),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: baseColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // 🔹 Animación suave del valor del gauge
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: valor),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              final dynamicColor = getDynamicColor(animatedValue);

              return SizedBox(
                height: 120,
                child: SfRadialGauge(
                  enableLoadingAnimation: false,
                  axes: <RadialAxis>[
                    RadialAxis(
                      minimum: 0,
                      maximum: maxValue,
                      showTicks: false,
                      showLabels: false,
                      axisLineStyle: AxisLineStyle(
                        thickness: 0.2,
                        cornerStyle: CornerStyle.bothCurve,
                        color: dynamicColor.withOpacity(0.15),
                        thicknessUnit: GaugeSizeUnit.factor,
                      ),
                      pointers: <GaugePointer>[
                        RangePointer(
                          value: animatedValue,
                          width: 0.2,
                          sizeUnit: GaugeSizeUnit.factor,
                          color: dynamicColor,
                          cornerStyle: CornerStyle.bothCurve,
                        ),
                      ],
                      annotations: <GaugeAnnotation>[
                        GaugeAnnotation(
                          positionFactor: 0.1,
                          angle: 90,
                          widget: Text(
                            "${animatedValue.toStringAsFixed(1)} $unidad",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
