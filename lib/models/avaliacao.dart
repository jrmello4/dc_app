// lib/models/avaliacao.dart

import 'package_utils.dart';
import 'package:dc_app/models/package_utils.dart'; // Import corrigido

// *** NOME DA CLASSE CORRIGIDO ***
class Avaliacao {
  final int id;
  final int nota;
  final String comentario;
  final DateTime? dataAvaliacao;
  final String nomeUsuario;
  final int? usuarioId;

  Avaliacao({
    required this.id,
    required this.nota,
    required this.comentario,
    this.dataAvaliacao,
    required this.nomeUsuario,
    this.usuarioId,
  });

  factory Avaliacao.fromJson(Map<String, dynamic> json) {
    return Avaliacao(
      id: PackageUtils.parseInt(json['id']),
      nota: PackageUtils.parseInt(json['nota']),
      comentario: json['descricao'] ?? '',
      dataAvaliacao: PackageUtils.parseDateTime(json['data']),
      nomeUsuario: json['usuario_nome'] ?? 'Usuário anônimo',
      usuarioId: PackageUtils.getIdFromJson(json['usuario']),
    );
  }
}