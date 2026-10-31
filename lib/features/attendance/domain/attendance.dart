class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.organisationId,
    required this.date,
    required this.clockIn,
    required this.clockOut,
    this.note,
    this.status = 'approved',
  });

  final String id;
  final String employeeId;
  final String organisationId;
  final DateTime date;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String? note;
  final String status;

  Duration get duration {
    final end = clockOut ?? clockIn;
    return end.difference(clockIn);
  }

  double get hours => duration.inMinutes / 60.0;

  AttendanceRecord copyWith({
    String? id,
    String? employeeId,
    String? organisationId,
    DateTime? date,
    DateTime? clockIn,
    DateTime? clockOut,
    String? note,
    String? status,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      organisationId: organisationId ?? this.organisationId,
      date: date ?? this.date,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      note: note ?? this.note,
      status: status ?? this.status,
    );
  }
}
