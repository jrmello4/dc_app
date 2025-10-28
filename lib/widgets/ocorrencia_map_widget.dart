// lib/widgets/ocorrencia_map_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dc_app/models/ocorrencia.dart';

class OcorrenciaMapWidget extends StatelessWidget {
  final Ocorrencia ocorrencia;
  final double height;

  const OcorrenciaMapWidget({
    Key? key,
    required this.ocorrencia,
    this.height = 300,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug: verificar dados recebidos
    print('🗺️ OcorrenciaMapWidget - Dados recebidos:');
    print('   - ID: ${ocorrencia.id}');
    print('   - Latitude: ${ocorrencia.latitude}');
    print('   - Longitude: ${ocorrencia.longitude}');
    print('   - Polígonos: ${ocorrencia.poligonos?.length ?? 'null'}');
    
    // Determina o centro do mapa
    LatLng center;
    if (ocorrencia.latitude != null && ocorrencia.longitude != null) {
      center = LatLng(ocorrencia.latitude!, ocorrencia.longitude!);
      print('   - Centro do mapa: ${center.latitude}, ${center.longitude}');
    } else {
      // Fallback para Araquari se não houver coordenadas
      center = const LatLng(-26.3726761, -48.7233351);
      print('   - Centro padrão: ${center.latitude}, ${center.longitude}');
    }

    // Extrai polígonos dos dados
    List<List<LatLng>> polygons = [];
    if (ocorrencia.poligonos != null) {
      print('   - Processando ${ocorrencia.poligonos!.length} polígonos...');
      for (int i = 0; i < ocorrencia.poligonos!.length; i++) {
        var poligonoData = ocorrencia.poligonos![i];
        print('   - Polígono $i: ${poligonoData.keys.join(', ')}');
        
        if (poligonoData['geom'] != null && 
            poligonoData['geom']['coordinates'] != null) {
          final coords = poligonoData['geom']['coordinates'] as List;
          print('   - Coordenadas do polígono $i: ${coords.length} anéis');
          
          if (coords.isNotEmpty && coords.first is List) {
            final polygonCoords = coords.first as List;
            print('   - Pontos do polígono $i: ${polygonCoords.length} pontos');
            
            List<LatLng> polygonPoints = [];
            for (var coord in polygonCoords) {
              if (coord is List && coord.length >= 2) {
                polygonPoints.add(LatLng(coord[1], coord[0])); // GeoJSON: [lng, lat]
              }
            }
            if (polygonPoints.length >= 3) {
              polygons.add(polygonPoints);
              print('   - Polígono $i adicionado com ${polygonPoints.length} pontos');
            } else {
              print('   - Polígono $i ignorado (${polygonPoints.length} pontos - mínimo 3)');
            }
          }
        } else {
          print('   - Polígono $i sem dados geométricos válidos');
        }
      }
    }
    
    print('   - Total de polígonos processados: ${polygons.length}');

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            center: center,
            zoom: 15.0,
            interactiveFlags: InteractiveFlag.all,
          ),
          children: [
            // Camada de tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.dc_app',
            ),
            
            // Marcador da posição central
            if (ocorrencia.latitude != null && ocorrencia.longitude != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            
            // Polígonos desenhados
            if (polygons.isNotEmpty)
              PolygonLayer(
                polygons: polygons.map((polygon) => Polygon(
                  points: polygon,
                  color: Colors.blue.withOpacity(0.3),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2,
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
