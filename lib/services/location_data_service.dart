// lib/services/location_data_service.dart

import 'package:logger/logger.dart';

class LocationDataService {
  static final _logger = Logger();

  /// Lista de áreas/regiões da cidade
  static final List<String> areas = [
    'Centro',
    'Zona Norte',
    'Zona Sul', 
    'Zona Leste',
    'Zona Oeste',
    'Centro Histórico',
    'Distrito Industrial',
    'Bairro Comercial',
    'Residencial Norte',
    'Residencial Sul',
    'Vila Operária',
    'Jardim das Flores',
    'Vila Nova',
    'Bairro Alto',
    'Vale Verde',
  ];

  /// Lista de locais específicos da cidade
  static final List<String> locais = [
    // Centro
    'Praça da Matriz',
    'Rua Principal',
    'Avenida Central',
    'Praça do Comércio',
    'Rua do Mercado',
    'Avenida das Flores',
    'Praça da Liberdade',
    'Rua da Igreja',
    'Avenida Getúlio Vargas',
    'Praça da República',
    
    // Zona Norte
    'Rua das Palmeiras',
    'Avenida Norte',
    'Praça do Norte',
    'Rua dos Eucaliptos',
    'Avenida das Acácias',
    'Rua das Rosas',
    'Avenida dos Lírios',
    'Rua das Margaridas',
    'Avenida das Orquídeas',
    'Rua dos Girassóis',
    
    // Zona Sul
    'Rua das Hortênsias',
    'Avenida Sul',
    'Praça do Sul',
    'Rua dos Ipês',
    'Avenida das Magnólias',
    'Rua das Azaléias',
    'Avenida dos Jasmins',
    'Rua das Camélias',
    'Avenida das Begônias',
    'Rua dos Cravos',
    
    // Zona Leste
    'Rua das Violetas',
    'Avenida Leste',
    'Praça do Leste',
    'Rua dos Crisântemos',
    'Avenida das Petúnias',
    'Rua das Dálias',
    'Avenida dos Narcisos',
    'Rua das Tulipas',
    'Avenida das Bromélias',
    'Rua dos Antúrios',
    
    // Zona Oeste
    'Rua das Begônias',
    'Avenida Oeste',
    'Praça do Oeste',
    'Rua dos Hibiscos',
    'Avenida das Gardênias',
    'Rua das Hortênsias',
    'Avenida dos Lírios',
    'Rua das Rosas',
    'Avenida das Azaléias',
    'Rua dos Jasmins',
    
    // Locais específicos importantes
    'Hospital Municipal',
    'Prefeitura Municipal',
    'Câmara de Vereadores',
    'Fórum da Comarca',
    'Delegacia de Polícia',
    'Corpo de Bombeiros',
    'Defesa Civil',
    'Terminal Rodoviário',
    'Estação Ferroviária',
    'Aeroporto Municipal',
    'Universidade Federal',
    'Colégio Estadual',
    'Escola Municipal',
    'Shopping Center',
    'Mercado Municipal',
    'Feira Livre',
    'Parque Central',
    'Estádio Municipal',
    'Ginásio de Esportes',
    'Teatro Municipal',
    'Biblioteca Pública',
    'Museu Histórico',
    'Igreja Matriz',
    'Catedral',
    'Seminário',
    'Convento',
    'Cemitério Municipal',
    'Crematório',
    'Posto de Saúde',
    'UBS Centro',
    'UBS Norte',
    'UBS Sul',
    'UBS Leste',
    'UBS Oeste',
    'Pronto Socorro',
    'SAMU',
    'Polícia Militar',
    'Polícia Civil',
    'Guarda Municipal',
    'Trânsito Municipal',
    'Obras Públicas',
    'Meio Ambiente',
    'Assistência Social',
    'CRAS',
    'CREAS',
    'Conselho Tutelar',
    'Vigilância Sanitária',
    'Vigilância Epidemiológica',
    'Endemias',
    'Zoonoses',
    'Controle de Vetores',
    'Limpeza Urbana',
    'Coleta Seletiva',
    'Aterro Sanitário',
    'Usina de Reciclagem',
    'Estação de Tratamento',
    'Reservatório de Água',
    'Estação Elevatória',
    'Subestação Elétrica',
    'Posto de Combustível',
    'Distribuidora de Gás',
    'Central de Gás',
    'Usina de Energia',
    'Torre de Transmissão',
    'Antena de Rádio',
    'Torre de TV',
    'Repetidora',
    'Central Telefônica',
    'Provedor de Internet',
    'Data Center',
    'Servidor Municipal',
    'Backup de Dados',
    'Sistema de Informação',
    'Geoprocessamento',
    'Cartografia',
    'Cadastro Técnico',
    'IPTU',
    'ISS',
    'Taxa de Lixo',
    'Taxa de Iluminação',
    'Taxa de Limpeza',
    'Taxa de Coleta',
    'Taxa de Varrição',
    'Taxa de Capina',
    'Taxa de Poda',
    'Taxa de Manutenção',
    'Taxa de Conservação',
    'Taxa de Reforma',
    'Taxa de Ampliação',
    'Taxa de Construção',
    'Taxa de Demolição',
    'Taxa de Remoção',
    'Taxa de Limpeza de Terreno',
    'Taxa de Capina de Terreno',
    'Taxa de Manutenção de Terreno',
    'Taxa de Conservação de Terreno',
    'Taxa de Reforma de Terreno',
    'Taxa de Ampliação de Terreno',
    'Taxa de Construção de Terreno',
    'Taxa de Demolição de Terreno',
    'Taxa de Remoção de Terreno',
  ];

  /// Busca áreas que correspondem ao texto digitado
  static List<String> searchAreas(String query) {
    if (query.isEmpty) return areas;
    
    final queryLower = query.toLowerCase();
    return areas
        .where((area) => area.toLowerCase().contains(queryLower))
        .toList();
  }

  /// Busca locais que correspondem ao texto digitado
  static List<String> searchLocais(String query) {
    if (query.isEmpty) return locais;
    
    final queryLower = query.toLowerCase();
    return locais
        .where((local) => local.toLowerCase().contains(queryLower))
        .toList();
  }

  /// Valida se uma área existe
  static bool isValidArea(String area) {
    return areas.contains(area);
  }

  /// Valida se um local existe
  static bool isValidLocal(String local) {
    return locais.contains(local);
  }

  /// Obtém sugestões de áreas baseadas no texto
  static List<String> getAreaSuggestions(String query, {int limit = 5}) {
    final results = searchAreas(query);
    return results.take(limit).toList();
  }

  /// Obtém sugestões de locais baseadas no texto
  static List<String> getLocalSuggestions(String query, {int limit = 10}) {
    final results = searchLocais(query);
    return results.take(limit).toList();
  }

  /// Obtém áreas mais comuns (para exibir como sugestões iniciais)
  static List<String> getCommonAreas() {
    return [
      'Centro',
      'Zona Norte',
      'Zona Sul',
      'Zona Leste',
      'Zona Oeste',
    ];
  }

  /// Obtém locais mais comuns (para exibir como sugestões iniciais)
  static List<String> getCommonLocais() {
    return [
      'Praça da Matriz',
      'Rua Principal',
      'Avenida Central',
      'Hospital Municipal',
      'Prefeitura Municipal',
      'Corpo de Bombeiros',
      'Defesa Civil',
      'Parque Central',
      'Terminal Rodoviário',
      'Mercado Municipal',
    ];
  }
}
