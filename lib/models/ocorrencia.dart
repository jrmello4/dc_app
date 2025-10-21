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
    );
  }
}