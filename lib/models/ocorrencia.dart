// lib/models/ocorrencia.dart

import 'package:dc_app/models/mensagem.dart';
import 'package:dc_app/models/package_utils.dart';

class Ocorrencia {
  final int id;
  final String assunto;
  final String descricao;
  final String status;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final DateTime? dataUltimaAtualizacao;
  final List<String> todasAnexoUrls;
  // NOVO: Lista de mensagens aninhadas
  final List<Mensagem> mensagens;

  final String? tipoOcorrenciaNome;
  final String? prioridadeNome;
  final String? setorNome;
  final String? solicitanteNome;
  final String? responsavelNome;
  final int? solicitanteId;
  
  // Campos para dados geográficos
  final List<Map<String, dynamic>>? poligonos;
  final List<Map<String, dynamic>>? pontos;
  final double? latitude;
  final double? longitude;

  Ocorrencia({
    required this.id,
    required this.assunto,
    required this.descricao,
    required this.status,
    this.dataInicio,
    this.dataFim,
    this.dataUltimaAtualizacao,
    this.todasAnexoUrls = const [],
    this.mensagens = const [], // Adicionado
    this.tipoOcorrenciaNome,
    this.prioridadeNome,
    this.setorNome,
    this.solicitanteNome,
    this.responsavelNome,
    this.solicitanteId,
    this.poligonos,
    this.pontos,
    this.latitude,
    this.longitude,
  });

