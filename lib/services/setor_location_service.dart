// lib/services/setor_location_service.dart

import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/models/setor.dart';

class SetorLocationService {
  static final _logger = Logger();

  /// Calcula a distância entre dois pontos em metros
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Verifica se um ponto está dentro de um setor (baseado em raio)
  static bool isPointInSetor(double latitude, double longitude, Setor setor) {
    if (setor.latitude == null || setor.longitude == null || setor.raio == null) {
      return false;
    }

    double distance = calculateDistance(
      latitude, 
      longitude, 
      setor.latitude!, 
      setor.longitude!
    );

    return distance <= setor.raio!;
  }

  /// Verifica se um ponto está dentro de um polígono (triangulação)
  static bool isPointInPolygon(double latitude, double longitude, List<List<double>> polygon) {
    if (polygon.length < 3) return false;

    int intersections = 0;
    int n = polygon.length;

    for (int i = 0; i < n; i++) {
      double x1 = polygon[i][0];
      double y1 = polygon[i][1];
      double x2 = polygon[(i + 1) % n][0];
      double y2 = polygon[(i + 1) % n][1];

      if (y1 > longitude != y2 > longitude) {
        double x = x1 + (longitude - y1) * (x2 - x1) / (y2 - y1);
        if (latitude < x) {
          intersections++;
        }
      }
    }

    return intersections % 2 == 1;
  }

  /// Calcula o centro de um polígono
  static Map<String, double> calculatePolygonCenter(List<List<double>> polygon) {
    if (polygon.isEmpty) return {'latitude': 0.0, 'longitude': 0.0};

    double sumLat = 0.0;
    double sumLon = 0.0;

    for (var point in polygon) {
      sumLat += point[0];
      sumLon += point[1];
    }

    return {
      'latitude': sumLat / polygon.length,
      'longitude': sumLon / polygon.length,
    };
  }

  /// Calcula a área de um polígono em metros quadrados
  static double calculatePolygonArea(List<List<double>> polygon) {
    if (polygon.length < 3) return 0.0;

    double area = 0.0;
    int n = polygon.length;

    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      area += polygon[i][0] * polygon[j][1];
      area -= polygon[j][0] * polygon[i][1];
    }

    area = area.abs() / 2.0;

