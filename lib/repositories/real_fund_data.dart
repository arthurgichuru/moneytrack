import '../models/fund_performance.dart';

/// Real-world performance seed data for the 10 funds in `FundCatalog`,
/// covering Jul 2025 – Jun 2026 (June 2026 is the latest month with
/// published figures as of 20 Jul 2026).
///
/// ── DATA PROVENANCE ────────────────────────────────────────────────
/// Rates are GROSS effective annual returns (% p.a., before the 15%
/// withholding tax), matching how the Kenyan daily press and fund
/// manager disclosures quote them.
///
/// [R] = Real published figure
///       Source: Vasili Africa monthly Money Market Wrap-Up reports
///       (compiled from daily fund performance disclosures in Kenyan
///       daily newspapers). Full league tables verified for
///       Aug 2025, May 2026 and Jun 2026; single-fund figures for
///       Nov 2025, Dec 2025 and Apr 2026.
/// [I] = Interpolated between two real anchor months (MMFs only —
///       the funds exist in every monthly table, the specific month's
///       page just wasn't retrievable).
/// [E] = ESTIMATED. No public monthly return series exists for these
///       funds. NCBA FIF has one real anchor (7.85% in Aug 2025);
///       Sanlam FIF (KES) publishes no monthly returns (tiny fund,
///       KES 99M AUM per CMA Q4-2025 CIS report). Equity/balanced
///       fund estimates are derived from the NSE rally (NASI +51.1%
///       in 2025 closing at 186.58; +4.42% in Q1 2026 to 194.82;
///       ~229 by mid-Jul 2026) less a haircut for fees and cash drag.
///       Replace with fact-sheet numbers before anything user-facing.
///
/// Per-fund coverage:
///   1  CIC MMF        R: Aug-25, Apr-26, May-26, Jun-26   | rest I
///   2  Sanlam MMF     R: Aug-25, May-26, Jun-26           | rest I
///   3  Britam MMF     R: Aug-25, May-26, Jun-26           | rest I
///   4  Etica MMF      R: Aug-25, Nov-25, Dec-25, Apr-26,
///                        May-26, Jun-26                   | rest I
///   5  NCBA FIF       R: Aug-25                           | rest E
///   6  Sanlam FIF     all E (no published series)
///   7  Britam Equity  all E (NASI-derived)
///   8  CIC Equity     all E (NASI-derived)
///   9  CIC Balanced   all E
///   10 NCBA Balanced  all E
///
/// Market context for sanity-checking: KES MMF industry average was
/// 9.87% gross in Aug 2025, 8.99% in May 2026, 8.92% in Jun 2026
/// (CBK held its policy rate at 8.75% from Feb 2026). Fixed income
/// sector averaged 11.84% in Aug 2025 and 11.87% in Jun 2026.
/// ───────────────────────────────────────────────────────────────────
class RealFundData {
  RealFundData._();

  /// Gross annual return (% p.a.) per fund per month.
  /// Outer key: performance month. Inner key: fundId (as in `FundCatalog`).
  static final Map<DateTime, Map<int, double>> _monthlyGrossReturns = {
    //                      CIC    Sanlam Britam Etica  NCBA   Sanlam Britam CIC    CIC    NCBA
    //                      MMF    MMF    MMF    MMF    FIF    FIF    EQ     EQ     BAL    BAL
    DateTime(2025, 7, 1): {
      1: 8.20, 2: 9.60, 3: 10.50, 4: 11.60, // I
      5: 7.90, 6: 11.00, 7: 30.50, 8: 28.00, 9: 15.50, 10: 14.20, // E
    },
    DateTime(2025, 8, 1): {
      1: 8.05, 2: 9.48, 3: 10.37, 4: 11.44, 5: 7.85, // R
      6: 10.90, 7: 31.20, 8: 28.80, 9: 15.80, 10: 14.50, // E
    },
    DateTime(2025, 9, 1): {
      1: 8.15, 2: 9.41, 3: 10.25, 4: 11.35, // I
      5: 7.80, 6: 10.80, 7: 32.00, 8: 29.50, 9: 16.00, 10: 14.70, // E
    },
    DateTime(2025, 10, 1): {
      1: 8.25, 2: 9.35, 3: 10.12, 4: 11.25, // I
      5: 7.75, 6: 10.70, 7: 33.50, 8: 31.00, 9: 16.50, 10: 15.10, // E
    },
    DateTime(2025, 11, 1): {
      1: 8.35, 2: 9.28, 3: 10.00, // I
      4: 11.15, // R
      5: 7.70, 6: 10.60, 7: 34.80, 8: 32.20, 9: 17.00, 10: 15.60, // E
    },
    DateTime(2025, 12, 1): {
      1: 8.45, 2: 9.22, 3: 9.88, // I
      4: 10.99, // R
      5: 7.65, 6: 10.50, 7: 36.50, 8: 34.00, 9: 17.80, 10: 16.20, // E
    },
    DateTime(2026, 1, 1): {
      1: 8.55, 2: 9.15, 3: 9.75, 4: 10.80, // I
      5: 7.60, 6: 10.40, 7: 35.00, 8: 32.50, 9: 17.20, 10: 15.70, // E
    },
    DateTime(2026, 2, 1): {
      1: 8.65, 2: 9.09, 3: 9.63, 4: 10.60, // I
      5: 7.60, 6: 10.30, 7: 34.20, 8: 31.80, 9: 16.80, 10: 15.30, // E
    },
    DateTime(2026, 3, 1): {
      1: 8.75, 2: 9.02, 3: 9.51, 4: 10.20, // I
      5: 7.55, 6: 10.20, 7: 33.50, 8: 31.00, 9: 16.50, 10: 15.00, // E
    },
    DateTime(2026, 4, 1): {
      1: 8.84, // R
      2: 8.96, 3: 9.38, // I
      4: 11.05, // R
      5: 7.55, 6: 10.10, 7: 34.00, 8: 31.50, 9: 16.70, 10: 15.20, // E
    },
    DateTime(2026, 5, 1): {
      1: 8.12, 2: 8.89, 3: 9.26, 4: 11.10, // R
      5: 7.50, 6: 10.05, 7: 35.50, 8: 33.00, 9: 17.20, 10: 15.70, // E
    },
    DateTime(2026, 6, 1): {
      1: 8.12, 2: 8.58, 3: 9.25, 4: 10.40, // R
      5: 7.50, 6: 10.00, 7: 37.00, 8: 34.50, 9: 17.80, 10: 16.20, // E
    },
  };

  /// Performance rows: one row per fund per month, ranked within each month
  /// (1 = best return that month across the 10 funds).
  static final List<FundPerformance> performance = _build();

  static List<FundPerformance> _build() {
    final rows = <FundPerformance>[];
    var id = 1;

    final months = _monthlyGrossReturns.keys.toList()..sort();
    for (final month in months) {
      final ranked = _monthlyGrossReturns[month]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var i = 0; i < ranked.length; i++) {
        rows.add(FundPerformance(
          performanceId: id++,
          fundId: ranked[i].key,
          performanceDate: month,
          annualReturnRate: ranked[i].value,
          rankPosition: i + 1,
          createdAt: month,
        ));
      }
    }
    return rows;
  }
}
