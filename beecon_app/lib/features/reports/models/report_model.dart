import 'dart:math';

import 'package:hive/hive.dart';

class ReportModel extends HiveObject {
  ReportModel({
    String? id,
    required this.reportType,
    required this.description,
    required this.lat,
    required this.lng,
    this.photoPath,
    DateTime? timestamp,
    this.upvotes = 0,
    this.status = 'pending',
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  String id;
  String reportType;
  String description;
  double lat;
  double lng;
  String? photoPath;
  DateTime timestamp;
  int upvotes;
  String status;

  static String _generateId() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

class ReportModelAdapter extends TypeAdapter<ReportModel> {
  @override
  final int typeId = 0;

  @override
  ReportModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportModel(
      id: fields[0] as String,
      reportType: fields[1] as String,
      description: fields[2] as String,
      lat: fields[3] as double,
      lng: fields[4] as double,
      photoPath: fields[5] as String?,
      timestamp: fields[6] as DateTime,
      upvotes: fields[7] as int,
      status: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ReportModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportType)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.lat)
      ..writeByte(4)
      ..write(obj.lng)
      ..writeByte(5)
      ..write(obj.photoPath)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.upvotes)
      ..writeByte(8)
      ..write(obj.status);
  }
}
