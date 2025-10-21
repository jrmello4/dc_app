// lib/config/api_config.dart

class ApiConfig {
  // --- CONTROLE DE AMBIENTE ---
  // Defina como 'true' para usar o servidor de produção.
  // Defina como 'false' para usar o servidor de desenvolvimento.
  static const bool isProduction = false;

  // --- CONFIGURAÇÕES DINÂMICAS ---
  static final String scheme = isProduction ? 'https' : 'http';
  static final String host = isProduction ? 'ti.araquari.sc.gov.br' : '10.70.11.58';
  static final String port = isProduction ? '' : ':8000'; // A porta só é adicionada em desenvolvimento

  // --- URLS FINAIS ---
  // URL base para as chamadas da API (ex: https://ti.araquari.sc.gov.br/api)
  static final String baseUrl = '$scheme://$host$port/api';

  // URL base para aceder a ficheiros de mídia (ex: https://ti.araquari.sc.gov.br)
  static final String baseMediaUrl = '$scheme://$host$port';

  // URL dos termos de uso
  static const String termsOfUseUrl = 'https://ti.araquari.sc.gov.br/termo/cadastro/usuario';
}