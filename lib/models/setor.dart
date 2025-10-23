// lib/models/setor.dart

class Setor {
  final int id;
  final String nome;
  final double? latitude;
  final double? longitude;
  final double? raio; // Raio em metros

  Setor({
    required this.id,
    required this.nome,
    this.latitude,
    this.longitude,
    this.raio,
  });

  factory Setor.fromJson(Map<String, dynamic> json) {
    return Setor(
      id: json['id'],
      nome: json['nome'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      raio: (json['raio'] as num?)?.toDouble(),
    );
  }

  // Override para facilitar o uso em Dropdowns e comparações
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Setor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
