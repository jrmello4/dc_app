// lib/services/auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:dc_app/config/api_config.dart'; // Import corrigido
// import 'package:dc_app/services/notification_service.dart'; // COMENTADO - depende do Firebase

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  final _logger = Logger();
  
  // Instância singleton para métodos estáticos
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _tokenKey = 'authToken';
  static const _userIdKey = 'authUserId';
  static const _userNameKey = 'authNomeUsuario';
  static const _isTecnicoKey = 'isTecnico';
  static const _userPhotoUrlKey = 'userPhotoUrl';

  String? _token;
  int? _userId;
  String? _nomeUsuario;
  bool _isTecnico = false;
  String? _photoUrl;

  // COMENTADO: Instância do NotificationService para enviar o token FCM
  // final NotificationService _notificationService = NotificationService();

  String? get token => _token;
  int? get userId => _userId;
  String? get nomeUsuario => _nomeUsuario;
  bool get isTecnico => _isTecnico;
  String? get photoUrl => _photoUrl;
  
  bool get isAuthenticated => _token != null;

  // Métodos estáticos para compatibilidade com serviços
  static String? get token => _instance._token;
  static int? get userId => _instance._userId;
  static String? get nomeUsuario => _instance._nomeUsuario;
  static bool get isTecnico => _instance._isTecnico;
  static String? get photoUrl => _instance._photoUrl;
  static bool get isAuthenticated => _instance._token != null;

  // Função auxiliar para construir URL completa da foto
  String? _buildFullPhotoUrl(String? partialUrl) {
    if (partialUrl == null || partialUrl.isEmpty) return null;
    if (partialUrl.startsWith('http')) return partialUrl;
    // Usa a baseMediaUrl que não tem /api no final
    return ApiConfig.baseMediaUrl + partialUrl;
  }

  Future<void> _saveAuthData(String token, int userId, String nomeUsuario, bool isTecnico, String? photoUrl) async {
    _token = token;
    _userId = userId;
    _nomeUsuario = nomeUsuario;
    _isTecnico = isTecnico;
    _photoUrl = _buildFullPhotoUrl(photoUrl); // Constrói a URL completa

    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(key: _userIdKey, value: _userId.toString());
    await _storage.write(key: _userNameKey, value: _nomeUsuario);
    await _storage.write(key: _isTecnicoKey, value: _isTecnico.toString());
    if (_photoUrl != null) {
      await _storage.write(key: _userPhotoUrlKey, value: _photoUrl);
    } else {
      await _storage.delete(key: _userPhotoUrlKey);
    }
    
    notifyListeners(); // Notifica os listeners sobre a mudança
  }

  Future<void> loadAuthData() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      final userIdStr = await _storage.read(key: _userIdKey);
      _userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      _nomeUsuario = await _storage.read(key: _userNameKey);
      final isTecnicoStr = await _storage.read(key: _isTecnicoKey);
      _isTecnico = isTecnicoStr == 'true';
      _photoUrl = await _storage.read(key: _userPhotoUrlKey);
      
      notifyListeners(); // Notifica os listeners sobre a mudança
    } catch (e) {
      _logger.e('Falha ao carregar dados de autenticação', error: e);
      await clearAuthData(); // Limpa dados corrompidos
    }
  }

  Future<void> clearAuthData() async {
    await _storage.deleteAll();
    _token = null;
    _userId = null;
    _nomeUsuario = null;
    _isTecnico = false;
    _photoUrl = null;
    
    notifyListeners(); // Notifica os listeners sobre a mudança
  }

  Future<void> login(String username, String password) async {
    // Lógica original da API (sem mock)
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/login/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      await _saveAuthData(
        responseData['token'],
        responseData['usuario']['id'],
        "${responseData['usuario']['first_name']} ${responseData['usuario']['last_name']}".trim(),
        (responseData['usuario']['groups'] as List).any((g) => g == 'Tecnico'),
        responseData['usuario']['foto_url'],
      );

      // COMENTADO: Envia o token FCM após o login bem-sucedido
      // try {
      //   final fcmToken = await _notificationService.getFCMToken();
      //   if (fcmToken != null) {
      //     await _notificationService.sendTokenToServer(fcmToken);
      //   } else {
      //     _logger.w("Não foi possível obter o token FCM para enviar ao backend após login.");
      //   }
      // } catch (e) {
      //   _logger.e("Falha ao obter ou enviar o token FCM após o login.", error: e);
      // }

    } else {
      // Tenta decodificar mensagem de erro da API
      String errorMessage = 'Credenciais inválidas.';
      try {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData.containsKey('detail')) {
          errorMessage = errorData['detail'];
        } else if (errorData is Map && errorData.isNotEmpty) {
          errorMessage = errorData.values.first.toString();
        }
      } catch (e) {
        _logger.w("Não foi possível decodificar a resposta de erro da API de login.");
      }
      throw AuthException(errorMessage);
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    // Lógica original da API (sem mock)
    final url = Uri.parse('${ApiConfig.baseUrl}/usuario/add/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({
        'first_name': firstName,
        'last_name': lastName,
        'username': email, // Assumindo que username é o email
        'email': email,
        'telefone': phone, // Campo telefone adicionado
        'password': password,
      }),
    );
    if (response.statusCode >= 300) {
      String errorMessage = 'Falha no cadastro.';
      try {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        // Tenta extrair a primeira mensagem de erro mais específica
        if (errorData is Map && errorData.isNotEmpty) {
          var firstErrorValue = errorData.values.first;
          if (firstErrorValue is List && firstErrorValue.isNotEmpty) {
            errorMessage = firstErrorValue.first;
          } else {
            errorMessage = firstErrorValue.toString();
          }
        }
      } catch (e) {
        _logger.w("Não foi possível decodificar a resposta de erro da API de registro.");
      }
      throw AuthException('$errorMessage (código: ${response.statusCode})');
    }
  }

  Future<bool> validateToken() async {
    // Lógica original da API (sem mock)
    if (_token == null) await loadAuthData();
    if (_token == null) return false;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/user/'), headers: {'Authorization': 'Token $_token'});
      return response.statusCode == 200;
    } catch (e) {
      _logger.e("Erro ao validar token", error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    // Lógica original da API (sem mock)
    if (_token == null) {
      await loadAuthData(); // Tenta carregar se não estiver na memória
      if (_token == null) throw AuthException('Usuário não autenticado.');
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/usuario/visualizar/');
    final response = await http.get(url, headers: {'Authorization': 'Token $_token'});
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      _logger.e("Falha ao carregar perfil. Status: ${response.statusCode}");
      // Se o token for inválido, limpa os dados locais
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearAuthData();
        throw AuthException('Sessão inválida ou expirada. Faça login novamente.');
      }
      throw Exception('Não foi possível carregar os dados do perfil.');
    }
  }

  Future<void> updateProfile({required Map<String, String> data, File? image}) async {
    // Lógica original da API (sem mock)
    if (_token == null) throw AuthException('Usuário não autenticado.');

    // Endpoint baseado no código original
    final url = Uri.parse('${ApiConfig.baseUrl}/usuario/alterar/');
    var request = http.MultipartRequest('PATCH', url); // Usando PATCH conforme original

    request.headers['Authorization'] = 'Token $_token';

    _logger.i("Preparando para atualizar perfil com dados: $data");
    request.fields.addAll(data);

    if (image != null) {
      const fieldName = 'imagem'; // Campo de imagem baseado no original
      _logger.i("-> Enviando arquivo de imagem no campo '$fieldName': ${image.path}");
      request.files.add(await http.MultipartFile.fromPath(fieldName, image.path));
    } else {
      _logger.i("-> Nenhuma nova imagem de perfil para enviar.");
    }

    _logger.i("Enviando requisição PATCH para: $url");

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      _logger.i("Perfil atualizado com sucesso! Status: ${response.statusCode}");
      // Recarrega os dados do usuário para atualizar nome/foto na memória
      try {
        final profileData = json.decode(responseBody);
        await _saveAuthData(
            _token!, // Token não muda
            profileData['id'],
            "${profileData['first_name']} ${profileData['last_name']}".trim(),
            _isTecnico, // Permissão não muda aqui
            profileData['foto_url']
        );
      } catch(e) {
        _logger.e("Erro ao processar resposta de atualização de perfil.", error: e);
        // Mesmo com erro no processamento, a API confirmou sucesso.
      }
    } else {
      _logger.e('Falha ao atualizar perfil. Status: ${response.statusCode}', error: responseBody);
      throw Exception('Falha ao atualizar o perfil.');
    }
  }

  Future<void> requestPasswordReset(String email) async {
    // Lógica original da API (sem mock)
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/usuario/password/reset/'), // Endpoint do código original
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({'email': email}),
    );

    // A API original pode retornar 200 ou 204 para sucesso
    if (response.statusCode != 200 && response.statusCode != 204) {
      String errorMessage = 'Não foi possível processar sua solicitação.';
      try {
        final responseData = json.decode(response.body);
        if (responseData is Map && responseData.containsKey('detail')) {
          errorMessage = responseData['detail'];
        } else if (responseData is Map && responseData.containsKey('email')) {
          errorMessage = responseData['email'] is List ? responseData['email'].join(', ') : responseData['email'].toString();
        } else if (response.body.isNotEmpty) {
          errorMessage = response.body;
        }
      } catch (e) {
        // Mantém a mensagem padrão
      }
      _logger.e("Falha ao solicitar reset de senha. Status: ${response.statusCode}");
      throw Exception('Erro: $errorMessage (Cód: ${response.statusCode})');
    }
  }

  Future<void> resetPassword(String uidb64, String token, String newPassword1, String newPassword2) async {
    // Lógica original da API (sem mock)
    final apiUrl = Uri.parse('${ApiConfig.baseUrl}/usuario/reset/$uidb64/$token/'); // Endpoint do código original
    final response = await http.post(
      apiUrl,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({
        'new_password1': newPassword1,
        'new_password2': newPassword2,
        'uidb64': uidb64, // Incluindo uidb64 e token no corpo também, como no original
        'token': token,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      String errorMessage = 'Não foi possível redefinir a senha.';
      try {
        final responseBody = json.decode(response.body);
        if (responseBody is Map) {
          if (responseBody.containsKey('new_password2')) {
            errorMessage = responseBody['new_password2'] is List ? responseBody['new_password2'].join('\n') : responseBody['new_password2'].toString();
          } else if (responseBody.containsKey('detail')) {
            errorMessage = responseBody['detail'];
          } else if (responseBody.isNotEmpty) {
            // Tenta pegar o primeiro erro da lista
            var firstError = responseBody.entries.firstWhere((entry) => entry.value is List && (entry.value as List).isNotEmpty, orElse: () => const MapEntry("", ["Erro desconhecido."]));
            errorMessage = (firstError.value as List).first;
          }
        } else if (responseBody is String && responseBody.isNotEmpty) {
          errorMessage = responseBody;
        }
      } catch(e) {
        // Mantém mensagem padrão
      }
      _logger.e("Falha ao redefinir senha. Status: ${response.statusCode}");
      throw Exception('Erro: $errorMessage (Cód: ${response.statusCode})');
    }
  }
}