import 'package:hive/hive.dart';

part 'patrimonio.g.dart';

@HiveType(typeId: 0)
class Patrimonio extends HiveObject {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String numeroPatrimonio;

  @HiveField(2)
  final String descricao;

  @HiveField(3)
  final String sala;

  @HiveField(4)
  final String responsavel;

  @HiveField(5)
  final String situacao;

  @HiveField(6)
  final String? observacoes;

  @HiveField(7)
  final String? fotoUrl;

  @HiveField(8)
  final DateTime? createdAt;

  @HiveField(9)
  final DateTime? updatedAt;

  // Campos para rastreamento de alterações (não vêm do servidor)
  @HiveField(10)
  final bool isModified;

  @HiveField(11)
  final Map<String, dynamic>? originalValues;

  @HiveField(12)
  final Map<String, dynamic>? modifiedFields;

  Patrimonio({
    this.id,
    required this.numeroPatrimonio,
    required this.descricao,
    required this.sala,
    required this.responsavel,
    required this.situacao,
    this.observacoes,
    this.fotoUrl,
    this.createdAt,
    this.updatedAt,
    this.isModified = false,
    this.originalValues,
    this.modifiedFields,
  });

  // Factory para criar a partir de JSON do backend
  factory Patrimonio.fromJson(Map<String, dynamic> json) {
    return Patrimonio(
      id: json['id'],
      numeroPatrimonio: json['numero_patrimonio'],
      descricao: json['descricao'],
      sala: json['sala'],
      responsavel: json['responsavel'],
      situacao: json['situacao'],
      observacoes: json['observacoes'],
      fotoUrl: json['foto_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // Converter para JSON para enviar ao backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero_patrimonio': numeroPatrimonio,
      'descricao': descricao,
      'sala': sala,
      'responsavel': responsavel,
      'situacao': situacao,
      'observacoes': observacoes,
      'foto_url': fotoUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Criar cópia com modificações
  Patrimonio copyWith({
    int? id,
    String? numeroPatrimonio,
    String? descricao,
    String? sala,
    String? responsavel,
    String? situacao,
    String? observacoes,
    String? fotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isModified,
    Map<String, dynamic>? originalValues,
    Map<String, dynamic>? modifiedFields,
    bool resetTracking = false,
  }) {
    return Patrimonio(
      id: id ?? this.id,
      numeroPatrimonio: numeroPatrimonio ?? this.numeroPatrimonio,
      descricao: descricao ?? this.descricao,
      sala: sala ?? this.sala,
      responsavel: responsavel ?? this.responsavel,
      situacao: situacao ?? this.situacao,
      observacoes: observacoes ?? this.observacoes,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isModified: resetTracking ? false : (isModified ?? this.isModified),
      originalValues: resetTracking ? null : (originalValues ?? this.originalValues),
      modifiedFields: resetTracking ? null : (modifiedFields ?? this.modifiedFields),
    );
  }

  @override
  String toString() {
    return 'Patrimonio(id: $id, numero: $numeroPatrimonio, descricao: $descricao, sala: $sala)';
  }
}