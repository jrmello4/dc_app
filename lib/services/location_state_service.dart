// lib/services/location_state_service.dart

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  // Alias para clearAll para compatibilidade
  void clearLocationState() {
    clearAll();
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

}
