import '../models/fund_performance.dart';
import 'dummy_data.dart';

/// Contract for reading performance history.
abstract class FundPerformanceRepository {
  /// Full monthly history for one fund, oldest first
  /// (chart-friendly ordering).
  Future<List<FundPerformance>> getPerformanceForFund(int fundId);

  /// The most recent month's return for every fund, as
  /// {fund_id: annual_return_rate}. Powers the badges on the list screen
  /// with a single call instead of N calls.
  Future<Map<int, double>> getLatestReturns();
}

/// Iteration-1 implementation backed by [DummyData].
class DummyFundPerformanceRepository implements FundPerformanceRepository {
  @override
  Future<List<FundPerformance>> getPerformanceForFund(int fundId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final rows = DummyData.performance.where((p) => p.fundId == fundId).toList()
      ..sort((a, b) => a.performanceDate.compareTo(b.performanceDate));
    return rows;
  }

  @override
  Future<Map<int, double>> getLatestReturns() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    // Find the newest performance_date in the table...
    final latestDate = DummyData.performance
        .map((p) => p.performanceDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    // ...then build the {fundId: rate} map for that month only.
    return {
      for (final p in DummyData.performance)
        if (p.performanceDate == latestDate && p.annualReturnRate != null)
          p.fundId: p.annualReturnRate!,
    };
  }
}
