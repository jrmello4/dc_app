// lib/services/ocorrencia_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dc_app/config/api_config.dart';
import 'package:dc_app/models/ocorrencia.dart';
import 'package:dc_app/models/mensagem.dart';
import 'package:dc_app/models/avaliacao.dart';
import 'package:logger/logger.dart';

// Exceção customizada
class OcorrenciaException implements Exception {
  final String message;
  final int? statusCode;
  OcorrenciaException(this.message, {this.statusCode});

  @override
  String toString() =>
      'OcorrenciaException: $message (Status: $statusCode)';
}

// Classe para agrupar os dados
class OcorrenciaCreationData {
  final List<String> prioridades;
  final List<String> tipos;
  final List<String> setores;

  OcorrenciaCreationData(
      {required this.prioridades,
        required this.tipos,
        required this.setores});
}

class OcorrenciaService {
  static final Logger _logger = Logger();

  // Helper para decodificar resposta
  static dynamic _decodeResponse(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      _logger.e('Erro ao decodificar JSON: ${response.body}', error: e);
      throw OcorrenciaException('Resposta inválida do servidor (JSON malformado).',
          statusCode: response.statusCode);
    }
  }

  // --- MÉTODOS DE DADOS PARA CRIAÇÃO ---

  static Future<OcorrenciaCreationData> getCreationData(String token, int userId) async {
    _logger.i('Buscando dados de criação para o usuário $userId...');

    // Header de autenticação
    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};

    try {
      final prioridadesData = await _fetchPrioridades('${ApiConfig.baseUrl}/prioridade/list/', headers);
      final tiposData = await _fetchTipos('${ApiConfig.baseUrl}/tipo/list/', headers);
      // Passa o userId para buscar setores
      final setoresData = await _fetchSetores('${ApiConfig.baseUrl}/setor/list/?usuario_id=$userId', headers);

      return OcorrenciaCreationData(
        prioridades: prioridadesData,
        tipos: tiposData,
        setores: setoresData,
      );
    } catch (e) {
      _logger.e('Falha ao buscar dados de criação.', error: e);
      // Lança a exceção para a UI tratar (ex: exibir erro)
      throw OcorrenciaException(
          'Falha ao carregar dados. Verifique sua conexão e tente novamente. ($e)');
    }
  }

  // Métodos de mock (mantidos como privados, mas não devem ser usados em caso de falha)
  static OcorrenciaCreationData _getMockCreationData() {
    _logger.w('Usando dados MOCK para criação de ocorrência.');
    return OcorrenciaCreationData(
      prioridades: ['Baixa', 'Média', 'Alta', 'Urgente'],
      tipos: ['Alagamento', 'Deslizamento', 'Incêndio', 'Outro'],
      setores: ['Centro', 'Zona Norte', 'Zona Sul', 'Zona Leste', 'Zona Oeste'],
    );
  }

  static Future<List<String>> _fetchPrioridades(String url, Map<String, String> headers) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> data = _decodeResponse(response);
      return data.map((item) => item['nome'] as String).toList();
    }
    throw OcorrenciaException('Falha ao buscar prioridades.', statusCode: response.statusCode);
  }

  static Future<List<String>> _fetchTipos(String url, Map<String, String> headers) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> data = _decodeResponse(response);
      return data.map((item) => item['nome'] as String).toList();
    }
    throw OcorrenciaException('Falha ao buscar tipos.', statusCode: response.statusCode);
  }

  static Future<List<String>> _fetchSetores(String url, Map<String, String> headers) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> data = _decodeResponse(response);
      return data.map((item) => item['nome'] as String).toList();
    }
    throw OcorrenciaException('Falha ao buscar setores.', statusCode: response.statusCode);
  }

  // --- MÉTODOS DE OCORRÊNCIA ---

  static Future<void> createOcorrencia(
      String token,
      int userId, {
        required String assunto,
        required String prioridade,
        required String tipo,
        required String setor,
        required String descricao,
        double? latitude,
        double? longitude,
        List<List<double>>? poligono,
      }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/create/');
    _logger.i('Registrando nova ocorrência...');

    final headers = {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    final body = {
      'usuario': userId, // Passa o userId
      'assunto': assunto,
      'prioridade': prioridade,
      'tipo': tipo,
      'setor': setor,
      'descricao': descricao,
      'latitude': latitude,
      'longitude': longitude,
      'poligono': poligono,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        _logger.i('Ocorrência registrada com sucesso.');
        // print('Resposta: ${response.body}');
      } else {
        _logger.e('Falha ao registrar ocorrência: ${response.statusCode}', error: response.body);
        // print('Erro: ${response.body}');
        throw OcorrenciaException(
            'Falha ao registrar ocorrência. (${response.statusCode})',
            statusCode: response.statusCode);
      }
    } on SocketException {
      _logger.e('Erro de conexão (SocketException) ao criar ocorrência.');
      throw OcorrenciaException('Erro de conexão. Verifique sua internet.');
    } catch (e) {
      _logger.e('Erro desconhecido ao criar ocorrência', error: e);
      if (e is OcorrenciaException) rethrow;
      throw OcorrenciaException('Erro inesperado: $e');
    }
  }

  static Future<void> uploadFile(
      String token, {
        required int ocorrenciaId,
        required File file,
      }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/$ocorrenciaId/upload/');
    _logger.i('Enviando anexo para ocorrência $ocorrenciaId...');

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Token $token';
      request.files.add(await http.MultipartFile.fromPath('anexo', file.path));

      var response = await request.send();

      if (response.statusCode == 201) {
        _logger.i('Anexo enviado com sucesso.');
      } else {
        _logger.e('Falha ao enviar anexo: ${response.statusCode}');
        throw OcorrenciaException('Falha ao enviar anexo.',
            statusCode: response.statusCode);
      }
    } on SocketException {
      _logger.e('Erro de conexão (SocketException) ao enviar anexo.');
      throw OcorrenciaException('Erro de conexão. Verifique sua internet.');
    } catch (e) {
      _logger.e('Erro desconhecido ao enviar anexo', error: e);
      if (e is OcorrenciaException) rethrow;
      throw OcorrenciaException('Erro inesperado: $e');
    }
  }

  static Future<List<Ocorrencia>> getOcorrenciasByStatus(String token, String status) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/list/?status=$status');
    _logger.i('Buscando ocorrências com status: $status');

    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = _decodeResponse(response);
        return data.map((item) => Ocorrencia.fromJson(item)).toList();
      } else {
        _logger.e('Falha ao buscar ocorrências ($status): ${response.statusCode}');
        throw OcorrenciaException('Falha ao buscar ocorrências.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao buscar ocorrências ($status)', error: e);
      return []; // Retorna lista vazia em caso de falha
    }
  }

  static Future<List<Ocorrencia>> getAssignedOcorrencias(String token, int userId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/assigned/$userId/');
    _logger.i('Buscando ocorrências atribuídas ao usuário: $userId');

    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = _decodeResponse(response);
        return data.map((item) => Ocorrencia.fromJson(item)).toList();
      } else {
        _logger.e('Falha ao buscar ocorrências atribuídas: ${response.statusCode}');
        throw OcorrenciaException('Falha ao buscar ocorrências atribuídas.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao buscar ocorrências atribuídas', error: e);
      return []; // Retorna lista vazia em caso de falha
    }
  }

  static Future<Ocorrencia> getOcorrenciaDetails(String token, int id) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/detail/$id/');
    _logger.i('Buscando detalhes da ocorrência: $id');

    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        dynamic data = _decodeResponse(response);
        return Ocorrencia.fromJson(data);
      } else {
        _logger.e('Falha ao buscar detalhes: ${response.statusCode}');
        throw OcorrenciaException('Falha ao buscar detalhes.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao buscar detalhes da ocorrência', error: e);
      throw OcorrenciaException('Erro ao carregar dados da ocorrência: $e');
    }
  }

  static Future<List<Mensagem>> getMessages(String token, int ocorrenciaId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/$ocorrenciaId/messages/');
    _logger.i('Buscando mensagens para ocorrência: $ocorrenciaId');

    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = _decodeResponse(response);
        return data.map((item) => Mensagem.fromJson(item)).toList();
      } else {
        _logger.e('Falha ao buscar mensagens: ${response.statusCode}');
        throw OcorrenciaException('Falha ao buscar mensagens.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao buscar mensagens', error: e);
      throw OcorrenciaException('Erro ao carregar mensagens: $e');
    }
  }

  static Future<void> postMessage(String token, int ocorrenciaId, String mensagem) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/$ocorrenciaId/messages/post/');
    _logger.i('Postando mensagem para ocorrência: $ocorrenciaId');

    final headers = {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'mensagem': mensagem}),
      );

      if (response.statusCode != 201) {
        _logger.e('Falha ao postar mensagem: ${response.statusCode}');
        throw OcorrenciaException('Falha ao enviar mensagem.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao postar mensagem', error: e);
      throw OcorrenciaException('Erro ao enviar mensagem: $e');
    }
  }

  static Future<List<Avaliacao>> getRatings(String token, int ocorrenciaId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/$ocorrenciaId/ratings/');
    _logger.i('Buscando avaliações para ocorrência: $ocorrenciaId');

    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = _decodeResponse(response);
        return data.map((item) => Avaliacao.fromJson(item)).toList();
      } else {
        _logger.e('Falha ao buscar avaliações: ${response.statusCode}');
        throw OcorrenciaException('Falha ao buscar avaliações.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao buscar avaliações', error: e);
      throw OcorrenciaException('Erro ao carregar avaliações: $e');
    }
  }

  static Future<void> postRating(
      String token, {
        required int ocorrenciaId,
        required int nota,
        required String comentario,
      }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/$ocorrenciaId/ratings/post/');
    _logger.i('Postando avaliação para ocorrência: $ocorrenciaId');

    final headers = {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'nota': nota, 'comentario': comentario}),
      );

      if (response.statusCode != 201) {
        _logger.e('Falha ao postar avaliação: ${response.statusCode}');
        throw OcorrenciaException('Falha ao enviar avaliação.', statusCode: response.statusCode);
      }
    } catch (e) {
      _logger.e('Erro ao postar avaliação', error: e);
      throw OcorrenciaException('Erro ao enviar avaliação: $e');
    }
  }
}