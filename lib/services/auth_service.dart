// lib/services/auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/config/api_config.dart';
// Removido: import 'package:firebase_messaging/firebase_messaging.dart';

class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);
}

class AuthService extends ChangeNotifier {
  final Logger _logger = Logger();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // --- Estado de Autenticação ---
  String? _token;
  int? _userId;
  String? _userName;
  String? _userEmail;
  List<String>? _userGroups;

  // --- Getters Públicos (Não-Estáticos) ---
  // A UI usará estes getters através do Provider
  String? get token => _token;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  List<String>? get userGroups => _userGroups;
  bool get isAuthenticated => _token != null;

  // --- Métodos de Autenticação ---

  Future<void> _saveAuthData(String token, Map<String, dynamic> userData) async {
    _token = token;
    _userId = userData['user_id'];
    _userName = userData['username'];
    _userEmail = userData['email'];
    _userGroups = (userData['groups'] as List<dynamic>?)
        ?.map((group) => group as String)
        .toList();

    await _storage.write(key: 'auth_token', value: _token);
    await _storage.write(key: 'user_id', value: _userId.toString());
    await _storage.write(key: 'user_name', value: _userName);
    await _storage.write(key: 'user_email', value: _userEmail);
    await _storage.write(
        key: 'user_groups', value: jsonEncode(_userGroups ?? []));

    _logger.i('Dados de autenticação salvos com segurança.');
    notifyListeners(); // Notifica a UI que o estado mudou
  }

  Future<void> loadAuthData() async {
    try {
      _token = await _storage.read(key: 'auth_token');
      final userIdString = await _storage.read(key: 'user_id');
      _userName = await _storage.read(key: 'user_name');
      _userEmail = await _storage.read(key: 'user_email');
      final userGroupsString = await _storage.read(key: 'user_groups');

      if (_token != null && userIdString != null) {
        _userId = int.tryParse(userIdString);
        if (userGroupsString != null) {
          _userGroups = (jsonDecode(userGroupsString) as List<dynamic>)
              .map((group) => group as String)
              .toList();
        }

        // Validar token (ex: checar expiração)
        if (Jwt.isExpired(_token!)) {
          _logger.w('Token expirado. Limpando dados.');
          await clearAuthData(); // O clearAuthData já chama notifyListeners
          return;
        }

        _logger.i('Dados de autenticação carregados.');
      } else {
        _logger.i('Nenhum dado de autenticação encontrado.');
        _token = null;
      }
    } catch (e) {
      _logger.e('Erro ao carregar dados de autenticação', error: e);
      await clearAuthData(); // Limpa em caso de erro
      return;
    }
    notifyListeners(); // Notifica que o carregamento terminou
  }

  Future<void> clearAuthData() async {
    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userGroups = null;

    await _storage.deleteAll();
    _logger.i('Dados de autenticação limpos.');
    notifyListeners(); // Notifica a UI (logout)
  }

