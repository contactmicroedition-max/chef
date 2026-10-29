enum EmploymentStatus { active, inactive, suspended }

enum EmployeeRole { owner, manager, employee }

enum EmployeePayType { hourly, monthly }

class Employee {
  const Employee({
    required this.id,
    required this.organisationId,
    required this.name,
    this.email,
    required this.jobTitle,
    required this.hourlyRate,
    this.payType = EmployeePayType.hourly,
    this.monthlySalary,
    required this.role,
    required this.employmentStatus,
    this.phone,
    this.hireDate,
  });

  final String id;
  final String organisationId;
  final String name;
  final String? email;
  final String jobTitle;
  final double hourlyRate;
  final EmployeePayType payType;
  final double? monthlySalary;
  final EmployeeRole role;
  final EmploymentStatus employmentStatus;
  final String? phone;
  final DateTime? hireDate;

  double salaryForHours(double hours) {
    return payType == EmployeePayType.hourly
        ? hourlyRate * hours
        : monthlySalary ?? 0;
  }

  Employee copyWith({
    String? id,
    String? organisationId,
    String? name,
    String? email,
    String? jobTitle,
    double? hourlyRate,
    EmployeePayType? payType,
    double? monthlySalary,
    EmployeeRole? role,
    EmploymentStatus? employmentStatus,
    String? phone,
    DateTime? hireDate,
  }) {
    return Employee(
      id: id ?? this.id,
      organisationId: organisationId ?? this.organisationId,
      name: name ?? this.name,
      email: email ?? this.email,
      jobTitle: jobTitle ?? this.jobTitle,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      payType: payType ?? this.payType,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      role: role ?? this.role,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      phone: phone ?? this.phone,
      hireDate: hireDate ?? this.hireDate,
    );
  }
}
