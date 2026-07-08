import 'controllers/fund_category_controller.dart';
import 'controllers/fund_controller.dart';
import 'controllers/fund_performance_controller.dart';
import 'repositories/fund_category_repository.dart';
import 'repositories/fund_management_company_repository.dart';
import 'repositories/fund_performance_repository.dart';
import 'repositories/fund_repository.dart';

/// Hand-rolled service locator — one place where concrete classes are
/// chosen. Screens/controllers only ever see abstractions.
///
/// Iteration 2 = replace the four `Dummy*Repository()` constructors with
/// `Supabase*Repository(supabaseService)`. Nothing else in the app changes.
class DI {
  DI._(); // static-only, no instances

  // Repositories (data layer)
  static late final FundRepository fundRepository;
  static late final FundCategoryRepository categoryRepository;
  static late final FundManagementCompanyRepository companyRepository;
  static late final FundPerformanceRepository performanceRepository;

  // Controllers (state layer) — created once and shared by all screens,
  // which is what makes signals app-wide state rather than per-widget.
  static late final FundController fundController;
  static late final FundCategoryController categoryController;
  static late final FundPerformanceController performanceController;

  /// Wires the object graph. Called exactly once, from main(), before
  /// runApp — `late final` fields throw if initialised twice, which
  /// conveniently guards against accidental double-init.
  static void init() {
    fundRepository = DummyFundRepository();
    categoryRepository = DummyFundCategoryRepository();
    companyRepository = DummyFundManagementCompanyRepository();
    performanceRepository = DummyFundPerformanceRepository();

    fundController = FundController(fundRepository, companyRepository);
    categoryController = FundCategoryController(categoryRepository);
    performanceController = FundPerformanceController(performanceRepository);
  }
}
