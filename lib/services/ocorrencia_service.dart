// lib/services/ocorrencia_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:dc_app/config/api_config.dart';
import 'package:dc_app/services/auth_service.dart';
import 'package:dc_app/models/ocorrencia.dart';
import 'package:dc_app/models/mensagem.dart';
import 'package:dc_app/models/avaliacao.dart';
import 'package:dc_app/models/setor.dart'; // Importa o novo modelo Setor

class DropdownItem {
  final int id;
  final String nome;
  DropdownItem({required this.id, required this.nome});
  @override
  bool operator ==(Object other) => identical(this, other) || other is DropdownItem && runtimeType == other.runtimeType && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

class OcorrenciaCreationData {
  final List<DropdownItem> prioridades;
  final List<DropdownItem> tiposOcorrencia;
  final List<Setor> setores; // Alterado para usar o modelo Setor
  final int? setorUsuarioId;
  OcorrenciaCreationData({required this.prioridades, required this.tiposOcorrencia, required this.setores, this.setorUsuarioId});
}

class OcorrenciaException implements Exception {
  final String message;
  OcorrenciaException(this.message);
  @override
  String toString() => message;
}

class OcorrenciaService {
  static final _logger = Logger(printer: PrettyPrinter(methodCount: 1));

  static Future<OcorrenciaCreationData> getCreationData() async {
    final token = AuthService.token;
    final userId = AuthService.userId;
    if (token == null || userId == null) throw AuthException('Sessão expirada.');
    final headers = {'Authorization': 'Token $token', 'Accept': 'application/json'};
    
    _logger.i("Iniciando busca de dados para criação de ocorrência");
    
    try {
      final prioridades = await _fetchGenericDropdownItems('${ApiConfig.baseUrl}/prioridade/list/', headers);
      final tiposOcorrencia = await _fetchGenericDropdownItems('${ApiConfig.baseUrl}/tipochamado/list/', headers);
      final setoresData = await _fetchSetores('${ApiConfig.baseUrl}/setor/list/?usuario_id=$userId', headers);
      
      return OcorrenciaCreationData(
        prioridades: prioridades,
        tiposOcorrencia: tiposOcorrencia,
        setores: setoresData['setores'] as List<Setor>, // Alterado para List<Setor>
        setorUsuarioId: setoresData['setor_usuario_id'] as int?,
      );
    } catch (e) {
      _logger.e("Erro ao buscar dados de criação", error: e);
      return _getMockCreationData();
    }
  }

  static OcorrenciaCreationData _getMockCreationData() {
    return OcorrenciaCreationData(
      prioridades: [
        DropdownItem(id: 1, nome: 'Baixa'),
        DropdownItem(id: 2, nome: 'Média'),
        DropdownItem(id: 3, nome: 'Alta'),
      ],
      tiposOcorrencia: [
        DropdownItem(id: 1, nome: 'Alagamento'),
        DropdownItem(id: 2, nome: 'Deslizamento'),
        DropdownItem(id: 3, nome: 'Incêndio'),
      ],
      setores: [
        Setor(id: 1, nome: 'Centro', latitude: -23.5505, longitude: -46.6333, raio: 500),
        Setor(id: 2, nome: 'Zona Norte', latitude: -23.496, longitude: -46.627, raio: 1000),
        Setor(id: 3, nome: 'Zona Sul', latitude: -23.682, longitude: -46.699, raio: 1500),
      ],
      setorUsuarioId: 1,
    );
  }

