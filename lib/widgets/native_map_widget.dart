// lib/widgets/native_map_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/models/setor.dart';

class NativeMapWidget extends StatefulWidget {
  final List<Setor> setores;
  final Position? currentPosition;
  final List<List<double>>? initialPolygon;
  final Function(List<List<double>>)? onPolygonChanged;
  final Function(Setor?)? onSetorSelected;
  final bool showSetores;
  final bool allowDrawing;

  const NativeMapWidget({
    Key? key,
    required this.setores,
    this.currentPosition,
    this.initialPolygon,
    this.onPolygonChanged,
    this.onSetorSelected,
    this.showSetores = true,
    this.allowDrawing = true,
  }) : super(key: key);

  @override
  State<NativeMapWidget> createState() => _NativeMapWidgetState();
}

class _NativeMapWidgetState extends State<NativeMapWidget> {
  List<LatLng> _polygonPoints = [];
  Setor? _selectedSetor;
  bool _isDrawing = false;
  double _area = 0.0;
  double _perimeter = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPolygon != null) {
      _polygonPoints = widget.initialPolygon!
          .map((point) => LatLng(point[0], point[1]))
          .toList();
      _calculateMetrics();
    }
  }

  void _calculateMetrics() {
    if (_polygonPoints.length < 3) {
      _area = 0.0;
      _perimeter = 0.0;
      return;
    }

    // Cálculo correto de área usando fórmula de Shoelace
    double area = 0.0;
    for (int i = 0; i < _polygonPoints.length; i++) {
      int j = (i + 1) % _polygonPoints.length;
      area += _polygonPoints[i].longitude * _polygonPoints[j].latitude;
      area -= _polygonPoints[j].longitude * _polygonPoints[i].latitude;
    }
    area = area.abs() / 2;

    // Conversão para metros quadrados (aproximação)
    _area = area * 111320 * 111320;

    // Cálculo de perímetro usando fórmula de Haversine
    _perimeter = 0.0;
    for (int i = 0; i < _polygonPoints.length; i++) {
      int j = (i + 1) % _polygonPoints.length;
      _perimeter += _calculateDistance(_polygonPoints[i], _polygonPoints[j]);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.allowDrawing) return;

    setState(() {
      if (!_isDrawing) {
        _polygonPoints.clear();
        _isDrawing = true;
      }
      _polygonPoints.add(point);
      _calculateMetrics();
    });

    // Notifica mudança
    if (_polygonPoints.length >= 3) {
      final polygonData = _polygonPoints.map((p) => [p.latitude, p.longitude]).toList();
      widget.onPolygonChanged?.call(polygonData);
    }
  }

  void _finishDrawing() {
    setState(() {
      _isDrawing = false;
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _isDrawing = false;
      _area = 0.0;
      _perimeter = 0.0;
    });
    widget.onPolygonChanged?.call([]);
  }

  void _onSetorTap(Setor setor) {
    setState(() {
      _selectedSetor = setor;
    });
    widget.onSetorSelected?.call(setor);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentPosition != null
        ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
        : const LatLng(-26.3726761, -48.7233351); // Araquari, SC

    return Column(
      children: [
        // Controles do mapa
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              if (widget.allowDrawing) ...[
                ElevatedButton.icon(
                  onPressed: _isDrawing ? _finishDrawing : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Finalizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _polygonPoints.isNotEmpty ? _clearPolygon : null,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _polygonPoints.isEmpty
                      ? 'Toque no mapa para desenhar'
                      : '${_polygonPoints.length} pontos - Área: ${_area.toStringAsFixed(0)} m²',
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        
        // Mapa
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              center: center,
              zoom: 15.0,
              onTap: _onMapTap,
            ),
            children: [
              // Camada de tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.dc_app',
              ),
              
              // Marcador da posição atual
              if (widget.currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              
              // Setores (círculos)
              if (widget.showSetores)
                CircleLayer(
                  circles: widget.setores.map((setor) {
                    final isSelected = _selectedSetor?.id == setor.id;
                    return CircleMarker(
                      point: LatLng(
                        setor.latitude ?? center.latitude,
                        setor.longitude ?? center.longitude,
                      ),
                      radius: (setor.raio ?? 500).toDouble(),
                      color: isSelected ? Colors.green : Colors.blue,
                      borderColor: isSelected ? Colors.green.shade800 : Colors.blue.shade800,
                      useRadiusInMeter: true,
                    );
                  }).toList(),
                ),
              
              // Marcadores dos setores
              if (widget.showSetores)
                MarkerLayer(
                  markers: widget.setores.map((setor) {
                    final isSelected = _selectedSetor?.id == setor.id;
                    return Marker(
                      point: LatLng(
                        setor.latitude ?? center.latitude,
                        setor.longitude ?? center.longitude,
                      ),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _onSetorTap(setor),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green : Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              
              // Polígono desenhado
              if (_polygonPoints.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: Colors.green.withOpacity(0.3),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              
              // Pontos do polígono
              if (_polygonPoints.isNotEmpty)
                MarkerLayer(
                  markers: _polygonPoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final point = entry.value;
                    return Marker(
                      point: point,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        
        // Informações do polígono
        if (_polygonPoints.length >= 3)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Área: ${_area.toStringAsFixed(0)} m²'),
                Text('Perímetro: ${_perimeter.toStringAsFixed(0)} m'),
                Text('Pontos: ${_polygonPoints.length}'),
              ],
            ),
          ),
      ],
    );
  }
}
