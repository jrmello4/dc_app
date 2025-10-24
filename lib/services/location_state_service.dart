// lib/services/location_state_service.dart

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/location_service.dart';

class LocationStateService extends ChangeNotifier {
  Position? _currentPosition;
  List<List<double>>? _drawnPolygon;
  bool _hasDrawnArea = false;
  bool _isGettingLocation = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  List<List<double>>? get drawnPolygon => _drawnPolygon;
  bool get hasDrawnArea => _hasDrawnArea;
  bool get isGettingLocation => _isGettingLocation;

  // Setters com notificação
  void setCurrentPosition(Position? position) {
    _currentPosition = position;
    notifyListeners();
  }

  void setDrawnPolygon(List<List<double>>? polygon) {
    _drawnPolygon = polygon;
    _hasDrawnArea = polygon != null && polygon.isNotEmpty;
    notifyListeners();
  }

  void setGettingLocation(bool isGetting) {
    _isGettingLocation = isGetting;
    notifyListeners();
  }

  // Métodos de conveniência
  void clearPolygon() {
    _drawnPolygon = null;
    _hasDrawnArea = false;
    notifyListeners();
  }

  void clearLocation() {
    _currentPosition = null;
    notifyListeners();
  }

  void clearAll() {
    _currentPosition = null;
    _drawnPolygon = null;
    _hasDrawnArea = false;
    _isGettingLocation = false;
    notifyListeners();
  }

  // Método para adicionar ponto ao polígono atual
  void addPointToPolygon(List<double> point) {
    if (_drawnPolygon == null) {
      _drawnPolygon = [];
    }
    _drawnPolygon!.add(point);
    _hasDrawnArea = true;
    notifyListeners();
  }

  // Método para remover último ponto do polígono
  void removeLastPoint() {
    if (_drawnPolygon != null && _drawnPolygon!.isNotEmpty) {
      _drawnPolygon!.removeLast();
      _hasDrawnArea = _drawnPolygon!.isNotEmpty;
      notifyListeners();
    }
  }

  // Método para verificar se há dados válidos
  bool get hasValidData => _currentPosition != null || _hasDrawnArea;

  // Método para obter dados formatados para envio
  Map<String, dynamic> getFormattedData() {
    return {
      'currentPosition': _currentPosition != null ? {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'accuracy': _currentPosition!.accuracy,
      } : null,
      'drawnPolygon': _drawnPolygon,
      'hasDrawnArea': _hasDrawnArea,
    };
  }

  // Método para obter localização atual
  Future<String> getCurrentLocation() async {
    setGettingLocation(true);
    
    try {
      // Solicita permissão de localização
      bool hasPermission = await LocationService.requestLocationPermission();
      if (!hasPermission) {
        return 'Permissão de localização negada.';
      }

      // Obtém a localização atual
      final locationData = await LocationService.getCurrentLocationOnly();
      
      if (locationData != null) {
        final position = Position(
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
        
        setCurrentPosition(position);
        return 'Localização obtida com sucesso.';
      } else {
        return 'Não foi possível obter a localização atual.';
      }
    } catch (e) {
      return 'Erro ao obter localização: $e';
    } finally {
      setGettingLocation(false);
    }
  }

  // Método para limpar todo o estado
  void clearLocationState() {
    clearAll();
  }
}
