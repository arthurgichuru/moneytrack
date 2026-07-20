import '../models/fund.dart';
import '../models/fund_category.dart';
import '../models/fund_management_company.dart';

/// In-memory catalog of funds, their categories, and their management
/// companies — the reference data the dummy repositories serve. The monthly
/// performance series lives separately in `RealFundData`.
///
/// In iteration 2 this whole file is deleted — the repositories will fetch
/// the same shapes from Supabase instead. Nothing outside the repositories
/// folder knows this file exists, which is what makes the swap painless.
class FundCatalog {
  FundCatalog._(); // no instances — this is a static data holder

  static final DateTime _seedDate = DateTime(2025, 1, 1);

  /// The four fund categories from the schema.
  static final List<FundCategory> categories = [
    FundCategory(
      categoryId: 1,
      categoryName: 'Money Market',
      categoryDescription:
          'Short-term interest-bearing instruments: T-bills, fixed deposits, commercial paper.',
      riskLevel: 'Low',
      createdAt: _seedDate,
    ),
    FundCategory(
      categoryId: 2,
      categoryName: 'Fixed Income',
      categoryDescription:
          'Government and corporate bonds with medium-term duration.',
      riskLevel: 'Low–Medium',
      createdAt: _seedDate,
    ),
    FundCategory(
      categoryId: 3,
      categoryName: 'Equity',
      categoryDescription:
          'Listed equities, primarily NSE with some regional exposure.',
      riskLevel: 'High',
      createdAt: _seedDate,
    ),
    FundCategory(
      categoryId: 4,
      categoryName: 'Balanced',
      categoryDescription: 'Mixed allocation across equities, bonds and cash.',
      riskLevel: 'Medium',
      createdAt: _seedDate,
    ),
  ];

  /// Five fund managers. Details are illustrative dummy data.
  static final List<FundManagementCompany> companies = [
    FundManagementCompany(
      companyId: 1,
      companyName: 'CIC Asset Management',
      companyDescription: 'Asset management arm of CIC Group.',
      companyWebsite: 'https://cic.co.ke',
      city: 'Nairobi',
      country: 'Kenya',
      email: 'callc@cic.co.ke',
      phone: '+254 703 099 120',
      regulatoryStatus: 'CMA Licensed',
      createdAt: _seedDate,
      updatedAt: _seedDate,
    ),
    FundManagementCompany(
      companyId: 2,
      companyName: 'Sanlam Investments EA',
      companyDescription: 'East African arm of the Sanlam group.',
      companyWebsite: 'https://sanlam.co.ke',
      city: 'Nairobi',
      country: 'Kenya',
      email: 'info@sanlam.co.ke',
      phone: '+254 20 496 7000',
      regulatoryStatus: 'CMA Licensed',
      createdAt: _seedDate,
      updatedAt: _seedDate,
    ),
    FundManagementCompany(
      companyId: 3,
      companyName: 'Britam Asset Managers',
      companyDescription: 'Asset management subsidiary of Britam Holdings.',
      companyWebsite: 'https://britam.com',
      city: 'Nairobi',
      country: 'Kenya',
      email: 'assetmanagement@britam.com',
      phone: '+254 705 100 100',
      regulatoryStatus: 'CMA Licensed',
      createdAt: _seedDate,
      updatedAt: _seedDate,
    ),
    FundManagementCompany(
      companyId: 4,
      companyName: 'NCBA Investment Bank',
      companyDescription:
          'Investment banking and asset management, NCBA Group.',
      companyWebsite: 'https://ncbagroup.com',
      city: 'Nairobi',
      country: 'Kenya',
      email: 'investments@ncbagroup.com',
      phone: '+254 20 288 4444',
      regulatoryStatus: 'CMA Licensed',
      createdAt: _seedDate,
      updatedAt: _seedDate,
    ),
    FundManagementCompany(
      companyId: 5,
      companyName: 'Etica Capital',
      companyDescription: 'Independent digital-first fund manager.',
      companyWebsite: 'https://eticacap.com',
      city: 'Nairobi',
      country: 'Kenya',
      email: 'invest@eticacap.com',
      phone: '+254 748 000 000',
      regulatoryStatus: 'CMA Licensed',
      createdAt: _seedDate,
      updatedAt: _seedDate,
    ),
  ];

  /// Ten funds spread across the categories and companies above.
  static final List<Fund> funds = [
    _fund(
        1,
        'CIC Money Market Fund',
        'CICMMF',
        1,
        1,
        2.0,
        'Flagship KES money market fund.',
        'Capital preservation with competitive short-term yield.'),
    _fund(
        2,
        'Sanlam Money Market Fund',
        'SANMMF',
        2,
        1,
        1.2,
        'Low-cost money market fund.',
        'Maximise current income while preserving capital.'),
    _fund(
        3,
        'Britam Money Market Fund',
        'BRTMMF',
        3,
        1,
        1.5,
        'Money market fund investing in short-dated paper.',
        'Liquidity and stable returns.'),
    _fund(4, 'Etica Money Market Fund', 'ETCMMF', 5, 1, 1.0,
        'Digital-first money market fund.', 'High yield with daily liquidity.'),
    _fund(
        5,
        'NCBA Fixed Income Fund',
        'NCBFIF',
        4,
        2,
        1.8,
        'Bond fund with a bias to infrastructure bonds.',
        'Income generation over the medium term.'),
    _fund(
        6,
        'Sanlam Fixed Income Fund',
        'SANFIF',
        2,
        2,
        1.5,
        'Diversified government and corporate bond fund.',
        'Steady income with moderate duration risk.'),
    _fund(7, 'Britam Equity Fund', 'BRTEQF', 3, 3, 2.5,
        'Equity fund focused on NSE blue chips.', 'Long-term capital growth.'),
    _fund(
        8,
        'CIC Equity Fund',
        'CICEQF',
        1,
        3,
        2.5,
        'Actively managed equity portfolio.',
        'Outperform the NSE 20 over a market cycle.'),
    _fund(9, 'CIC Balanced Fund', 'CICBAL', 1, 4, 2.2,
        'Mixed equities, bonds and cash.', 'Balance of growth and income.'),
    _fund(
        10,
        'NCBA Balanced Fund',
        'NCBBAL',
        4,
        4,
        2.0,
        'Multi-asset fund with tactical allocation.',
        'Real returns above inflation.'),
  ];

  /// Small helper so the fund list above stays readable —
  /// fills in the boilerplate fields every fund shares.
  static Fund _fund(int id, String name, String code, int companyId,
          int categoryId, double fee, String description, String objective) =>
      Fund(
        fundId: id,
        fundName: name,
        fundCode: code,
        companyId: companyId,
        categoryId: categoryId,
        currency: 'KES',
        managementFee: fee,
        description: description,
        investmentObjective: objective,
        createdAt: _seedDate,
        updatedAt: _seedDate,
      );
}
