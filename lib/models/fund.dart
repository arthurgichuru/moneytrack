/// Mirrors the `funds` table. This is the central entity of the app —
/// the list screen shows funds, the detail screen shows one fund,
/// and the form screen creates/edits one.
class Fund {
  final int fundId;
  final String fundName;

  /// Short ticker-style code, e.g. "CICMMF".
  final String? fundCode;

  /// FK -> fund_management_companies.company_id
  final int? companyId;

  /// FK -> fund_categories.category_id
  final int? categoryId;
  final String? currency;

  /// Annual management fee as a percentage, e.g. 2.0 means 2.0% p.a.
  final double? managementFee;
  final String? description;
  final String? investmentObjective;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Fund({
    required this.fundId,
    required this.fundName,
    this.fundCode,
    this.companyId,
    this.categoryId,
    this.currency,
    this.managementFee,
    this.description,
    this.investmentObjective,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserializes a database row. `management_fee` arrives from Postgres
  /// as NUMERIC which json-decodes as `num`, so we normalise to double.
  factory Fund.fromJson(Map<String, dynamic> json) => Fund(
        fundId: json['fund_id'] as int,
        fundName: json['fund_name'] as String,
        fundCode: json['fund_code'] as String?,
        companyId: json['company_id'] as int?,
        categoryId: json['category_id'] as int?,
        currency: json['currency'] as String?,
        managementFee: (json['management_fee'] as num?)?.toDouble(),
        description: json['description'] as String?,
        investmentObjective: json['investment_objective'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Serializes to a map for Supabase writes.
  Map<String, dynamic> toJson() => {
        'fund_id': fundId,
        'fund_name': fundName,
        'fund_code': fundCode,
        'company_id': companyId,
        'category_id': categoryId,
        'currency': currency,
        'management_fee': managementFee,
        'description': description,
        'investment_objective': investmentObjective,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Returns a copy of this fund with some fields replaced.
  /// Used by the edit form: we never mutate a Fund in place — we build a
  /// new one, which keeps signals' change-detection reliable.
  Fund copyWith({
    int? fundId,
    String? fundName,
    String? fundCode,
    int? companyId,
    int? categoryId,
    String? currency,
    double? managementFee,
    String? description,
    String? investmentObjective,
    bool? isActive,
    DateTime? updatedAt,
  }) =>
      Fund(
        fundId: fundId ?? this.fundId,
        fundName: fundName ?? this.fundName,
        fundCode: fundCode ?? this.fundCode,
        companyId: companyId ?? this.companyId,
        categoryId: categoryId ?? this.categoryId,
        currency: currency ?? this.currency,
        managementFee: managementFee ?? this.managementFee,
        description: description ?? this.description,
        investmentObjective: investmentObjective ?? this.investmentObjective,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
