/// Mirrors the `fund_categories` table.
///
/// Every model in this app follows the same pattern:
///  - Immutable fields (`final`) so state can only change through signals.
///  - `fromJson` / `toJson` that use the *exact* Supabase column names,
///    so in iteration 2 the Supabase rows deserialize with zero changes.
class FundCategory {
  final int categoryId;
  final String categoryName;
  final String? categoryDescription;

  /// Free-text risk label, e.g. "Low", "Medium", "High".
  final String? riskLevel;
  final DateTime createdAt;

  const FundCategory({
    required this.categoryId,
    required this.categoryName,
    this.categoryDescription,
    this.riskLevel,
    required this.createdAt,
  });

  /// Builds a [FundCategory] from a database row / JSON map.
  /// Keys match the Postgres column names in the schema.
  factory FundCategory.fromJson(Map<String, dynamic> json) => FundCategory(
        categoryId: json['category_id'] as int,
        categoryName: json['category_name'] as String,
        categoryDescription: json['category_description'] as String?,
        riskLevel: json['risk_level'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Serializes back to a map suitable for a Supabase insert/update.
  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'category_name': categoryName,
        'category_description': categoryDescription,
        'risk_level': riskLevel,
        'created_at': createdAt.toIso8601String(),
      };
}