  factory Ocorrencia.fromJson(Map<String, dynamic> json) {
    String statusText = json['status'] is bool
        ? ((json['status'] as bool) ? 'Encerrada' : 'Aberta') // Texto atualizado
        : (json['status'] ?? 'Status desconhecido');

    List<String> urlsDeImagens = [];
    if (json['imagem'] is List) {
      for (var itemImagem in json['imagem']) {
        if (itemImagem is Map<String, dynamic> && itemImagem.containsKey('imagem_url')) {
          final url = itemImagem['imagem_url'] as String?;
          if (url != null && url.isNotEmpty) {
            urlsDeImagens.add(PackageUtils.buildFullUrl(url));
          }
        }
      }
    }

    // Lógica para ler as mensagens aninhadas
    List<Mensagem> mensagensAninhadas = [];
    if (json['mensagem'] is List) {
      mensagensAninhadas = (json['mensagem'] as List)
          .map((msgJson) => Mensagem.fromJson(msgJson))
          .toList();
    }

    // Lógica para ler dados geográficos
    List<Map<String, dynamic>>? poligonosData;
    List<Map<String, dynamic>>? pontosData;
    double? lat;
    double? lng;
    
    // Debug: mostrar estrutura completa do JSON
    print('🔍 Debug - JSON completo recebido (ID: ${json['id']}):');
    print('   - Chaves disponíveis: ${json.keys.join(', ')}');
    print('   - poligono presente: ${json.containsKey('poligono')}');
    print('   - ponto presente: ${json.containsKey('ponto')}');
    if (json['poligono'] != null) {
      print('   - poligono tipo: ${json['poligono'].runtimeType}');
      if (json['poligono'] is List) {
        print('   - poligono length: ${(json['poligono'] as List).length}');
        if ((json['poligono'] as List).isNotEmpty) {
          print('   - primeiro polígono: ${(json['poligono'] as List).first.keys.join(', ')}');
        }
      }
    }
    
    if (json['poligono'] is List && (json['poligono'] as List).isNotEmpty) {
      poligonosData = (json['poligono'] as List).cast<Map<String, dynamic>>();
      print('🔍 Debug - Estrutura dos polígonos:');
      for (int i = 0; i < poligonosData.length; i++) {
        print('   Polígono $i: ${poligonosData[i].keys.join(', ')}');
        if (poligonosData[i]['geom'] != null) {
          print('   - geom: ${poligonosData[i]['geom'].keys.join(', ')}');
          if (poligonosData[i]['geom']['coordinates'] != null) {
            final coords = poligonosData[i]['geom']['coordinates'] as List;
            print('   - coordinates: ${coords.length} anéis');
            if (coords.isNotEmpty && coords.first is List) {
              print('   - primeiro anel: ${(coords.first as List).length} pontos');
            }
          }
        }
      }
    }
    
    if (json['ponto'] is List && (json['ponto'] as List).isNotEmpty) {
      pontosData = (json['ponto'] as List).cast<Map<String, dynamic>>();
      // Extrai latitude e longitude do primeiro ponto
      if (pontosData.isNotEmpty && pontosData.first['geom'] != null) {
        final coords = pontosData.first['geom']['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          lng = coords[0].toDouble();
          lat = coords[1].toDouble();
        }
      }
    } else if (poligonosData != null && poligonosData.isNotEmpty) {
      // Se não há ponto, calcula o centro do primeiro polígono
      final firstPolygon = poligonosData.first;
      if (firstPolygon['geom'] != null && firstPolygon['geom']['coordinates'] != null) {
        final coords = firstPolygon['geom']['coordinates'] as List;
        if (coords.isNotEmpty && coords.first is List) {
          final polygonCoords = coords.first as List;
          if (polygonCoords.isNotEmpty) {
            // Calcula o centro do polígono
            double sumLat = 0;
            double sumLng = 0;
            for (var coord in polygonCoords) {
              if (coord is List && coord.length >= 2) {
                sumLng += coord[0].toDouble();
                sumLat += coord[1].toDouble();
              }
            }
            lng = sumLng / polygonCoords.length;
            lat = sumLat / polygonCoords.length;
            print('🔍 Debug - Centro calculado do polígono: lat=$lat, lng=$lng');
          }
        }
      }
    }

    int? finalSolicitanteId;
    if (json['usuario'] is int) {
      finalSolicitanteId = json['usuario'];
    } else if (json['usuario'] is Map && json['usuario']['id'] != null) {
      finalSolicitanteId = PackageUtils.parseInt(json['usuario']['id']);
    } else if (json['usuario_nome'] == json['responsavel_nome'] && json['responsavel'] is int) {
      finalSolicitanteId = json['responsavel'];
    }


    return Ocorrencia(
      id: PackageUtils.parseInt(json['id']),
      assunto: json['nome'] ?? json['assunto'] ?? 'Assunto não informado',
      descricao: json['descricao'] ?? 'Sem descrição.',
      status: statusText,
      dataInicio: PackageUtils.parseDateTime(json['data_inicio']),
      dataFim: PackageUtils.parseDateTime(json['data_fim']),
      dataUltimaAtualizacao: PackageUtils.parseDateTime(json['data_ultima_atualizacao']),
      todasAnexoUrls: urlsDeImagens,
      mensagens: mensagensAninhadas, // Adicionado
      prioridadeNome: PackageUtils.getNameFromJson(json['prioridade']) ?? (json['prioridade_nome'] as String?),
      setorNome: PackageUtils.getNameFromJson(json['setor']) ?? (json['setor_nome'] as String?),
      // Lógica atualizada para aceitar 'tipo_ocorrencia' ou 'tipo_chamado' da API
      tipoOcorrenciaNome: PackageUtils.getNameFromJson(json['tipo_ocorrencia']) ??
          PackageUtils.getNameFromJson(json['tipo_chamado']) ??
          (json['tipo_ocorrencia_nome'] as String?) ??
          (json['tipo_chamado_nome'] as String?),
      solicitanteId: finalSolicitanteId,
      solicitanteNome: json['usuario_nome'] as String?,
      responsavelNome: PackageUtils.getNameFromJson(json['responsavel']) ?? (json['responsavel_nome'] as String?),
      poligonos: poligonosData,
      pontos: pontosData,
      latitude: lat,
      longitude: lng,
    );
  }
}