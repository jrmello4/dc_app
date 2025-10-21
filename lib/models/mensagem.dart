// lib/models/mensagem.dart

import 'package:dc_app/models/package_utils.dart';

class Mensagem {
  final int id;
  final String texto;
  final DateTime? dataCriacao;
  final String nomeUsuario;
  final int? usuarioId;
  final List<String> anexoUrls;

  Mensagem({
    required this.id,
    required this.texto,
    this.dataCriacao,
    required this.nomeUsuario,
    this.usuarioId,
    this.anexoUrls = const [],
  });

  String? get imageUrl => anexoUrls.isNotEmpty ? anexoUrls.first : null;

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    List<String> urls = [];
    // *** LÓGICA CORRIGIDA PARA LER A IMAGEM ***
    // A API agora envia 'imagem' como uma lista de objetos
    if (json['imagem'] is List) {
      for (var img in (json['imagem'] as List)) {
        if (img is Map<String, dynamic> && img.containsKey('imagem_url')) {
          final url = img['imagem_url'] as String?;
          if (url != null && url.isNotEmpty) {
            urls.add(PackageUtils.buildFullUrl(url));
          }
        }
      }
    }

    return Mensagem(
      id: PackageUtils.parseInt(json['id']),
      texto: json['descricao'] ?? '',
      dataCriacao: PackageUtils.parseDateTime(json['data']),
      nomeUsuario: json['usuario_nome'] ?? 'Usuário desconhecido',
      usuarioId: PackageUtils.parseInt(json['usuario'], defaultValue: -1),
      anexoUrls: urls,
    );
  }
}