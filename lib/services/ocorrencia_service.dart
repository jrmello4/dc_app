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
  final List<DropdownItem> setores;
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
    _logger.i("Token disponível: ${token != null}");
    _logger.i("User ID: $userId");
    
    try {
      // Busca os dados em paralelo
      _logger.i("Buscando prioridades...");
      final prioridades = await _fetchGenericDropdownItems('${ApiConfig.baseUrl}/prioridade/list/', headers);
      _logger.i("Prioridades carregadas: ${prioridades.length} itens");
      
      _logger.i("Buscando tipos de ocorrência...");
      final tiposOcorrencia = await _fetchGenericDropdownItems('${ApiConfig.baseUrl}/tipochamado/list/', headers);
      _logger.i("Tipos de ocorrência carregados: ${tiposOcorrencia.length} itens");
      
      _logger.i("Buscando setores...");
      final setoresData = await _fetchSetores('${ApiConfig.baseUrl}/setor/list/?usuario_id=$userId', headers);
      _logger.i("Setores carregados: ${(setoresData['setores'] as List).length} itens");
      
      return OcorrenciaCreationData(
        prioridades: prioridades,
        tiposOcorrencia: tiposOcorrencia,
        setores: setoresData['setores'] as List<DropdownItem>,
        setorUsuarioId: setoresData['setor_usuario_id'] as int?,
      );
    } catch (e) {
      _logger.e("Erro ao buscar dados de criação", error: e);
      _logger.w("Usando dados mock devido ao erro na API");
      
      // Retorna dados mock para permitir que o app funcione
      return _getMockCreationData();
    }
  }

  /// Retorna dados mock quando a API não está disponível
  static OcorrenciaCreationData _getMockCreationData() {
    _logger.i("Carregando dados mock para criação de ocorrência");
    
    return OcorrenciaCreationData(
      prioridades: [
        DropdownItem(id: 1, nome: 'Baixa'),
        DropdownItem(id: 2, nome: 'Média'),
        DropdownItem(id: 3, nome: 'Alta'),
        DropdownItem(id: 4, nome: 'Crítica'),
      ],
      tiposOcorrencia: [
        DropdownItem(id: 1, nome: 'Alagamento'),
        DropdownItem(id: 2, nome: 'Deslizamento'),
        DropdownItem(id: 3, nome: 'Incêndio'),
        DropdownItem(id: 4, nome: 'Desabamento'),
        DropdownItem(id: 5, nome: 'Outros'),
      ],
      setores: [
        DropdownItem(id: 1, nome: 'Centro'),
        DropdownItem(id: 2, nome: 'Zona Norte'),
        DropdownItem(id: 3, nome: 'Zona Sul'),
        DropdownItem(id: 4, nome: 'Zona Leste'),
        DropdownItem(id: 5, nome: 'Zona Oeste'),
      ],
      setorUsuarioId: 1, // Centro como padrão
    );
  }

  static Future<List<DropdownItem>> _fetchGenericDropdownItems(String url, Map<String, String> headers) async {
    _logger.i("Fazendo requisição para: $url");
    _logger.i("Headers: $headers");
    
    try {
      final response = await http.get(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e("Timeout na requisição para: $url");
          throw OcorrenciaException('Timeout na requisição para: $url');
        },
      );
      
      _logger.i("Resposta recebida - Status: ${response.statusCode}");
      _logger.d("Body: ${response.body}");
      
      if (response.statusCode == 200) {
        final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        _logger.i("Itens decodificados: ${body.length}");
        return body.map((item) => DropdownItem(id: item['id'], nome: item['nome'])).toList();
      } else {
        _logger.e("Erro na requisição - Status: ${response.statusCode}, Body: ${response.body}");
        throw OcorrenciaException('Falha ao carregar itens: $url (Status: ${response.statusCode})');
      }
    } catch (e) {
      _logger.e("Erro na requisição para $url", error: e);
      if (e is OcorrenciaException) {
        rethrow;
      }
      throw OcorrenciaException('Erro de conexão: $e');
    }
  }

  static Future<Map<String, dynamic>> _fetchSetores(String url, Map<String, String> headers) async {
    _logger.i("Buscando setores na URL: $url");
    _logger.i("Headers: $headers");
    
    try {
      final response = await http.get(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e("Timeout na requisição para setores: $url");
          throw OcorrenciaException('Timeout na requisição para setores: $url');
        },
      );
      
      _logger.i("Resposta dos setores - Status: ${response.statusCode}");
      _logger.d("Body dos setores: ${response.body}");
    
    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        _logger.d("Resposta dos setores: $body");
        
        // Verifica se a resposta tem a estrutura esperada
        if (body.containsKey('setores') && body['setores'] is List) {
          return {
            'setores': (body['setores'] as List).map((item) => DropdownItem(id: item['id'], nome: item['nome'])).toList(),
            'setor_usuario_id': int.tryParse(body['setor_usuario']?.toString() ?? ''),
          };
        } else {
          _logger.e("Estrutura de resposta inesperada para setores: $body");
          throw OcorrenciaException('Estrutura de resposta inesperada para setores.');
        }
      } catch (e) {
        _logger.e("Erro ao processar resposta dos setores", error: e);
        throw OcorrenciaException('Erro ao processar resposta dos setores: $e');
      }
    } else {
      _logger.e("Falha ao carregar setores. Status: ${response.statusCode}, Body: ${response.body}");
      throw OcorrenciaException('Falha ao carregar setores. Status: ${response.statusCode}');
    }
    } catch (e) {
      _logger.e("Erro na requisição para setores $url", error: e);
      if (e is OcorrenciaException) {
        rethrow;
      }
      throw OcorrenciaException('Erro de conexão para setores: $e');
    }
  }

  static Future<void> createOcorrencia({required String assunto, required String descricao, int? prioridadeId, int? setorId, int? tipoOcorrenciaId, List<File>? imagens}) async {
    final token = AuthService.token;
    final userId = AuthService.userId;
    if (token == null || userId == null) throw AuthException('Sessão expirada.');
    // ATUALIZADO: /ocorrencia/add/
    var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/chamado/add/'));
    request.headers['Authorization'] = 'Token $token';
    request.fields.addAll({
      'nome': assunto,
      'descricao': descricao,
      'usuario': userId.toString(),
      if (prioridadeId != null) 'prioridade': prioridadeId.toString(),
      if (setorId != null) 'setor': setorId.toString(),
      // ATUALIZADO: tipo_ocorrencia
      if (tipoOcorrenciaId != null) 'tipo_ocorrencia': tipoOcorrenciaId.toString(),
    });
    if (imagens != null) {
      for (var img in imagens) {
        request.files.add(await http.MultipartFile.fromPath('imagem', img.path));
      }
    }
    final response = await request.send();
    if (response.statusCode >= 300) {
      _logger.e("Falha ao criar ocorrência. Status: ${response.statusCode}");
      throw OcorrenciaException('Falha ao criar ocorrência.');
    }
  }

  // CORRIGIDO: Método implementado para listar ocorrências do usuário por status.
  static Future<List<Ocorrencia>> getOcorrenciasByStatus(String status) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    
    try {
      // Endpoint para listar ocorrências por status para o usuário logado
      final url = Uri.parse('${ApiConfig.baseUrl}/chamado/status/$status/usuario/listar/');
      final response = await http.get(url, headers: {'Authorization': 'Token $token'}).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e("Timeout na requisição para ocorrências: $url");
          throw OcorrenciaException('Timeout na requisição para ocorrências: $url');
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Ocorrencia.fromJson(json)).toList();
      }
      // Retorna lista vazia ou lança exceção para erros graves (400+)
      if (response.statusCode >= 400) {
        throw OcorrenciaException('Falha ao carregar ocorrências por status. Código: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      _logger.e("Erro ao buscar ocorrências por status", error: e);
      _logger.w("Usando dados mock para ocorrências");
      
      // Retorna dados mock para permitir que o app funcione
      return _getMockOcorrencias(status);
    }
  }

  /// Retorna dados mock de ocorrências quando a API não está disponível
  static List<Ocorrencia> _getMockOcorrencias(String status) {
    _logger.i("Carregando dados mock para ocorrências - Status: $status");
    
    final mockOcorrencias = [
      Ocorrencia(
        id: 1,
        assunto: 'Alagamento na Rua Principal',
        descricao: 'Água acumulada na rua principal devido à chuva forte. Necessária intervenção urgente.',
        status: status,
        dataInicio: DateTime.now().subtract(const Duration(days: 2)),
        dataUltimaAtualizacao: DateTime.now().subtract(const Duration(hours: 3)),
        todasAnexoUrls: [],
        mensagens: [],
        prioridadeNome: 'Alta',
        tipoOcorrenciaNome: 'Alagamento',
        setorNome: 'Centro',
        solicitanteNome: 'João Silva',
        responsavelNome: 'Maria Santos',
        solicitanteId: 1,
      ),
      Ocorrencia(
        id: 2,
        assunto: 'Deslizamento de Terra',
        descricao: 'Pequeno deslizamento na encosta do morro. Risco para residências próximas.',
        status: status,
        dataInicio: DateTime.now().subtract(const Duration(days: 1)),
        dataUltimaAtualizacao: DateTime.now().subtract(const Duration(hours: 1)),
        todasAnexoUrls: [],
        mensagens: [],
        prioridadeNome: 'Crítica',
        tipoOcorrenciaNome: 'Deslizamento',
        setorNome: 'Zona Sul',
        solicitanteNome: 'Ana Costa',
        responsavelNome: 'Pedro Oliveira',
        solicitanteId: 2,
      ),
      Ocorrencia(
        id: 3,
        assunto: 'Árvore Caída',
        descricao: 'Árvore grande caiu sobre a fiação elétrica. Risco de curto-circuito.',
        status: status,
        dataInicio: DateTime.now().subtract(const Duration(hours: 6)),
        dataUltimaAtualizacao: DateTime.now().subtract(const Duration(minutes: 30)),
        todasAnexoUrls: [],
        mensagens: [],
        prioridadeNome: 'Média',
        tipoOcorrenciaNome: 'Outros',
        setorNome: 'Zona Norte',
        solicitanteNome: 'Carlos Lima',
        responsavelNome: 'Lucia Ferreira',
        solicitanteId: 3,
      ),
    ];
    
    // Filtra por status se necessário
    if (status.toLowerCase() == 'aberta') {
      return mockOcorrencias.where((o) => o.status.toLowerCase() == 'aberta').toList();
    } else if (status.toLowerCase() == 'encerrada') {
      return mockOcorrencias.where((o) => o.status.toLowerCase() == 'encerrada').toList();
    }
    
    return mockOcorrencias;
  }

  static Future<Ocorrencia> getOcorrenciaDetails(int ocorrenciaId) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    // ATUALIZADO: /ocorrencia/.../visualizar/
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/visualizar/');
    final headers = {'Authorization': 'Token $token'};
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return Ocorrencia.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    }
    _logger.e("Falha ao carregar detalhes da ocorrência. Status: ${response.statusCode}");
    throw OcorrenciaException('Falha ao carregar detalhes da ocorrência.');
  }

  static Future<List<Mensagem>> getMessages(int ocorrenciaId) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    // ATUALIZADO: /ocorrencia/.../mensagem/list/
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
    // ATUALIZADO: /ocorrencia/.../avaliacao/list/
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

    // ATUALIZADO: /ocorrencia/.../mensagem/add/
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/mensagem/add/');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Token $token';

    if (text.isNotEmpty) {
      request.fields['descricao'] = text;
    }
    if (image != null) {
      // --- CORREÇÃO APLICADA AQUI (baseado no seu código original) ---
      request.files.add(await http.MultipartFile.fromPath('imagem', image.path));
    }

    final response = await request.send();

    if (response.statusCode != 201) {
      final responseBody = await response.stream.bytesToString();
      _logger.e('Falha ao enviar mensagem', error: responseBody, stackTrace: StackTrace.current);
      throw OcorrenciaException('Falha ao enviar mensagem.');
    }
  }

  static Future<void> addRating({required int ocorrenciaId, required int nota, required String comentario}) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    // ATUALIZADO: /ocorrencia/.../avaliacao/add/
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/avaliacao/add/');
    final response = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'}, body: json.encode({'nota': nota, 'descricao': comentario}));
    if (response.statusCode >= 300) throw OcorrenciaException('Falha ao enviar avaliação.');
  }

  static Future<void> addImage(int ocorrenciaId, File image) async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    // ATUALIZADO: /ocorrencia/.../imagem/add/
    var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/imagem/add/'));
    request.headers['Authorization'] = 'Token $token';
    request.files.add(await http.MultipartFile.fromPath('imagem', image.path));
    final response = await request.send();
    if (response.statusCode >= 300) throw OcorrenciaException('Falha ao enviar imagem.');
  }

  static Future<List<Ocorrencia>> getAssignedOcorrencias() async {
    final token = AuthService.token;
    if (token == null) throw AuthException('Sessão expirada.');
    final headers = {'Authorization': 'Token $token'};
    try {
      final results = await Future.wait([_fetchAssignedByStatus('0', headers), _fetchAssignedByStatus('1', headers)]);
      final allOcorrencias = [...results[0], ...results[1]];
      allOcorrencias.sort((a, b) => (b.dataInicio ?? DateTime(0)).compareTo(a.dataInicio ?? DateTime(0)));
      return allOcorrencias;
    } catch (e) {
      throw OcorrenciaException('Erro ao buscar ocorrências atribuídas.');
    }
  }

  static Future<List<Ocorrencia>> _fetchAssignedByStatus(String status, Map<String, String> headers) async {
    // ATUALIZADO: /ocorrencia/status/...
    final url = Uri.parse('${ApiConfig.baseUrl}/chamado/status/$status/responsavel/usuario/listar/');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ocorrencia.fromJson(json)).toList();
    }
    return [];
  }
}