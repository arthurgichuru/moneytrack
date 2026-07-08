import '../models/fund_management_company.dart';
import 'dummy_data.dart';

/// Contract for reading fund management companies.
abstract class FundManagementCompanyRepository {
  /// Returns all active companies, ordered by name.
  Future<List<FundManagementCompany>> getCompanies();
}

/// Iteration-1 implementation backed by [DummyData].
class DummyFundManagementCompanyRepository
    implements FundManagementCompanyRepository {
  @override
  Future<List<FundManagementCompany>> getCompanies() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final list = DummyData.companies.where((c) => c.isActive).toList()
      ..sort((a, b) => a.companyName.compareTo(b.companyName));
    return list;
  }
}
