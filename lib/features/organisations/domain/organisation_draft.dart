class OrganisationDraft {
  const OrganisationDraft({
    required this.name,
    required this.currency,
    required this.timezone,
    this.address,
    this.phone,
    this.logoUrl,
  });

  final String name;
  final String currency;
  final String timezone;
  final String? address;
  final String? phone;
  final String? logoUrl;
}
