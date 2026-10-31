class SalaryAdvance {
  const SalaryAdvance({
    required this.id,
    required this.employeeId,
    required this.organisationId,
    required this.amount,
    required this.requestedAt,
    required this.status,
  });

  final String id;
  final String employeeId;
  final String organisationId;
  final double amount;
  final DateTime requestedAt;
  final String status;
}

class SalaryPayment {
  const SalaryPayment({
    required this.id,
    required this.employeeId,
    required this.organisationId,
    required this.amount,
    required this.paidAt,
    required this.reference,
  });

  final String id;
  final String employeeId;
  final String organisationId;
  final double amount;
  final DateTime paidAt;
  final String reference;
}

class PayrollSummary {
  const PayrollSummary({
    required this.employeeId,
    required this.grossSalary,
    required this.advances,
    required this.payments,
  });

  final String employeeId;
  final double grossSalary;
  final double advances;
  final double payments;

  double get remainingBalance => grossSalary - advances - payments;

  double get netPay => grossSalary - advances;
}
