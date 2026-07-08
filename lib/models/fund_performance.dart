/// Mirrors the `fund_performance` table — one row per fund per month.
class FundPerformance {
  final int performanceId;

  /// FK -> funds.fund_id (ON DELETE CASCADE in the schema).
  final int fundId;

  /// The month this observation belongs to (stored as DATE in Postgres).
  final DateTime performanceDate;

  /// Effective annual yield for that month, e.g. 13.42 means 13.42% p.a.
  final double? annualReturnRate;

  /// Market-wide rank for that month: 1 = best performing fund.
  final int? rankPosition;
  final DateTime createdAt;

  const FundPerformance({
    required this.performanceId,
    required this.fundId,
    required this.performanceDate,
    this.annualReturnRate,
    this.rankPosition,
    required this.createdAt,
  });

  /// Deserializes a database row.
  factory FundPerformance.fromJson(Map<String, dynamic> json) =>
      FundPerformance(
        performanceId: json['performance_id'] as int,
        fundId: json['fund_id'] as int,
        performanceDate: DateTime.parse(json['performance_date'] as String),
        annualReturnRate: (json['annual_return_rate'] as num?)?.toDouble(),
        rankPosition: json['rank_position'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Serializes to a map for Supabase writes. DATE columns want
  /// a yyyy-MM-dd string, hence the substring.
  Map<String, dynamic> toJson() => {
        'performance_id': performanceId,
        'fund_id': fundId,
        'performance_date':
            performanceDate.toIso8601String().substring(0, 10),
        'annual_return_rate': annualReturnRate,
        'rank_position': rankPosition,
        'created_at': createdAt.toIso8601String(),
      };
}
