// lib/services/status_ocorrencia_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart'; // Import Logger
import 'package:dc_app/config/api_config.dart';
import 'package:dc_app/services/auth_service.dart';

class StatusOcorrenciaService {
  final Logger _logger = Logger(); // Adiciona um logger

  /// Função para Reabrir ou Encerrar uma ocorrência.
  /// [token]: Token de autenticação.
  /// [ocorrenciaId]: O PK da ocorrência.
  /// [acao]: Deve ser 'abrir' ou 'fechar'.
  Future<String> atualizarStatusOcorrencia(String token, int ocorrenciaId, String acao) async {
    if (acao != 'abrir' && acao != 'fechar') {
      throw ArgumentError("Ação inválida. Use 'abrir' ou 'fechar'.");
    }

    if (token.isEmpty) {
      throw Exception("Token de autenticação inválido.");
    }

    // Tenta primeiro o endpoint novo (/ocorrencia/)
    Uri url = Uri.parse('${ApiConfig.baseUrl}/ocorrencia/$ocorrenciaId/$acao/');
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Token $token',
    };

    http.Response response;
    try {
      _logger.i("Tentando atualizar status em: $url");
      response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({}), // O corpo é vazio, a ação está na URL
      );

      // Se o endpoint novo falhar (ex: 404 Not Found), tenta o antigo (/chamado/)
      if (response.statusCode >= 400) {
        _logger.w("Endpoint /ocorrencia/ falhou (${response.statusCode}). Tentando /chamado/...");
        url = Uri.parse('${ApiConfig.baseUrl}/chamado/$ocorrenciaId/$acao/');
        _logger.i("Tentando atualizar status em: $url");
        response = await http.post(
          url,
          headers: headers,
          body: jsonEncode({}),
        );
      }

    } catch (e) {
      _logger.e("Erro de rede ao atualizar status da ocorrência.", error: e);
      throw Exception("Erro de conexão ao tentar atualizar o status.");
    }

    final responseBody = utf8.decode(response.bodyBytes);
    final data = jsonDecode(responseBody);

    if (response.statusCode == 200) {
      _logger.i("Status da ocorrência $ocorrenciaId atualizado para '$acao' com sucesso.");
      return data['message'] ?? "Status atualizado com sucesso.";
    } else {
      // Pega a mensagem de erro da API para exibir ao usuário
      String errorMessage = data['error'] ?? data['detail'] ?? "Ocorreu um erro desconhecido.";
      _logger.e("Falha ao atualizar status. Status: ${response.statusCode}, Erro: $errorMessage");
      throw Exception(errorMessage);
    }
  }
}