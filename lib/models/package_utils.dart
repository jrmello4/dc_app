// lib/models/package_utils.dart

import 'package:dc_app/config/api_config.dart';

// Classe com métodos estáticos para parsing e outras utilidades
class PackageUtils {
  /// Converte um valor dinâmico para int de forma segura.
  static int parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Converte uma string para DateTime de forma segura.
  static DateTime? parseDateTime(dynamic value) {
    if (value == null || value is! String) return null;
    return DateTime.tryParse(value);
  }

  /// Extrai um ID de um mapa (ex: { "id": 1, "nome": "..." }).
  static int? getIdFromJson(dynamic data) {
    if (data is Map) return parseInt(data['id'], defaultValue: -1);
    if (data is int) return data;
    return null;
  }

  /// Extrai um nome de um mapa.
  static String? getNameFromJson(dynamic data) {
    if (data is Map) return data['nome'] as String?;
    return null;
  }

  /// Constrói a URL completa para um recurso de mídia.
  static String buildFullUrl(String partialUrl) {
    // Se a URL já for completa (começa com http), apenas a retorna.
    if (partialUrl.startsWith('http')) {
      return partialUrl;
    }

    // Usa a 'baseMediaUrl' definida no api_config,
    // que já é a URL correta sem o sufixo '/api'.
    // Ex: https://ti.araquari.sc.gov.br
    return ApiConfig.baseMediaUrl + partialUrl;
  }
}