  static Future<List<DropdownItem>> _fetchGenericDropdownItems(String url, Map<String, String> headers) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      return body.map((item) => DropdownItem(id: item['id'], nome: item['nome'])).toList();
    } else {
      throw OcorrenciaException('Falha ao carregar itens: $url');
    }
  }

  static Future<Map<String, dynamic>> _fetchSetores(String url, Map<String, String> headers) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      
      if (body.containsKey('setores') && body['setores'] is List) {
        return {
          'setores': (body['setores'] as List).map((item) => Setor.fromJson(item)).toList(),
          'setor_usuario_id': int.tryParse(body['setor_usuario']?.toString() ?? ''),
        };
      } else {
        throw OcorrenciaException('Estrutura de resposta inesperada para setores.');
      }
    } else {
      throw OcorrenciaException('Falha ao carregar setores.');
    }
  }

  static Future<void> createOcorrencia({
    required String assunto,
    required String descricao,
    int? prioridadeId,
    int? setorId,
    int? tipoOcorrenciaId,
    List<File>? imagens,
    double? latitude,
    double? longitude,
    List<List<double>>? poligono, // Novo parâmetro para polígono
    Map<String, dynamic>? mapData, // Dados completos do mapa com triangulações
  }) async {
    final token = AuthService.token;
    final userId = AuthService.userId;
    if (token == null || userId == null) throw AuthException('Sessão expirada.');

    var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/chamado/add/'));
    request.headers['Authorization'] = 'Token $token';
    
    // Log dos dados que serão enviados
    print('📤 Enviando dados para o servidor:');
    print('📍 Latitude: $latitude');
    print('📍 Longitude: $longitude');
    print('🗺️ Polígono: ${poligono?.length} pontos');
    if (poligono != null) {
      print('🗺️ Primeiro ponto: ${poligono.first}');
    }
    if (mapData != null) {
      print('🗺️ Dados completos do mapa: ${mapData.keys.join(', ')}');
      print('🗺️ Centro do mapa: ${mapData['center']}');
      print('🗺️ Setor no mapa: ${mapData['setor']}');
    }
    
    request.fields.addAll({
      'nome': assunto,
      'descricao': descricao,
      'usuario': userId.toString(),
      if (prioridadeId != null) 'prioridade': prioridadeId.toString(),
      if (setorId != null) 'setor': setorId.toString(),
      if (tipoOcorrenciaId != null) 'tipo_ocorrencia': tipoOcorrenciaId.toString(),
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (poligono != null) 'poligono': json.encode(poligono),
      if (mapData != null) 'map_data': json.encode(mapData), // Dados completos do mapa
    });

    if (imagens != null) {
      for (var img in imagens) {
        request.files.add(await http.MultipartFile.fromPath('imagem', img.path));
      }
    }

    final response = await request.send();
    print('📡 Resposta do servidor: ${response.statusCode}');
    
    if (response.statusCode >= 300) {
      final responseBody = await response.stream.bytesToString();
      print('❌ Erro do servidor: $responseBody');
      throw OcorrenciaException('Falha ao criar ocorrência. Status: ${response.statusCode}');
    }
    
    print('✅ Ocorrência criada com sucesso no servidor!');
  }

  static Future<List<Ocorrencia>> getOcorrenciasByStatus(String status) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/status/$status/usuario/listar/');
    final response = await http.get(url, headers: {'Authorization': 'Token $token'});
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ocorrencia.fromJson(json)).toList();
    }
    return [];
  }

  static Future<List<Ocorrencia>> getAssignedOcorrencias() async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/atribuidas/usuario/listar/');
    final response = await http.get(url, headers: {'Authorization': 'Token $token'});
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ocorrencia.fromJson(json)).toList();
    }
    return [];
  }
  
  static Future<Ocorrencia> getOcorrenciaDetails(int ocorrenciaId) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/visualizar/');
    final headers = {'Authorization': 'Token $token'};
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return Ocorrencia.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    }
    throw OcorrenciaException('Falha ao carregar detalhes da ocorrência.');
  }

  static Future<List<Mensagem>> getMessages(int ocorrenciaId) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/mensagem/list/');
    final response = await http.get(url, headers: {'Authorization': 'Token $token'});
    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      return body.map((item) => Mensagem.fromJson(item)).toList();
    }
    return [];
  }

  static Future<List<Avaliacao>> getRatings(int ocorrenciaId) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/avaliacao/list/');
    final response = await http.get(url, headers: {'Authorization': 'Token $token'});
    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      return body.map((item) => Avaliacao.fromJson(item)).toList();
    }
    return [];
  }

  static Future<void> addMessage(int ocorrenciaId, String text, {File? image}) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/mensagem/add/');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Token $token';
    if (text.isNotEmpty) {
      request.fields['descricao'] = text;
    }
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('imagem', image.path));
    }
    final response = await request.send();
    if (response.statusCode != 201) {
      throw OcorrenciaException('Falha ao enviar mensagem.');
    }
  }

  static Future<void> addRating({required int ocorrenciaId, required int nota, required String comentario}) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/avaliacao/add/');
    final response = await http.post(url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
        body: json.encode({'nota': nota, 'descricao': comentario}));
    if (response.statusCode >= 300) throw OcorrenciaException('Falha ao enviar avaliação.');
  }

  static Future<void> addImage(int ocorrenciaId, File image) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/imagem/add/');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Token $token';
    request.files.add(await http.MultipartFile.fromPath('imagem', image.path));
    final response = await request.send();
    if (response.statusCode != 201) {
      throw OcorrenciaException('Falha ao enviar imagem.');
    }
  }
}
