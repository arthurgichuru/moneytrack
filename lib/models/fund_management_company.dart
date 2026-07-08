/// Mirrors the `fund_management_companies` table.
class FundManagementCompany {
  final int companyId;
  final String companyName;
  final String? companyDescription;
  final String? companyWebsite;
  final String? physicalAddress;
  final String? city;
  final String? country;
  final String? postalAddress;
  final String? email;
  final String? phone;

  /// e.g. "CMA Licensed" — regulator status shown on the detail screen.
  final String? regulatoryStatus;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FundManagementCompany({
    required this.companyId,
    required this.companyName,
    this.companyDescription,
    this.companyWebsite,
    this.physicalAddress,
    this.city,
    this.country,
    this.postalAddress,
    this.email,
    this.phone,
    this.regulatoryStatus,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserializes a database row into a company object.
  factory FundManagementCompany.fromJson(Map<String, dynamic> json) =>
      FundManagementCompany(
        companyId: json['company_id'] as int,
        companyName: json['company_name'] as String,
        companyDescription: json['company_description'] as String?,
        companyWebsite: json['company_website'] as String?,
        physicalAddress: json['physical_address'] as String?,
        city: json['city'] as String?,
        country: json['country'] as String?,
        postalAddress: json['postal_address'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        regulatoryStatus: json['regulatory_status'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Serializes to a map for Supabase writes.
  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'company_name': companyName,
        'company_description': companyDescription,
        'company_website': companyWebsite,
        'physical_address': physicalAddress,
        'city': city,
        'country': country,
        'postal_address': postalAddress,
        'email': email,
        'phone': phone,
        'regulatory_status': regulatoryStatus,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
