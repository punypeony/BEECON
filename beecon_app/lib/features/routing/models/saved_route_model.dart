import 'package:hive/hive.dart';

class SavedRouteModel extends HiveObject {
  SavedRouteModel({
    required this.routeId,
    required this.routeType,
    required this.totalScore,
    required this.distanceM,
    required this.durationMin,
    required this.originLabel,
    required this.destinationLabel,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  String routeId;
  String routeType;
  int totalScore;
  int distanceM;
  int durationMin;
  String originLabel;
  String destinationLabel;
  DateTime savedAt;
}

class SavedRouteModelAdapter extends TypeAdapter<SavedRouteModel> {
  @override
  final int typeId = 2;

  @override
  SavedRouteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedRouteModel(
      routeId: fields[0] as String,
      routeType: fields[1] as String,
      totalScore: fields[2] as int,
      distanceM: fields[3] as int,
      durationMin: fields[4] as int,
      originLabel: fields[5] as String,
      destinationLabel: fields[6] as String,
      savedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SavedRouteModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.routeId)
      ..writeByte(1)
      ..write(obj.routeType)
      ..writeByte(2)
      ..write(obj.totalScore)
      ..writeByte(3)
      ..write(obj.distanceM)
      ..writeByte(4)
      ..write(obj.durationMin)
      ..writeByte(5)
      ..write(obj.originLabel)
      ..writeByte(6)
      ..write(obj.destinationLabel)
      ..writeByte(7)
      ..write(obj.savedAt);
  }
}