  Future<void> login(String username, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api-token-auth/');
    _logger.i('Tentando login para $username');

    try {
      // String? fcmToken = await FirebaseMessaging.instance.getToken();
      // _logger.i('FCM Token: $fcmToken');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          // 'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        final responseData =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final token = responseData['token'] as String?;
        final user = responseData['user'] as Map<String, dynamic>?;

        if (token != null && user != null) {
          await _saveAuthData(token, user);
          _logger.i('Login bem-sucedido para $username');
        } else {
          _logger.e('Resposta de login inválida: token ou usuário nulo.');
          throw AuthServiceException(
              'Resposta inválida do servidor. Tente novamente.');
        }
      } else if (response.statusCode == 400) {
        _logger.w('Falha no login (400): Credenciais inválidas');
        throw AuthServiceException('Usuário ou senha inválidos.');
      } else {
        _logger.e('Erro de servidor no login: ${response.statusCode}');
        throw AuthServiceException(
            'Erro no servidor (${response.statusCode}). Tente mais tarde.');
      }
    } on SocketException {
      _logger.e('Erro de conexão no login (SocketException)');
      throw AuthServiceException(
          'Não foi possível conectar ao servidor. Verifique sua internet.');
    } catch (e) {
      _logger.e('Erro desconhecido no login', error: e);
      // Re-lança se já for uma AuthServiceException
      if (e is AuthServiceException) rethrow;
      // Trata outros erros
      throw AuthServiceException('Ocorreu um erro inesperado: $e');
    }
  }

  Future<void> register(String username, String email, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/register/');
    _logger.i('Tentando registrar novo usuário: $username');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        _logger.i('Registro bem-sucedido para $username');
        // O backend deve retornar os dados do usuário e token aqui?
        // Se sim, chamar _saveAuthData
        // Se não, o usuário deve fazer login
      } else if (response.statusCode == 400) {
        final responseData =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // Tenta extrair a mensagem de erro da API
        String errorMessage = "Erro de validação.";
        if (responseData.containsKey('username')) {
          errorMessage = 'Usuário: ${responseData['username'][0]}';
        } else if (responseData.containsKey('email')) {
          errorMessage = 'Email: ${responseData['email'][0]}';
        } else if (responseData.containsKey('password')) {
          errorMessage = 'Senha: ${responseData['password'][0]}';
        }
        _logger.w('Falha no registro (400): $errorMessage');
        throw AuthServiceException(errorMessage);
      } else {
        _logger.e('Erro de servidor no registro: ${response.statusCode}');
        throw AuthServiceException(
            'Erro no servidor (${response.statusCode}). Tente mais tarde.');
      }
    } on SocketException {
      _logger.e('Erro de conexão no registro');
      throw AuthServiceException(
          'Não foi possível conectar ao servidor. Verifique sua internet.');
    } catch (e) {
      _logger.e('Erro desconhecido no registro', error: e);
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Ocorreu um erro inesperado: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/reset-password/');
    _logger.i('Solicitando redefinição de senha para: $email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        _logger.i('Solicitação de redefinição de senha enviada para $email');
      } else if (response.statusCode == 404) {
        _logger.w('Email não encontrado para redefinição: $email');
        throw AuthServiceException('Nenhum usuário encontrado com este email.');
      } else {
        _logger.e(
            'Erro do servidor ao redefinir senha: ${response.statusCode}');
        throw AuthServiceException(
            'Erro no servidor (${response.statusCode}). Tente mais tarde.');
      }
    } on SocketException {
      _logger.e('Erro de conexão ao redefinir senha');
      throw AuthServiceException(
          'Não foi possível conectar ao servidor. Verifique sua internet.');
    } catch (e) {
      _logger.e('Erro desconhecido ao redefinir senha', error: e);
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Ocorreu um erro inesperado: $e');
    }
  }

  Future<void> confirmResetPassword(
      String token, String newPassword, String uidb64) async {
    final url =
    Uri.parse('${ApiConfig.baseUrl}/reset-password/confirm/$uidb64/$token/');
    _logger.i('Confirmando redefinição de senha para UID: $uidb64');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'new_password': newPassword}),
      );

      if (response.statusCode == 200) {
        _logger.i('Senha redefinida com sucesso para UID: $uidb64');
      } else {
        final responseData =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        String errorMsg =
            responseData['error'] ?? 'Token inválido ou expirado.';
        _logger.w('Falha ao confirmar redefinição: $errorMsg');
        throw AuthServiceException(errorMsg);
      }
    } on SocketException {
      _logger.e('Erro de conexão ao confirmar redefinição');
      throw AuthServiceException(
          'Não foi possível conectar ao servidor. Verifique sua internet.');
    } catch (e) {
      _logger.e('Erro desconhecido ao confirmar redefinição', error: e);
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Ocorreu um erro inesperado: $e');
    }
  }
}