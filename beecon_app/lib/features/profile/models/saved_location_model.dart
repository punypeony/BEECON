import 'dart:math';

import 'package:hive/hive.dart';

class SavedLocationModel extends HiveObject {
  SavedLocationModel({
    String? id,
    required this.name,
    required this.lat,
    required this.lng,
    DateTime? savedAt,
  })  : id = id ?? _generateId(),
        savedAt = savedAt ?? DateTime.now();

  String id;
  String name;
  double lat;
  double lng;
  DateTime savedAt;

  static String _generateId() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

class SavedLocationModelAdapter extends TypeAdapter<SavedLocationModel> {
  @override
  final int typeId = 1;

  @override
  SavedLocationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedLocationModel(
      id: fields[0] as String,
      name: fields[1] as String,
      lat: fields[2] as double,
      lng: fields[3] as double,
      savedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SavedLocationModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.lat)
      ..writeByte(3)
      ..write(obj.lng)
      ..writeByte(4)
      ..write(obj.savedAt);
  }
}
