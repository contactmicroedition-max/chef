enum EmploymentStatus { active, inactive, suspended }

enum EmployeeRole { owner, manager, employee }

enum EmployeePayType { hourly, monthly }

class Employee {
  const Employee({
    required this.id,
    required this.organisationId,
    required this.name,
    required this.jobTitle,
    required this.hourlyRate,
    this.payType = EmployeePayType.hourly,
    this.monthlySalary,
    required this.role,
    required this.employmentStatus,
    this.loginId,
    this.loginEmail,
    this.hireDate,
  });

  final String id;
  final String organisationId;
  final String name;
  final String jobTitle;
  final double hourlyRate;
  final EmployeePayType payType;
  final double? monthlySalary;
  final EmployeeRole role;
  final EmploymentStatus employmentStatus;
  final String? loginId;
  final String? loginEmail;
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
    String? jobTitle,
    double? hourlyRate,
    EmployeePayType? payType,
    double? monthlySalary,
    EmployeeRole? role,
    EmploymentStatus? employmentStatus,
    String? loginId,
    String? loginEmail,
    DateTime? hireDate,
  }) {
    return Employee(
      id: id ?? this.id,
      organisationId: organisationId ?? this.organisationId,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      payType: payType ?? this.payType,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      role: role ?? this.role,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      loginId: loginId ?? this.loginId,
      loginEmail: loginEmail ?? this.loginEmail,
      hireDate: hireDate ?? this.hireDate,
    );
  }
}
