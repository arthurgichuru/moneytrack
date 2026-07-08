import 'package:signals/signals_flutter.dart';

import '../models/fund_performance.dart';
import '../repositories/fund_performance_repository.dart';

/// Owns performance state for two places at once:
///  - the list screen's return badges ([latestReturns], one map for all funds)
///  - the detail screen's chart and stats ([history] for the selected fund)
class FundPerformanceController {
  FundPerformanceController(this._repository);

  final FundPerformanceRepository _repository;

  // ---------------------------------------------------------------- state

  /// {fundId: latest annual return %} — powers the green/red badges on
  /// every row of the funds list.
  final latestReturns = mapSignal<int, double>({});

  /// Monthly history (oldest -> newest) for the fund currently open in
  /// the detail screen. Reused across detail visits.
  final history = listSignal<FundPerformance>([]);

  final isLoadingHistory = signal(false);
  final errorMessage = signal<String?>(null);

  // -------------------------------------------------------------- derived
  // Each of these reads [history], so opening a different fund's detail
  // screen (which reloads history) refreshes all four automatically.

  /// Most recent month's return, or null before data arrives.
  late final latestReturn = computed(
      () => history.value.isEmpty ? null : history.value.last.annualReturnRate);

  /// Simple 12-month average return.
  late final averageReturn = computed(() {
    final rates = history.value
        .map((p) => p.annualReturnRate)
        .whereType<double>()
        .toList();
    if (rates.isEmpty) return null;
    return rates.reduce((a, b) => a + b) / rates.length;
  });

  /// Best (lowest number) league-table rank achieved in the window.
  late final bestRank = computed(() {
    final ranks =
        history.value.map((p) => p.rankPosition).whereType<int>().toList();
    if (ranks.isEmpty) return null;
    return ranks.reduce((a, b) => a < b ? a : b);
  });

  /// Just the return values in date order — exactly what the sparkline
  /// painter needs, so the widget layer does zero data massaging.
  late final chartValues = computed(() => history.value
      .map((p) => p.annualReturnRate)
      .whereType<double>()
      .toList());

  // -------------------------------------------------------------- actions

  /// Loads the one-row-per-fund latest returns map (list screen startup).
  Future<void> loadLatestReturns() async {
    try {
      final map = await _repository.getLatestReturns();
      latestReturns.value = map;
    } catch (e) {
      errorMessage.value = 'Failed to load returns: $e';
    }
  }

  /// Loads the full monthly series for one fund (detail screen).
  /// Clears the previous fund's rows first so stale data never flashes.
  Future<void> loadHistory(int fundId) async {
    isLoadingHistory.value = true;
    errorMessage.value = null;
    history.value = [];
    try {
      history.value = await _repository.getPerformanceForFund(fundId);
    } catch (e) {
      errorMessage.value = 'Failed to load performance: $e';
    } finally {
      isLoadingHistory.value = false;
    }
  }
}
