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
    // Determina o centro do mapa
    LatLng center;
    if (ocorrencia.latitude != null && ocorrencia.longitude != null) {
      center = LatLng(ocorrencia.latitude!, ocorrencia.longitude!);
    } else {
      // Fallback para Araquari se não houver coordenadas
      center = const LatLng(-26.3726761, -48.7233351);
    }

    // Extrai polígonos dos dados
    List<List<LatLng>> polygons = [];
    if (ocorrencia.poligonos != null) {
      for (var poligonoData in ocorrencia.poligonos!) {
        if (poligonoData['geom'] != null && 
            poligonoData['geom']['coordinates'] != null) {
          final coords = poligonoData['geom']['coordinates'] as List;
          if (coords.isNotEmpty && coords.first is List) {
            final polygonCoords = coords.first as List;
            List<LatLng> polygonPoints = [];
            for (var coord in polygonCoords) {
              if (coord is List && coord.length >= 2) {
                polygonPoints.add(LatLng(coord[1], coord[0])); // GeoJSON: [lng, lat]
              }
            }
            if (polygonPoints.length >= 3) {
              polygons.add(polygonPoints);
            }
          }
        }
      }
    }

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
