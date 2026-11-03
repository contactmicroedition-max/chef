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
    this.approvalStatus = 'approved',
    this.shiftId,
    this.assignedShiftId,
    this.shiftName,
    this.assignedShiftName,
    this.autoClosed = false,
  });

  final String id;
  final String employeeId;
  final String organisationId;
  final DateTime date;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String? note;
  final String status;
  final String approvalStatus;
  final String? shiftId;
  final String? assignedShiftId;
  final String? shiftName;
  final String? assignedShiftName;
  final bool autoClosed;

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
    String? approvalStatus,
    String? shiftId,
    String? assignedShiftId,
    String? shiftName,
    String? assignedShiftName,
    bool? autoClosed,
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
      approvalStatus: approvalStatus ?? this.approvalStatus,
      shiftId: shiftId ?? this.shiftId,
      assignedShiftId: assignedShiftId ?? this.assignedShiftId,
      shiftName: shiftName ?? this.shiftName,
      assignedShiftName: assignedShiftName ?? this.assignedShiftName,
      autoClosed: autoClosed ?? this.autoClosed,
    );
  }
}
