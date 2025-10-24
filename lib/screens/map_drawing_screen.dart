// lib/screens/map_drawing_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/services/ocorrencia_service.dart';
import 'package:dc_app/services/location_service.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/widgets/native_map_widget.dart';

class MapDrawingScreen extends StatefulWidget {
  const MapDrawingScreen({Key? key}) : super(key: key);

  @override
  State<MapDrawingScreen> createState() => _MapDrawingScreenState();
}

class _MapDrawingScreenState extends State<MapDrawingScreen> {
  List<List<double>> _selectedPolygon = [];
  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  bool _allowDrawing = true;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtém localização atual automaticamente
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar dados: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _logger.d('🔍 Iniciando obtenção de localização...');
      
      // Solicita permissão de localização
      bool hasPermission = await LocationService.requestLocationPermission();
      if (!hasPermission) {
        _logger.w('❌ Permissão de localização negada');
        throw Exception('Permissão de localização negada');
      }
      _logger.d('✅ Permissão de localização concedida');

      // Obtém localização atual
      _logger.d('📍 Obtendo localização atual...');
      final locationData = await LocationService.getCurrentLocationOnly();
      
      if (locationData != null) {
        _logger.d('✅ Localização obtida: ${locationData['latitude']}, ${locationData['longitude']}');
        setState(() {
          _currentPosition = Position(
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            timestamp: DateTime.now(),
            accuracy: locationData['accuracy'] ?? 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });
        _logger.d('✅ Posição atual definida no estado');
      } else {
        _logger.w('❌ Dados de localização nulos');
      }
    } catch (e) {
      _logger.e('❌ Erro ao obter localização', error: e);
      // Continua sem localização se houver erro
    }
  }

  void _onPolygonChanged(List<List<double>> polygon) {
    setState(() {
      _selectedPolygon = polygon;
    });
  }



  double _calculatePolygonArea(List<List<double>> polygon) {
    if (polygon.length < 3) return 0.0;
    
    double area = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      int j = (i + 1) % polygon.length;
      area += polygon[i][0] * polygon[j][1];
      area -= polygon[j][0] * polygon[i][1];
    }
    return (area.abs() / 2) * 111320 * 111320; // Aproximação para metros quadrados
  }

  double _calculatePolygonPerimeter(List<List<double>> polygon) {
    if (polygon.length < 2) return 0.0;
    
    double perimeter = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      int j = (i + 1) % polygon.length;
      double lat1 = polygon[i][0] * 3.14159265359 / 180;
      double lat2 = polygon[j][0] * 3.14159265359 / 180;
      double dLat = (polygon[j][0] - polygon[i][0]) * 3.14159265359 / 180;
      double dLng = (polygon[j][1] - polygon[i][1]) * 3.14159265359 / 180;
      
      double a = sin(dLat / 2) * sin(dLat / 2) +
                 cos(lat1) * cos(lat2) *
                 sin(dLng / 2) * sin(dLng / 2);
      double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      
      perimeter += 6371000 * c; // Raio da Terra em metros
    }
    return perimeter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desenhar Área no Mapa'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar dados',
          ),
          if (_selectedPolygon.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_selectedPolygon),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Usar Esta Área', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [

                    // Mapa interativo
        Expanded(
          child: NativeMapWidget(
            currentPosition: _currentPosition,
            initialPolygon: _selectedPolygon,
            onPolygonChanged: _onPolygonChanged,
            allowDrawing: _allowDrawing,
          ),
        ),

                    // Painel de informações
                    if (_selectedPolygon.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Área Selecionada:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.straighten,
                                    title: 'Área',
                                    value: '${SetorLocationService.calculatePolygonArea(_selectedPolygon).toStringAsFixed(2)} m²',
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.timeline,
                                    title: 'Perímetro',
                                    value: '${SetorLocationService.calculatePolygonPerimeter(_selectedPolygon).toStringAsFixed(2)} m',
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.location_on,
                                    title: 'Pontos',
                                    value: '${_selectedPolygon.length}',
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoCard(
                                    icon: Icons.check_circle,
                                    title: 'Válido',
                                    value: SetorLocationService.isValidPolygon(_selectedPolygon) ? 'Sim' : 'Não',
                                    color: SetorLocationService.isValidPolygon(_selectedPolygon) ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Botões de ação
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Cancelar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
