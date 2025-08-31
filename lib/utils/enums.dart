// ignore: constant_identifier_names
enum Layout { DEFAULT, BEAUTY }

// ignore: constant_identifier_names
enum ShiftType { FULL, DAY, NIGHT }

extension ShiftTypeExt on ShiftType {
  static ShiftType fromString(String s) {
    final v = s.toUpperCase();
    if (v == 'DAY') return ShiftType.DAY;
    if (v == 'NIGHT') return ShiftType.NIGHT;
    return ShiftType.FULL;
  }

  String toShortString() {
    return toString().split('.').last;
  }
}

class ReservatedDay {
  final DateTime reservedFrom;
  final DateTime reservedTo;
  final ShiftType shiftType;

  ReservatedDay({
    required this.reservedFrom,
    required this.reservedTo,
    required this.shiftType,
  });

  factory ReservatedDay.fromJson(Map<String, dynamic> json) {
    return ReservatedDay(
      reservedFrom: DateTime.parse(json['reservedFrom'] as String),
      reservedTo: DateTime.parse(json['reservedTo'] as String),
      shiftType: ShiftTypeExt.fromString(json['shiftType'] as String),
    );
  }

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final a = DateTime(reservedFrom.year, reservedFrom.month, reservedFrom.day);
    final b = DateTime(reservedTo.year, reservedTo.month, reservedTo.day);
    return (d.isAtSameMomentAs(a) || d.isAtSameMomentAs(b)) ||
        (d.isAfter(a) && d.isBefore(b));
  }
}
