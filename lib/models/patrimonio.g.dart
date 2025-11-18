// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patrimonio.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatrimonioAdapter extends TypeAdapter<Patrimonio> {
  @override
  final int typeId = 0;

  @override
  Patrimonio read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Patrimonio(
      id: fields[0] as int?,
      numeroPatrimonio: fields[1] as String,
      descricao: fields[2] as String,
      sala: fields[3] as String,
      responsavel: fields[4] as String,
      situacao: fields[5] as String,
      observacoes: fields[6] as String?,
      fotoUrl: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
      isModified: fields[10] as bool,
      originalValues: (fields[11] as Map?)?.cast<String, dynamic>(),
      modifiedFields: (fields[12] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Patrimonio obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.numeroPatrimonio)
      ..writeByte(2)
      ..write(obj.descricao)
      ..writeByte(3)
      ..write(obj.sala)
      ..writeByte(4)
      ..write(obj.responsavel)
      ..writeByte(5)
      ..write(obj.situacao)
      ..writeByte(6)
      ..write(obj.observacoes)
      ..writeByte(7)
      ..write(obj.fotoUrl)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.isModified)
      ..writeByte(11)
      ..write(obj.originalValues)
      ..writeByte(12)
      ..write(obj.modifiedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatrimonioAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
