// lib/services/cache_service.dart

import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final _logger = Logger();
  // Define por quanto tempo o cache é considerado válido (em minutos)
  // Nota: Esta duração pode não ser relevante dependendo de como você usa o cache.
  static const int _cacheDurationInMinutes = 5;

  // Salva os dados em cache como uma string JSON.
  static Future<void> saveData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(data);
      await prefs.setString(key, jsonString);

      // Salva o timestamp de quando o cache foi salvo
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('${key}_timestamp', timestamp);

      _logger.i('Dados salvos no cache com a chave: $key');
    } catch (e) {
      _logger.e('Erro ao salvar dados no cache para a chave: $key', error: e);
    }
  }

  // Carrega os dados do cache (decodifica JSON), se forem válidos (não expirados).
  static Future<dynamic> loadData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? timestamp = prefs.getInt('${key}_timestamp');

      // Verifica se o cache existe e se não expirou
      if (timestamp != null) {
        final now = DateTime.now();
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final difference = now.difference(cacheTime);

        if (difference.inMinutes < _cacheDurationInMinutes) {
          final String? jsonString = prefs.getString(key);
          if (jsonString != null) {
            _logger.i('Dados carregados do cache com a chave: $key');
            return json.decode(jsonString);
          }
        } else {
          _logger.i('Cache expirado para a chave: $key. Removendo...');
          await invalidateCache(key); // Limpa o cache expirado
        }
      }
    } catch (e) {
      _logger.e('Erro ao carregar dados do cache para a chave: $key', error: e);
    }
    _logger.i('Nenhum cache válido encontrado para a chave: $key');
    return null; // Retorna nulo se não houver cache válido
  }

  // Invalida (limpa) um cache específico (chave e timestamp).
  static Future<void> invalidateCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      await prefs.remove('${key}_timestamp');
      _logger.i('Cache invalidado para a chave: $key');
    } catch (e) {
      _logger.e('Erro ao invalidar cache para a chave: $key', error: e);
    }
  }

  // Métodos adicionais do seu código original (saveString, getString, etc.)
  // que podem ser úteis para salvar dados simples diretamente.

  static Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}