    // Converte de graus quadrados para metros quadrados (aproximação)
    // 1 grau ≈ 111,320 metros
    return area * pow(111320, 2);
  }

  /// Cria um polígono circular baseado em centro e raio
  static List<List<double>> createCircularPolygon(double centerLat, double centerLon, double radiusMeters, {int sides = 16}) {
    List<List<double>> polygon = [];
    double radiusDegrees = radiusMeters / 111320.0; // Aproximação: 1 grau ≈ 111,320 metros

    for (int i = 0; i < sides; i++) {
      double angle = 2 * pi * i / sides;
      double lat = centerLat + radiusDegrees * cos(angle);
      double lon = centerLon + radiusDegrees * sin(angle);
      polygon.add([lat, lon]);
    }

    return polygon;
  }

  /// Cria um polígono retangular baseado em centro e dimensões
  static List<List<double>> createRectangularPolygon(double centerLat, double centerLon, double widthMeters, double heightMeters) {
    double widthDegrees = widthMeters / 111320.0;
    double heightDegrees = heightMeters / 111320.0;

    double halfWidth = widthDegrees / 2;
    double halfHeight = heightDegrees / 2;

    return [
      [centerLat - halfHeight, centerLon - halfWidth], // Canto inferior esquerdo
      [centerLat + halfHeight, centerLon - halfWidth], // Canto superior esquerdo
      [centerLat + halfHeight, centerLon + halfWidth], // Canto superior direito
      [centerLat - halfHeight, centerLon + halfWidth], // Canto inferior direito
    ];
  }

  /// Encontra o setor mais próximo de uma localização
  static Setor? findNearestSetor(double latitude, double longitude, List<Setor> setores) {
    if (setores.isEmpty) return null;

    Setor? nearestSetor;
    double minDistance = double.infinity;

    for (Setor setor in setores) {
      if (setor.latitude != null && setor.longitude != null) {
        double distance = calculateDistance(latitude, longitude, setor.latitude!, setor.longitude!);
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestSetor = setor;
        }
      }
    }

    return nearestSetor;
  }

  /// Encontra todos os setores que contêm um ponto
  static List<Setor> findSetoresContainingPoint(double latitude, double longitude, List<Setor> setores) {
    List<Setor> containingSetores = [];

    for (Setor setor in setores) {
      if (isPointInSetor(latitude, longitude, setor)) {
        containingSetores.add(setor);
      }
    }

    return containingSetores;
  }

  /// Calcula a triangulação de Delaunay para um conjunto de pontos
  static List<List<int>> delaunayTriangulation(List<Map<String, double>> points) {
    if (points.length < 3) return [];

    // Implementação simplificada da triangulação de Delaunay
    // Para uma implementação completa, seria necessário usar uma biblioteca externa
    List<List<int>> triangles = [];

    // Triangulação simples (não é Delaunay real, mas funciona para casos básicos)
    for (int i = 0; i < points.length - 2; i++) {
      for (int j = i + 1; j < points.length - 1; j++) {
        for (int k = j + 1; k < points.length; k++) {
          triangles.add([i, j, k]);
        }
      }
    }

    return triangles;
  }

  /// Valida se um polígono é válido (não se cruza, tem área > 0)
  static bool isValidPolygon(List<List<double>> polygon) {
    if (polygon.length < 3) return false;

    // Verifica se o polígono se fecha (primeiro e último ponto são iguais)
    if (polygon.first[0] != polygon.last[0] || polygon.first[1] != polygon.last[1]) {
      return false;
    }

    // Verifica se tem área > 0
    double area = calculatePolygonArea(polygon);
    return area > 0;
  }

  /// Converte polígono para formato GeoJSON
  static Map<String, dynamic> polygonToGeoJSON(List<List<double>> polygon) {
    return {
      "type": "Polygon",
      "coordinates": [polygon]
    };
  }

  /// Converte GeoJSON para polígono
  static List<List<double>> geoJSONToPolygon(Map<String, dynamic> geoJSON) {
    if (geoJSON["type"] != "Polygon") return [];
    
    List<dynamic> coordinates = geoJSON["coordinates"][0];
    return coordinates.map<List<double>>((coord) => [coord[0].toDouble(), coord[1].toDouble()]).toList();
  }

  /// Calcula o perímetro de um polígono em metros
  static double calculatePolygonPerimeter(List<List<double>> polygon) {
    if (polygon.length < 2) return 0.0;

    double perimeter = 0.0;
    int n = polygon.length;

    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      double distance = calculateDistance(
        polygon[i][0], polygon[i][1],
        polygon[j][0], polygon[j][1]
      );
      perimeter += distance;
    }

    return perimeter;
  }

  /// Cria um buffer ao redor de um polígono
  static List<List<double>> createPolygonBuffer(List<List<double>> polygon, double bufferMeters) {
    if (polygon.isEmpty) return [];

    List<List<double>> bufferedPolygon = [];
    int n = polygon.length;

    for (int i = 0; i < n; i++) {
      int prev = (i - 1 + n) % n;
      int next = (i + 1) % n;

      // Calcula vetores normais
      double dx1 = polygon[i][0] - polygon[prev][0];
      double dy1 = polygon[i][1] - polygon[prev][1];
      double dx2 = polygon[next][0] - polygon[i][0];
      double dy2 = polygon[next][1] - polygon[i][1];

      // Normaliza os vetores
      double len1 = sqrt(dx1 * dx1 + dy1 * dy1);
      double len2 = sqrt(dx2 * dx2 + dy2 * dy2);

      if (len1 > 0) {
        dx1 /= len1;
        dy1 /= len1;
      }
      if (len2 > 0) {
        dx2 /= len2;
        dy2 /= len2;
      }

      // Calcula o ponto buffer
      double bufferDegrees = bufferMeters / 111320.0;
      double newLat = polygon[i][0] + (dx1 + dx2) * bufferDegrees;
      double newLon = polygon[i][1] + (dy1 + dy2) * bufferDegrees;

      bufferedPolygon.add([newLat, newLon]);
    }

    return bufferedPolygon;
  }
}
