// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:logger/logger.dart';

class LocationService {
  static final _logger = Logger();

  /// Solicita permissão de localização
  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('Permissão de localização negada pelo usuário');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.e('Permissão de localização negada permanentemente');
        return false;
      }

      _logger.i('Permissão de localização concedida');
      return true;
    } catch (e) {
      _logger.e('Erro ao solicitar permissão de localização', error: e);
      return false;
    }
  }

  /// Obtém a localização atual
  static Future<Position?> getCurrentLocation() async {
    try {
      // Verifica se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Serviço de localização desabilitado');
        return null;
      }

      // Solicita permissão
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return null;
      }

      // Obtém a localização atual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _logger.i('Localização obtida: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      _logger.e('Erro ao obter localização atual', error: e);
      return null;
    }
  }

  /// Converte coordenadas em endereço
  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Monta o endereço de forma mais legível
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        String address = addressParts.join(', ');
        _logger.i('Endereço obtido: $address');
        return address;
      }
      
      _logger.w('Nenhum endereço encontrado para as coordenadas');
      return null;
    } catch (e) {
      _logger.e('Erro ao obter endereço das coordenadas', error: e);
      return null;
    }
  }

  /// Obtém localização atual com endereço
  static Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      Position? position = await getCurrentLocation();
      if (position == null) {
        return null;
      }

      String? address = await getAddressFromCoordinates(position.latitude, position.longitude);
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address ?? 'Endereço não disponível',
        'accuracy': position.accuracy,
        'timestamp': position.timestamp,
      };
    } catch (e) {
      _logger.e('Erro ao obter localização com endereço', error: e);
      return null;
    }
  }
}
