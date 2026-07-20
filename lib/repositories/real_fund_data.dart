import '../models/fund_performance.dart';

/// Real-world performance seed data for the 10 funds in `FundCatalog`,
/// covering Jul 2025 – Jun 2026 (June 2026 is the latest month with
/// published figures as of 20 Jul 2026).
///
/// ── DATA PROVENANCE ────────────────────────────────────────────────
/// Figures are GROSS annual returns (% p.a.), but the exact measure differs
/// by fund type, matching what each manager publishes:
///   • MMFs / fixed income → effective annual yield (Kenyan daily-press
///     money-market tables).
///   • Equity / balanced   → trailing 12-month annualised total return
///     (CIC monthly fund fact sheets, gross of fees). Shown side by side
///     the way a fund league table does — "what you earned over a year" —
///     but note it is not the same measure as an MMF yield.
///
/// [R] = Real published figure.
///       MMF/FIF: Vasili Africa monthly Money Market Wrap-Ups (compiled
///       from daily fund disclosures in the Kenyan press).
///       CIC Equity / CIC Balanced: CIC Asset Management monthly fact
///       sheets, "Annualized Fund Performance -> 1 year", gross of fees
///       (ke.cicinsurancegroup.com). 1-year anchors captured:
///         CIC Equity   Nov-25 52.78, Jan-26 55.71, Feb-26 64.87,
///                      Mar-26 53.44, Apr-26 61.38, May-26 49.63,
///                      Jun-26 44.94.
///         CIC Balanced Nov-25 36.64, Feb-26 26.80, Mar-26 20.82,
///                      Apr-26 21.82, May-26 18.50.
/// [I] = Interpolated (linear) between two real anchor months. For CIC
///       Equity/Balanced the Jul–Oct-25 ramp interpolates from the
///       pre-window May-25 fact sheets (Equity 17.42, Balanced 23.70) up
///       to the Nov-25 anchor; Jun-26 balanced extrapolates from May-26.
/// [E] = ESTIMATED, no public monthly series. Britam Equity (7) and NCBA
///       Balanced (10) are NASI-derived (NASI +51.1% in 2025 to 186.58;
///       ~224 by Jun 2026) less a fee/cash-drag haircut. NCBA FIF (5) has
///       one real anchor (7.85% Aug-25); Sanlam FIF (6) publishes no
///       monthly returns (tiny fund, ~KES 99M AUM per CMA Q4-2025).
///       Replace the remaining [E] funds with fact-sheet numbers when
///       available.
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
///   8  CIC Equity     R: Nov-25, Jan-26, Feb-26, Mar-26, Apr-26,
///                        May-26, Jun-26 (7 mo)            | rest I
///   9  CIC Balanced   R: Nov-25, Feb-26, Mar-26, Apr-26,
///                        May-26 (5 mo)                    | rest I
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
    // Funds: 1 CIC MMF · 2 Sanlam MMF · 3 Britam MMF · 4 Etica MMF ·
    //        5 NCBA FIF · 6 Sanlam FIF · 7 Britam EQ · 8 CIC EQ ·
    //        9 CIC BAL · 10 NCBA BAL.  Tags per line: R real, I interp, E est.
    DateTime(2025, 7, 1): {
      1: 8.20, 2: 9.60, 3: 10.50, 4: 11.60, // I
      5: 7.90, 6: 11.00, 7: 30.50, 10: 14.20, // E
      8: 29.21, 9: 28.01, // I (CIC EQ/BAL — interp May-25→Nov-25)
    },
    DateTime(2025, 8, 1): {
      1: 8.05, 2: 9.48, 3: 10.37, 4: 11.44, 5: 7.85, // R
      6: 10.90, 7: 31.20, 10: 14.50, // E
      8: 35.10, 9: 30.17, // I (CIC EQ/BAL)
    },
    DateTime(2025, 9, 1): {
      1: 8.15, 2: 9.41, 3: 10.25, 4: 11.35, // I
      5: 7.80, 6: 10.80, 7: 32.00, 10: 14.70, // E
      8: 40.99, 9: 32.33, // I (CIC EQ/BAL)
    },
    DateTime(2025, 10, 1): {
      1: 8.25, 2: 9.35, 3: 10.12, 4: 11.25, // I
      5: 7.75, 6: 10.70, 7: 33.50, 10: 15.10, // E
      8: 46.89, 9: 34.48, // I (CIC EQ/BAL)
    },
    DateTime(2025, 11, 1): {
      1: 8.35, 2: 9.28, 3: 10.00, // I
      4: 11.15, // R
      5: 7.70, 6: 10.60, 7: 34.80, 10: 15.60, // E
      8: 52.78, 9: 36.64, // R (CIC EQ/BAL fact sheets)
    },
    DateTime(2025, 12, 1): {
      1: 8.45, 2: 9.22, 3: 9.88, // I
      4: 10.99, // R
      5: 7.65, 6: 10.50, 7: 36.50, 10: 16.20, // E
      8: 54.25, 9: 33.36, // I (CIC EQ/BAL)
    },
    DateTime(2026, 1, 1): {
      1: 8.55, 2: 9.15, 3: 9.75, 4: 10.80, // I
      5: 7.60, 6: 10.40, 7: 35.00, 10: 15.70, // E
      8: 55.71, // R (CIC EQ fact sheet)
      9: 30.08, // I (CIC BAL — interp Nov-25→Feb-26)
    },
    DateTime(2026, 2, 1): {
      1: 8.65, 2: 9.09, 3: 9.63, 4: 10.60, // I
      5: 7.60, 6: 10.30, 7: 34.20, 10: 15.30, // E
      8: 64.87, 9: 26.80, // R (CIC EQ/BAL fact sheets)
    },
    DateTime(2026, 3, 1): {
      1: 8.75, 2: 9.02, 3: 9.51, 4: 10.20, // I
      5: 7.55, 6: 10.20, 7: 33.50, 10: 15.00, // E
      8: 53.44, 9: 20.82, // R (CIC EQ/BAL fact sheets)
    },
    DateTime(2026, 4, 1): {
      1: 8.84, // R
      2: 8.96, 3: 9.38, // I
      4: 11.05, // R
      5: 7.55, 6: 10.10, 7: 34.00, 10: 15.20, // E
      8: 61.38, 9: 21.82, // R (CIC EQ/BAL fact sheets)
    },
    DateTime(2026, 5, 1): {
      1: 8.12, 2: 8.89, 3: 9.26, 4: 11.10, // R
      5: 7.50, 6: 10.05, 7: 35.50, 10: 15.70, // E
      8: 49.63, 9: 18.50, // R (CIC EQ/BAL fact sheets)
    },
    DateTime(2026, 6, 1): {
      1: 8.12, 2: 8.58, 3: 9.25, 4: 10.40, // R
      5: 7.50, 6: 10.00, 7: 37.00, 10: 16.20, // E
      8: 44.94, // R (CIC EQ fact sheet)
      9: 17.50, // I (CIC BAL — extrapolated from May-26)
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
