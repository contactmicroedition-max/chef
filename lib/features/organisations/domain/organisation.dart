class Organisation {
  const Organisation({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.ownerId,
    this.logoUrl,
    this.address,
    this.phone,
    this.status = 'active',
    this.createdAt,
    this.workHoursPerDay = 8,
    this.payrollDay = 30,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String currency;
  final String timezone;
  final String ownerId;
  final String status;
  final DateTime? createdAt;
  final int workHoursPerDay;
  final int payrollDay;

  Organisation copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? address,
    String? phone,
    String? currency,
    String? timezone,
    String? ownerId,
    String? status,
    DateTime? createdAt,
    int? workHoursPerDay,
    int? payrollDay,
  }) {
    return Organisation(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      ownerId: ownerId ?? this.ownerId,
      logoUrl: logoUrl ?? this.logoUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
      payrollDay: payrollDay ?? this.payrollDay,
    );
  }
}
