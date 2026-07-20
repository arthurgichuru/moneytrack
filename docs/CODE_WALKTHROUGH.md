# MoneyTrack — Code Walkthrough

A step-by-step tour of the entire app, built **from the ground up**: we start
at the data layer (models and repositories), climb through the wiring
(dependency injection), into the state layer (controllers), and finish at the
UI (screens). By the end you should be able to trace any pixel on screen back
to the row of data that produced it.

> **How to read this document.** Each section explains *what* a file does,
> *why* it's shaped that way, and *how* it connects to the layer above it.
> Code snippets are quoted from the real files with their line numbers so you
> can open the source alongside.

---

## Table of contents

1. [The big picture](#1-the-big-picture)
2. [A 5-minute primer on signals](#2-a-5-minute-primer-on-signals)
3. [Layer 0 — the models](#3-layer-0--the-models)
4. [Layer 1 — the repositories](#4-layer-1--the-repositories)
5. [Seed data: the fund catalog and the real returns](#5-seed-data-the-fund-catalog-and-the-real-returns)
6. [The wiring — dependency injection](#6-the-wiring--dependency-injection)
7. [Layer 2 — the controllers](#7-layer-2--the-controllers)
8. [Bootstrapping — `main.dart`](#8-bootstrapping--maindart)
9. [Layer 3 — the screens](#9-layer-3--the-screens)
10. [Putting it together — three end-to-end journeys](#10-putting-it-together--three-end-to-end-journeys)
11. [The test, and why it's tiny](#11-the-test-and-why-its-tiny)
12. [Iteration 2 — the Supabase swap](#12-iteration-2--the-supabase-swap)

---

## 1. The big picture

MoneyTrack is a fund-performance browser. It shows a searchable, filterable
list of investment funds; tapping one opens a detail screen with a 12-month
return chart, statistics, and history; a form lets you add or edit funds.

The whole app is built around **one architectural rule**: dependencies point
in a single direction, and each layer only knows about the *abstraction*
directly beneath it.

```
┌──────────────────────────────────────────────────────────────┐
│  SCREENS          funds_list · fund_detail · fund_form         │  UI
│  read state through Watch(), write to signals on interaction   │
└───────────────┬────────────────────────────────────────────────┘
                │ reads .value / calls actions
┌───────────────▼────────────────────────────────────────────────┐
│  CONTROLLERS      FundController · FundCategoryController ·      │  STATE
│                   FundPerformanceController                      │
│  own signals + computed derived state; call repositories        │
└───────────────┬────────────────────────────────────────────────┘
                │ awaits Future<...>
┌───────────────▼────────────────────────────────────────────────┐
│  REPOSITORIES     abstract contracts + Dummy* implementations   │  DATA
│  return models, simulate latency                                │
└───────────────┬────────────────────────────────────────────────┘
                │ constructs
┌───────────────▼────────────────────────────────────────────────┐
│  MODELS + FundCatalog/RealFundData    Fund · FundCategory · …   │  SHAPES
└──────────────────────────────────────────────────────────────────┘

        DI (dependency_injection.dart) wires all of this together once,
        at startup, from main().
```

**Why this matters.** Because the screens and controllers only ever touch
*abstract* repository types, the entire data source can be replaced — dummy
in-memory lists today, a live Supabase backend tomorrow — by changing **four
lines** in one file. We'll see exactly how at the end.

The dependency list is deliberately tiny (`pubspec.yaml`):

```yaml
dependencies:
  signals: ^6.0.2   # reactive state: signal / computed / Watch
  intl: ^0.20.2     # date formatting for the history table
```

No `provider`, no `bloc`, no `riverpod`, no charting library. That's the point
— the app demonstrates that a clean layered design plus signals is enough.

### The same picture, rendered

The diagram below shows the four layers, the write-path (solid, top-down) and
the reactive read-path (dashed, bottom-up), with `DI` wiring the graph once at
startup.

```mermaid
flowchart TB
    subgraph UI["UI · screens/ + main.dart"]
        S1[FundsListScreen]
        S2[FundDetailScreen]
        S3[FundFormScreen]
    end
    subgraph STATE["STATE · controllers/"]
        C1[FundController]
        C2[FundCategoryController]
        C3[FundPerformanceController]
    end
    subgraph DATA["DATA · repositories/ (abstract contracts)"]
        R1[FundRepository]
        R2[FundCategoryRepository]
        R3[FundManagementCompanyRepository]
        R4[FundPerformanceRepository]
    end
    subgraph SHAPES["SHAPES · models/ + FundCatalog + RealFundData"]
        M[Fund · FundCategory · FundManagementCompany · FundPerformance]
    end

    UI -- "read .value via Watch()" --> STATE
    STATE -- "call actions (write signals)" --> UI
    STATE -- "await Future&lt;...&gt;" --> DATA
    DATA -- "construct / return" --> SHAPES

    DI([DI.init · service locator]) -. "builds once at startup" .-> STATE
    DI -. "chooses Dummy* impls" .-> DATA

    classDef layer fill:#e8f5f2,stroke:#00695c,color:#003d33;
    class UI,STATE,DATA,SHAPES layer;
    classDef di fill:#fff3e0,stroke:#e65100,color:#5c2c00;
    class DI di;
```

The key visual truth: arrows into `DATA` and `SHAPES` only ever point at the
**abstract** boxes. No screen or controller has an edge to a `Dummy*` class —
that's why `DI` can repoint them at Supabase without anything above noticing.

---

## 2. A 5-minute primer on signals

Every layer above the repositories speaks in terms of **signals**, so it's
worth understanding them before reading any controller or screen. There are
only three concepts.

### `signal(x)` — a reactive value

A `signal` is a box holding a value. You read it with `.value` and write it
with `.value = ...`. The magic: anything that *read* the signal is
automatically remembered as a dependency, and re-runs when the value changes.

```dart
final searchQuery = signal('');      // create
searchQuery.value;                   // read  -> ''
searchQuery.value = 'money market';  // write -> notifies all readers
```

There are typed collection variants used in this codebase:

- `listSignal<T>([])` — a signal wrapping a `List<T>` with helpers like
  `.add(...)` that mutate **and** notify in one call.
- `mapSignal<K,V>({})` — the same idea for a `Map`.

### `computed(() => ...)` — derived state

A `computed` is a value *calculated* from other signals. It re-evaluates only
when a signal it actually read has changed, and caches its result otherwise.
You never set a computed; you only read its `.value`.

```dart
late final filteredFunds = computed(() {
  // reads funds, searchQuery, selectedCategoryId…
  // …so it recomputes whenever any of those three change.
});
```

This is the workhorse of the app: search, filtering, chart data, statistics,
and lookup tables are all `computed` values that maintain themselves.

### `Watch((context) => ...)` — a reactive widget

`Watch` is a Flutter widget whose builder re-runs when any signal it reads
changes. Crucially, it rebuilds **only its own subtree**, not the whole
screen. This replaces `setState`, `StreamBuilder`, and manual listeners.

```dart
Watch((context) {
  final funds = _fundController.filteredFunds.value; // subscribe
  return ListView(...);                              // rebuilds on change
});
```

**Mental model for the entire app:**
> Widgets *write* to signals on user interaction → `computed` values recalculate
> → `Watch` widgets that read them repaint. No glue code in between.

```mermaid
flowchart LR
    A["User interaction<br/>(type, tap, save)"] -->|"signal.value = x"| B([writable signal])
    B -->|"auto-tracked read"| C([computed<br/>re-evaluates])
    C -->|"read inside builder"| D["Watch()<br/>repaints its subtree"]
    D -.->|"user acts again"| A

    classDef sig fill:#e8f5f2,stroke:#00695c,color:#003d33;
    class B,C sig;
    classDef ui fill:#fff3e0,stroke:#e65100,color:#5c2c00;
    class A,D ui;
```

Keep this loop in mind; every screen is an instance of it.

---

## 3. Layer 0 — the models

**Files:** `lib/models/fund.dart`, `fund_category.dart`,
`fund_management_company.dart`, `fund_performance.dart`

Models are plain Dart classes that mirror the Postgres tables **column for
column**. They are the "shapes" that flow up through every layer.

The four tables and their relationships (this is the schema iteration 2's
Supabase database will mirror exactly):

```mermaid
erDiagram
    FUND_MANAGEMENT_COMPANIES ||--o{ FUNDS : "manages"
    FUND_CATEGORIES           ||--o{ FUNDS : "classifies"
    FUNDS                     ||--o{ FUND_PERFORMANCE : "has monthly"

    FUND_MANAGEMENT_COMPANIES {
        int company_id PK
        string company_name
        string regulatory_status
        bool is_active
    }
    FUND_CATEGORIES {
        int category_id PK
        string category_name
        string risk_level
    }
    FUNDS {
        int fund_id PK
        string fund_name
        string fund_code
        int company_id FK
        int category_id FK
        double management_fee
        bool is_active
    }
    FUND_PERFORMANCE {
        int performance_id PK
        int fund_id FK
        date performance_date
        double annual_return_rate
        int rank_position
    }
```

A `Fund` carries two nullable foreign keys — `company_id` and `category_id` —
which the UI resolves into a manager name and a category label via the
controllers' `companiesById` / `categoriesById` lookup maps. Each fund fans out
to twelve `FundPerformance` rows (one per month), which power the detail
screen's chart, stats and history. Four rules are followed by all of the
models:

1. **All fields are `final`** — models are immutable. State can only change by
   building a *new* object, never by mutating an existing one. This is what
   makes signal change-detection reliable (a new object reference = a real
   change).
2. **`fromJson` / `toJson` use the exact Supabase column names** (`fund_id`,
   `management_fee`, …). Because the dummy data and the future Supabase rows
   share these key names, the models deserialize identically from either
   source.
3. **Nullable vs. required mirrors the schema's `NOT NULL` constraints.**
4. **Numeric coercion is explicit** — Postgres `NUMERIC` decodes as `num`, so
   fees/rates are normalised with `(json['x'] as num?)?.toDouble()`.

### 3.1 `Fund` — the central entity

`Fund` is the star of the app: the list shows funds, the detail screen shows
one, the form creates/edits one. Its fields (`fund.dart:4-24`):

```dart
final int fundId;           // primary key
final String fundName;      // NOT NULL
final String? fundCode;     // ticker-style, e.g. "CICMMF"
final int? companyId;       // FK -> fund_management_companies
final int? categoryId;      // FK -> fund_categories
final String? currency;
final double? managementFee; // 2.0 == 2.0% p.a.
final String? description;
final String? investmentObjective;
final bool isActive;        // soft-delete flag
final DateTime createdAt;
final DateTime updatedAt;
```

The two foreign keys (`companyId`, `categoryId`) are the joins that the UI
resolves later into a manager name and a category label.

#### `copyWith` — the immutability workhorse (`fund.dart:77-103`)

```dart
Fund copyWith({ int? fundId, String? fundName, /* … */ DateTime? updatedAt }) =>
    Fund(
      fundId: fundId ?? this.fundId,
      fundName: fundName ?? this.fundName,
      // …
      createdAt: createdAt,                 // never changes
      updatedAt: updatedAt ?? DateTime.now(),
    );
```

Since you can't mutate a `Fund`, `copyWith` is how edits happen: produce a new
`Fund` with a few fields replaced. Note two deliberate details:

- `createdAt` is **not** a parameter — creation time is set once and preserved.
- `updatedAt` defaults to `DateTime.now()`, so every copy is automatically
  timestamped. This mirrors an `updated_at` trigger in a database.

This method is used by the repository (to stamp a new id on create) and by the
controller (to flip `isActive` on delete). Watch for it below.

### 3.2 The supporting models

- **`FundCategory`** (`fund_category.dart`) — id, name, description, and a
  free-text `riskLevel` ("Low", "High", …). Four of these exist (Money Market,
  Fixed Income, Equity, Balanced).
- **`FundManagementCompany`** (`fund_management_company.dart`) — the fund
  manager: name, contact details, and `regulatoryStatus` ("CMA Licensed").
  Shown on the detail screen's manager card.
- **`FundPerformance`** (`fund_performance.dart`) — **one row per fund per
  month**: `performanceDate`, `annualReturnRate` (e.g. `13.42` = 13.42% p.a.),
  and `rankPosition` (1 = best fund that month). Twelve of these per fund power
  the chart, the statistics, and the history table.

One nice detail in `FundPerformance.toJson` (`fund_performance.dart:43`): a
`DATE` column wants `yyyy-MM-dd`, so it truncates the ISO timestamp:

```dart
'performance_date': performanceDate.toIso8601String().substring(0, 10),
```

**Takeaway:** models carry no logic beyond serialization and `copyWith`. They
are dumb data. All behaviour lives above them.

---

## 4. Layer 1 — the repositories

**Files:** `lib/repositories/fund_repository.dart`,
`fund_category_repository.dart`, `fund_management_company_repository.dart`,
`fund_performance_repository.dart`

Each repository is **two things in one file**:

1. An `abstract class` — the *contract* the rest of the app depends on.
2. A `Dummy…` class — the iteration-1 *implementation* backed by in-memory
   lists.

This split is the linchpin of the whole architecture. Controllers import and
hold the abstract type; they have no idea whether the data comes from a list or
a network. Let's read each one.

### 4.1 `FundRepository` — the only read/write repository

Funds are the only entity the user can create and edit, so this contract is the
richest (`fund_repository.dart:6-20`):

```dart
abstract class FundRepository {
  Future<List<Fund>> getFunds();          // read all (active + inactive)
  Future<Fund> createFund(Fund fund);     // insert, returns row w/ new id
  Future<Fund> updateFund(Fund fund);     // update, returns stored version
  Future<void> deactivateFund(int fundId);// SOFT delete (is_active = false)
}
```

Two design decisions are baked into the contract itself:

- **`getFunds()` returns *everything*, active or not.** The repository doesn't
  decide what's visible — the controller's `filteredFunds` does. Keeping the
  filter in the state layer means the same fetched data can be filtered many
  ways without re-hitting the data source.
- **Delete is a soft delete.** Real financial systems rarely hard-delete
  records that have history hanging off them (here, `fund_performance` rows
  cascade from a fund). So `deactivateFund` flips a flag rather than removing a
  row — exactly what the Supabase version will do.

#### The dummy implementation (`fund_repository.dart:25-68`)

```dart
class DummyFundRepository implements FundRepository {
  // A PRIVATE copy of the seed list, so create/update/delete behave like a
  // real backend for the app session without mutating the shared seed data.
  final List<Fund> _funds = List<Fund>.from(FundCatalog.funds);

  int get _nextId =>
      _funds.map((f) => f.fundId).fold(0, (a, b) => a > b ? a : b) + 1;
```

Line-by-line reasoning:

- **The private working copy** (`_funds`) is critical. If the repository
  mutated `FundCatalog.funds` directly, every repository instance (and the test)
  would share and corrupt the same list. Copying on construction isolates state.
- **`_nextId`** computes `max(existing ids) + 1`, imitating a Postgres `SERIAL`
  column so newly created funds get realistic sequential ids.

Each method **awaits an artificial delay** before doing its work:

```dart
Future<List<Fund>> getFunds() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  return List<Fund>.unmodifiable(_funds);   // callers can't mutate our state
}
```

The 250–350ms delays exist so the app's **loading spinners are actually
visible** — without them the dummy data would return instantly and you'd never
see the async states the UI is built to handle. Returning an *unmodifiable*
view is another defensive touch: callers get the data but can't reach in and
change the repository's internals.

`createFund` shows `copyWith` doing its job (`fund_repository.dart:41-47`):

```dart
final created = fund.copyWith(fundId: _nextId, updatedAt: DateTime.now());
_funds.add(created);
return created;   // caller gets the server-assigned id back
```

`updateFund` finds the row by id and replaces it (throwing `StateError` if the
id is unknown), and `deactivateFund` replaces the row with
`copyWith(isActive: false)`. Notice **nothing is ever mutated in place** — even
here in the "database", every change produces a new immutable `Fund`.

### 4.2 The three read-only repositories

The other three follow the same abstract-plus-dummy shape but only expose
reads.

**`FundCategoryRepository`** (`fund_category_repository.dart`) — returns all
categories sorted by name:

```dart
final list = List<FundCategory>.from(FundCatalog.categories)
  ..sort((a, b) => a.categoryName.compareTo(b.categoryName));
```

(It copies the list *before* sorting so it never reorders the shared seed.)

**`FundManagementCompanyRepository`** — returns only **active** companies,
sorted by name, using a `.where((c) => c.isActive)` filter.

**`FundPerformanceRepository`** is the most interesting of the three because it
exposes **two differently-shaped reads** for two different screens
(`fund_performance_repository.dart:5-14`):

```dart
abstract class FundPerformanceRepository {
  // Full monthly history for ONE fund, oldest-first (chart-friendly).
  Future<List<FundPerformance>> getPerformanceForFund(int fundId);

  // Latest month's return for EVERY fund, as {fundId: rate}. One call feeds
  // all the badges on the list screen instead of N calls.
  Future<Map<int, double>> getLatestReturns();
}
```

`getPerformanceForFund` filters to one fund and sorts oldest→newest, which is
exactly the order the area-chart painter wants (left = oldest, right = newest).

Both methods read from **`RealFundData.performance`** — the one place in the app
backed by *real* published figures rather than the illustrative catalog (see
§5). `getLatestReturns` is a small aggregation (`fund_performance_repository.dart`):

```dart
final latestDate = RealFundData.performance
    .map((p) => p.performanceDate)
    .reduce((a, b) => a.isAfter(b) ? a : b);          // newest month in table
return {
  for (final p in RealFundData.performance)
    if (p.performanceDate == latestDate && p.annualReturnRate != null)
      p.fundId: p.annualReturnRate!,                  // {fundId: rate}
};
```

It finds the most recent month across the whole table, then builds a
`{fundId: rate}` map for just that month. The list screen uses this single map
to render the return pill on every row — an O(1) lookup per row instead of a
fetch per fund.

**Takeaway:** repositories define *what data operations exist* (the abstract
class) and *where the data currently comes from* (the dummy class — catalog for
funds, `RealFundData` for performance). The seam between those two is where
iteration 2 will cut.

---

## 5. Seed data: the fund catalog and the real returns

The in-memory data comes from **two** static-only holders, split by *what kind*
of data they hold — reference data vs. the performance series:

- **`FundCatalog`** (`lib/repositories/fund_catalog.dart`) — the catalog of
  funds, their categories, and their management companies (illustrative sample
  records).
- **`RealFundData`** (`lib/repositories/real_fund_data.dart`) — the monthly
  return series, sourced from *real* published figures.

Both are deleted in iteration 2 (their shapes come from Supabase instead), and
nothing outside `repositories/` knows either exists.

### 5.1 `FundCatalog` — the reference catalog

A static-only holder (`FundCatalog._();` forbids instances) seeding three
things:

- **4 categories** (`fund_catalog.dart`) — Money Market, Fixed Income, Equity,
  Balanced, each with a risk level.
- **5 companies** — realistic Kenyan fund managers, all "CMA Licensed".
- **10 funds** — built via a private `_fund(...)` helper that fills in the
  fields every fund shares (currency `KES`, timestamps), keeping the list
  readable.

That's *all* it holds — identity and relationships, no returns. This is the file
`DummyFundRepository`, `DummyFundCategoryRepository`, and
`DummyFundManagementCompanyRepository` read from.

### 5.2 `RealFundData` — the real monthly performance

Performance is the one thing in the app backed by **real published data**, so it
lives on its own. `RealFundData` holds a `Map<DateTime, Map<int, double>>` — for
each month (Jul 2025 – Jun 2026), the gross annual return (% p.a.) per fund id:

```dart
static final Map<DateTime, Map<int, double>> _monthlyGrossReturns = {
  //                      CIC   Sanlam Britam Etica  NCBA  …
  DateTime(2026, 6, 1): {
    1: 8.12, 2: 8.58, 3: 9.25, 4: 10.40, // R = real published figures
    5: 7.50, 6: 10.00, 7: 37.00, 8: 34.50, 9: 17.80, 10: 16.20, // E = estimated
  },
  // … 11 more months …
};
```

The file's header documents **provenance** for every number, tagged inline:
`[R]` real published figure (from Vasili Africa's monthly Money Market Wrap-Ups,
compiled from Kenyan daily-press fund disclosures), `[I]` interpolated between
two real anchor months (MMFs only), and `[E]` estimated (equity/balanced funds,
which publish no monthly series — derived from the NSE rally less a fee/cash-drag
haircut). The money-market figures are largely real; the rest is clearly flagged
as illustrative and slated for replacement with fact-sheet numbers.

`_build()` turns that map into the `FundPerformance` rows the repositories serve
— and this is where the **ranking** happens (`real_fund_data.dart`):

```dart
static List<FundPerformance> _build() {
  final rows = <FundPerformance>[];
  var id = 1;
  final months = _monthlyGrossReturns.keys.toList()..sort();   // oldest first
  for (final month in months) {
    final ranked = _monthlyGrossReturns[month]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));            // best return first
    for (var i = 0; i < ranked.length; i++) {
      rows.add(FundPerformance(
        performanceId: id++,
        fundId: ranked[i].key,
        performanceDate: month,
        annualReturnRate: ranked[i].value,
        rankPosition: i + 1,        // 1-based league position that month
        createdAt: month,
      ));
    }
  }
  return rows;
}
```

Each month's returns are sorted descending and assigned `rankPosition` 1..10,
exactly like a published fund league table — that's the number the detail
screen's "Best rank" stat mines. The result is exposed as the public static
`RealFundData.performance`, which the performance repository reads (§4.2).

> **Historical note.** Earlier iterations *generated* this series
> deterministically (a per-fund seeded RNG jittering around a per-category base
> rate). That generator was replaced by the real data above; the ranking and
> row shape are identical, so nothing downstream changed.

**Takeaway:** the data layer is now complete. Models define shapes, `FundCatalog`
supplies the reference catalog and `RealFundData` the real returns, and
repositories serve both behind abstract contracts. Everything above this line is
pure Dart with zero Flutter — and could be unit-tested as such.

---

## 6. The wiring — dependency injection

**File:** `lib/dependency_injection.dart`

We have contracts and implementations; something has to decide *which*
implementation to use and *construct the object graph*. That's `DI` — a
hand-rolled service locator (no external DI package needed).

```dart
class DI {
  DI._(); // static-only, no instances

  // Data layer — declared as the ABSTRACT types.
  static late final FundRepository fundRepository;
  static late final FundCategoryRepository categoryRepository;
  static late final FundManagementCompanyRepository companyRepository;
  static late final FundPerformanceRepository performanceRepository;

  // State layer — one shared instance of each controller.
  static late final FundController fundController;
  static late final FundCategoryController categoryController;
  static late final FundPerformanceController performanceController;

  static void init() {
    fundRepository = DummyFundRepository();                    // <-- the only
    categoryRepository = DummyFundCategoryRepository();        //     place the
    companyRepository = DummyFundManagementCompanyRepository();//     CONCRETE
    performanceRepository = DummyFundPerformanceRepository();  //     classes
                                                               //     appear
    fundController = FundController(fundRepository, companyRepository);
    categoryController = FundCategoryController(categoryRepository);
    performanceController = FundPerformanceController(performanceRepository);
  }
}
```

Every detail here is deliberate:

- **Fields are typed as the abstract classes** (`FundRepository`, not
  `DummyFundRepository`). The rest of the app can only see the contract, so it
  physically *cannot* depend on dummy-specific behaviour.
- **`init()` is the single spot where concrete classes are named.** This is the
  "seam." Iteration 2 swaps these four constructors for `Supabase*` ones and
  the app is done — no screen or controller changes.
- **Controllers are created once and stored statically.** Because there's
  exactly one `FundController` for the whole app, the signals inside it are
  effectively *app-wide state*. Two different screens reading
  `DI.fundController.funds` see the same list. (If each screen made its own
  controller, signals would be per-widget and nothing would stay in sync.)
- **`late final` doubles as a guard.** A `late final` field throws if written
  twice, so an accidental second `DI.init()` fails loudly instead of silently
  rebuilding the graph.

**Takeaway:** `DI` is the knot that ties data to state. It's small on purpose —
its whole value is *centralizing the one decision* that changes between
iterations.

---

## 7. Layer 2 — the controllers

**Files:** `lib/controllers/fund_controller.dart`,
`fund_category_controller.dart`, `fund_performance_controller.dart`

Controllers own the app's state as signals and expose actions that call
repositories. They are the bridge between "data at rest" (repositories) and
"data on screen" (widgets). No controller imports Flutter's `material.dart` —
they're pure Dart, which is why the test can drive them with no widgets.

Every controller follows the same three-part shape:
**state (signals) → derived (computed) → actions (async methods)**.

### 7.1 `FundCategoryController` — the simplest one, read it first

Because it's the smallest, it's the clearest illustration of the pattern
(`fund_category_controller.dart`):

```dart
class FundCategoryController {
  FundCategoryController(this._repository);
  final FundCategoryRepository _repository;   // the ABSTRACT type

  // --- state ---
  final categories = listSignal<FundCategory>([]);
  final isLoading = signal(false);
  final errorMessage = signal<String?>(null);

  // --- derived ---
  late final categoriesById = computed(
    () => {for (final c in categories.value) c.categoryId: c},
  );

  // --- action ---
  Future<void> loadCategories() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      categories.value = await _repository.getCategories();
    } catch (e) {
      errorMessage.value = 'Failed to load categories: $e';
    } finally {
      isLoading.value = false;   // <-- always runs, even on error
    }
  }
}
```

Things to notice, because **every controller repeats them**:

- **The `isLoading` / `errorMessage` / data triad.** Three signals fully
  describe an async operation's state, and the UI switches on them
  (spinner → error → data).
- **The `try/catch/finally` shape.** `finally` guarantees `isLoading` returns
  to `false` no matter what, so the UI can never get stuck on a spinner.
- **`categoriesById` is a `computed` lookup table.** Screens need to turn a
  `categoryId` into a category name constantly. Rather than scan the list every
  time, this computed builds a `{id: category}` map — and because it's
  `computed`, it only rebuilds when `categories` actually changes, so screens
  can read it every frame for free.

### 7.2 `FundController` — the heart of the app

This controller owns the fund list, the search text, and the active filter, and
derives the filtered result. It's where the app's core interaction lives.

**State** (`fund_controller.dart:16-32`):

```dart
final funds = listSignal<Fund>([]);                  // unfiltered source of truth
final companies = listSignal<FundManagementCompany>([]); // for manager names
final isLoading = signal(false);
final errorMessage = signal<String?>(null);
final searchQuery = signal('');                      // bound to the search box
final selectedCategoryId = signal<int?>(null);       // null = "All"
```

**Derived** — two computed values (`fund_controller.dart:37-62`):

```dart
// {companyId: company} for O(1) manager-name lookups in list rows.
late final companiesById = computed(
  () => {for (final c in companies.value) c.companyId: c},
);

// THE core computed: active funds matching BOTH search text AND category,
// sorted by name. Reads three signals, so changing any one recomputes it.
late final filteredFunds = computed(() {
  final query = searchQuery.value.trim().toLowerCase();
  final categoryId = selectedCategoryId.value;

  final result = funds.value.where((fund) {
    if (!fund.isActive) return false;                 // hide soft-deleted
    final matchesCategory = categoryId == null || fund.categoryId == categoryId;
    final matchesQuery = query.isEmpty ||
        fund.fundName.toLowerCase().contains(query) ||
        (fund.fundCode?.toLowerCase().contains(query) ?? false);
    return matchesCategory && matchesQuery;
  }).toList()
    ..sort((a, b) => a.fundName.compareTo(b.fundName));
  return result;
});
```

`filteredFunds` is the single most important line of reactive plumbing in the
app. It reads **three** signals — `funds`, `searchQuery`, `selectedCategoryId`
— so a keystroke in the search box, a chip tap, or a data reload each trigger a
recompute, and only the list widget watching it repaints. The search feature,
the category filter, and the hide-deleted-funds behaviour are *all* expressed
in this one pure function. There is no imperative "when the user types, filter
the list" code anywhere — the dependency graph does it.

**Actions.** Three async methods drive the state:

`loadFunds()` fetches funds and companies **in parallel**
(`fund_controller.dart:68-83`):

```dart
final results = await Future.wait([
  _fundRepository.getFunds(),
  _companyRepository.getCompanies(),
]);
funds.value = results[0] as List<Fund>;
companies.value = results[1] as List<FundManagementCompany>;
```

`Future.wait` runs both fetches concurrently — one spinner, roughly half the
wait versus doing them sequentially.

`saveFund()` is a **create-or-update in one entry point**
(`fund_controller.dart:88-111`). The convention: `fundId == 0` means "not yet
persisted", so it's a create; otherwise it's an update.

```dart
if (fund.fundId == 0) {
  final created = await _fundRepository.createFund(fund);
  funds.add(created);                    // listSignal.add: mutate + notify
} else {
  final updated = await _fundRepository.updateFund(fund);
  funds.value = funds.value
      .map((f) => f.fundId == updated.fundId ? updated : f)
      .toList();                          // rebuild list -> notify watchers
}
return true;                             // tells the form whether to pop
```

Note the two ways of notifying watchers: `.add()` mutates-and-notifies in one
call, whereas the update path builds a **new list** and reassigns `.value`
(reassignment is what a signal detects as a change). Either way, `filteredFunds`
recomputes and the list repaints — instantly, without re-fetching from the
repository.

`deactivateFund()` does the same trick for delete: it calls the repository, then
**mirrors the change locally** with `copyWith(isActive: false)` rather than
re-fetching the whole list (`fund_controller.dart:115-124`). Cheaper, and the
row vanishes from the UI immediately because `filteredFunds` drops inactive
funds.

### 7.3 `FundPerformanceController` — one controller, two audiences

This controller feeds **two screens at once** and is a great example of
`computed` doing the heavy lifting (`fund_performance_controller.dart`).

**State:**

```dart
final latestReturns = mapSignal<int, double>({});   // {fundId: %} for LIST badges
final history = listSignal<FundPerformance>([]);     // series for the OPEN fund
final isLoadingHistory = signal(false);
final errorMessage = signal<String?>(null);
```

**Derived** — four computeds, *all reading `history`*
(`fund_performance_controller.dart:32-58`):

```dart
late final latestReturn = computed(
    () => history.value.isEmpty ? null : history.value.last.annualReturnRate);

late final averageReturn = computed(() {
  final rates = history.value.map((p) => p.annualReturnRate)
      .whereType<double>().toList();
  if (rates.isEmpty) return null;
  return rates.reduce((a, b) => a + b) / rates.length;
});

late final bestRank = computed(() {
  final ranks = history.value.map((p) => p.rankPosition)
      .whereType<int>().toList();
  if (ranks.isEmpty) return null;
  return ranks.reduce((a, b) => a < b ? a : b);      // lowest number = best
});

late final chartValues = computed(() => history.value
    .map((p) => p.annualReturnRate).whereType<double>().toList());
```

Here's the payoff: `loadHistory(fundId)` sets `history` **once**, and all four
of these recompute automatically. The detail screen's three stat tiles and its
chart never call the repository themselves — they just read these computeds.
Open a different fund, `history` changes, and every derived value refreshes in
lockstep. `chartValues` in particular hands the painter a clean `List<double>`
so the widget layer does *zero* data massaging.

**Actions:**

- `loadLatestReturns()` — fills the `{fundId: rate}` map for the list badges.
- `loadHistory(fundId)` — loads one fund's 12-month series. Note it **clears
  `history` first** (`history.value = []`) so the previous fund's data never
  flashes on screen while the new fund loads (`fund_performance_controller.dart:74-85`).

**Takeaway:** controllers turn repository calls into reactive state. The pattern
is identical everywhere: a few signals for raw state, `computed` values for
anything derived, and thin async actions that only touch signals and abstract
repositories.

---

## 8. Bootstrapping — `main.dart`

**File:** `lib/main.dart`

With every layer defined, `main()` assembles and launches them. **Order
matters**, and the comments spell it out (`main.dart:12-17`):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 1. required before async pre-runApp
  await SupabaseService.init();              // 2. no-op today, real init later
  DI.init();                                 // 3. build repos + controllers once
  runApp(const MoneyTrackApp());             // 4. now every screen can read DI.*
}
```

By the time `runApp` executes, the controllers exist and hold empty signals; the
screens will *trigger* the data loads themselves in their `initState`. So the
first frame renders instantly with spinners, and data pops in as it arrives.

`SupabaseService` (`lib/services/supabase_service.dart`) is currently a
deliberate no-op — a placeholder whose doc comment sketches the iteration-2
`Supabase.initialize(...)` call. It exists now so the startup sequence already
has the right shape; iteration 2 fills in the body without touching `main()`'s
structure.

The root widget `MoneyTrackApp` (`main.dart:21-55`) is intentionally thin: a
`MaterialApp` with a Material 3 theme and `home: FundsListScreen()`. All state
lives in controllers; all UI lives in screens; the root just wires a theme and
the first route.

The theme itself is a **Binance-style light theme** — white surfaces, black
text, a gold accent (`0xFFF0B90B`), and a flat white app bar with no elevation:

```dart
const gold = Color(0xFFF0B90B);
theme: ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.light)
      .copyWith(surface: Colors.white),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white, foregroundColor: Colors.black,
    elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 22,
        fontWeight: FontWeight.bold),
  ),
);
```

The green/red gain-loss colours aren't in the global theme — they're per-screen
design tokens (`_kGreen`, `_kRed`, `_kGold`, …) declared at the top of each
screen file, so the reactive widgets can pick a colour from a value at build
time. Keep this "theme vs. tokens" split in mind as you read the screens.

---

## 9. Layer 3 — the screens

**Files:** `lib/screens/funds_list_screen.dart`, `fund_detail_screen.dart`,
`fund_form_screen.dart`

Now the top of the stack. The guiding principle: **screens hold almost no state
of their own.** They read from controllers via `Watch` and write to controller
signals on interaction. Each screen grabs its controllers from `DI` once:

```dart
final _fundController = DI.fundController;
final _categoryController = DI.categoryController;
final _performanceController = DI.performanceController;
```

### 9.1 `FundsListScreen` — the home screen

**Kicking off the loads** (`funds_list_screen.dart:28-34`). The screen is a
`StatefulWidget` purely so it can trigger loads in `initState`:

```dart
@override
void initState() {
  super.initState();
  _fundController.loadFunds();            // note: NOT awaited
  _categoryController.loadCategories();
  _performanceController.loadLatestReturns();
}
```

These are fired without `await`. They write into signals when they finish, and
the `Watch` widgets below repaint themselves — so there's no need to await or
`setState`. The screen builds immediately; the data catches up.

> **The redesign, and why the walkthrough barely changes.** The list, detail,
> and form screens were later restyled into a Binance-style markets view. This
> is worth pausing on: the visual overhaul touched **only the widget tree** —
> every controller, signal, and `computed` stayed exactly the same. The screens
> still read the same signals and write the same ones on interaction. That a
> full reskin was possible without opening a single controller file is the
> clearest practical proof of the layered design: presentation and state are
> genuinely decoupled. The sections below describe the current (redesigned) UI.

**The layout** is a `Column` (`funds_list_screen.dart:72-80`) of four pieces: a
search row, a gold-underlined category-tab strip, a column header, and the fund
list filling the rest. Design tokens (`_kGold`, `_kGreen`, `_kRed`,
`_kCategoryColors`, `_kStrongReturn = 10.0`, …) sit at the top of the file
(`:9-31`).

**The search row** (`funds_list_screen.dart:86`) is where the reactive model
shines. Its entire behaviour is one line:

```dart
onChanged: (text) => _fundController.searchQuery.value = text,
```

That's the whole search feature. Typing writes to `searchQuery` →
`filteredFunds` recomputes → the list repaints. No debounce logic, no listener,
no filtering code in the widget. The `TextField` itself isn't wrapped in a
`Watch` — it only *writes*, it doesn't *read* a signal, so it never rebuilds.
Beside it sits a "…" `IconButton` that clears both the search text and the
category selection in one tap (`:117-120`) — two signal writes, and the list
falls back to showing everything.

**The category tabs** replaced the old chips with gold-underlined tabs
(`funds_list_screen.dart:130`, rendered by the `_CategoryTab` widget at `:232`),
but the reactive shape is identical — still one `Watch` reading two signals:

```dart
Watch((context) {
  final categories = _categoryController.categories.value;  // async-loaded
  final selectedId = _fundController.selectedCategoryId.value;
  return ListView(scrollDirection: Axis.horizontal, children: [
    _CategoryTab(label: 'All', selected: selectedId == null,
      onTap: () => _fundController.selectedCategoryId.value = null),
    for (final category in categories)
      _CategoryTab(
        label: category.categoryName,
        selected: selectedId == category.categoryId,
        // tapping the active tab clears the filter (toggle)
        onTap: () => _fundController.selectedCategoryId.value =
            selectedId == category.categoryId ? null : category.categoryId),
  ]);
});
```

`_CategoryTab` is a pure presentation widget: the label goes bold black with a
gold underline when `selected`, muted grey otherwise. Because the builder reads
both `categories` and `selectedCategoryId`, the strip appears when categories
finish loading **and** restyles when the selection changes. Tapping a tab writes
`selectedCategoryId`, which — again — recomputes `filteredFunds` and repaints
the list. A static `_buildColumnHeader` (`:163`) prints the `Name / Manager ·
Latest · Return` labels, aligned to the row columns via shared width constants
(`_kNumberCol`, `_kPillCol`).

**The list body** handles all four async states in one `Watch`
(`funds_list_screen.dart:186`), read top to bottom as a priority ladder:

```dart
Watch((context) {
  if (isLoading && funds.isEmpty) return CircularProgressIndicator();  // 1 loading
  if (error != null)              return <error + Retry button>;       // 2 error
  final funds = filteredFunds.value;
  if (funds.isEmpty)              return Text('No funds match…');       // 3 empty
  return RefreshIndicator(child: ListView.builder(...));               // 4 data
});
```

The loading check is `isLoading && funds.isEmpty` — so the spinner only shows on
the *first* load, not on a pull-to-refresh when we already have data to display.
The data case wraps a `ListView.builder` in a `RefreshIndicator` whose `onRefresh`
re-runs both `loadFunds()` and `loadLatestReturns()`.

**A single row — `_FundTile`** (`funds_list_screen.dart:280`) is split into its
own widget so each row rebuilds independently. It has its own `Watch`, and now
renders a three-column flat row — avatar + ticker/name·manager, a latest-return
+ fee number block, and a solid return pill:

```dart
Watch((context) {
  final company = fundController.companiesById.value[fund.companyId];
  final latestReturn = performanceController.latestReturns.value[fund.fundId];
  return InkWell(
    onTap: () => Navigator.push(... FundDetailScreen(fund: fund)),
    child: Row(children: [
      _CategoryAvatar(fund: fund),                       // colour by category
      Expanded(child: Column(children: [                 // ticker + name·manager
        Text(fund.fundCode ?? fund.fundName, /* bold */),
        Text([fund.fundName, if (company != null) company.companyName].join(' · ')),
      ])),
      SizedBox(width: _kNumberCol, child: Column(children: [  // latest return + fee
        Text(latestReturn == null ? '—' : '${latestReturn.toStringAsFixed(2)}%'),
        Text('${fund.managementFee!.toStringAsFixed(2)}% p.a.'),
      ])),
      SizedBox(width: _kPillCol, child: latestReturn == null
          ? const SizedBox.shrink()
          : _ReturnPill(returnRate: latestReturn)),       // green/red pill
    ]),
  );
});
```

This is why the numbers "pop in" a moment after the row appears: the row renders
as soon as `filteredFunds` has data (identity + fee come from the `Fund` itself),
but the return column and pill read `latestReturns`, which is populated by a
*separate* async call. When that call finishes, only those parts repaint —
they're the only things inside this `Watch` that read the changed signal.

Two pure presentation helpers finish the row:
- **`_CategoryAvatar`** (`:390`) — a circle coloured from `_kCategoryColors` by
  the fund's `categoryId`, showing the first two letters of the code.
- **`_ReturnPill`** (`:419`) — a solid rounded pill, **green** at or above
  `_kStrongReturn` (10%), **red** below (`:426`). The colour is chosen from the
  value at build time — exactly the "theme vs. tokens" split from §8.

### 9.2 `FundDetailScreen` — reading derived state

Opened with a specific `Fund`. In `initState` it triggers one load
(`fund_detail_screen.dart:53-58`):

```dart
_performanceController.loadHistory(widget.fund.fundId);
```

That single call populates `history`, and — as we saw in §7.3 — the four
performance computeds refresh off it. The redesigned screen is a single
scrolling `ListView` (`:69-86`): a custom header, a gold-underlined "Overview"
label, a headline, the chart card, a disclaimer, a stats card, the manager card,
and the monthly history. It also holds one piece of local UI state — the
selected chart range (`int _rangeMonths = 12`, `:50`).

**The header** (`fund_detail_screen.dart:94`) is a custom row — back arrow,
category avatar, `fundCode` + fund name, and the edit/delete actions (delete is
the soft-delete confirm flow, `:539`). It reads only `widget.fund`, so it needs
no `Watch`.

**The headline** (`fund_detail_screen.dart:191`) is one `Watch` over three
computeds plus the category lookup:

```dart
Watch((context) {
  final latest   = _performanceController.latestReturn.value;   // big number
  final average  = _performanceController.averageReturn.value;  // subline
  final bestRank = _performanceController.bestRank.value;
  final category = _categoryController.categoriesById.value[widget.fund.categoryId];
  final avgColor = (average ?? 0) >= _kStrongReturn ? _kGreen : _kRed;
  // 34pt latest-return %, a category pill, then "avg X% · best rank #N · Past 12 months"
});
```

The big latest-return figure sits next to an outlined **category pill**; beneath
it the 12-month average is coloured green/red by the same 10% rule, followed by
the best rank. Everything shows an em-dash while `history` is empty and fills in
together when `loadHistory` completes.

**The chart card** (`fund_detail_screen.dart:263`) is the most involved piece.
Its `Watch` switches on `isLoadingHistory`, then **slices** the series to the
selected range before drawing:

```dart
final all = _performanceController.chartValues.value;
final take = _rangeMonths.clamp(0, all.length);
final values = all.sublist(all.length - take);   // last N months
if (values.length < 2) return const Center(child: Text('Not enough data'));
final up = values.last >= values.first;          // trend over the window
final color = up ? _kGreen : _kRed;
return Row(children: [
  Expanded(child: CustomPaint(painter: _AreaChartPainter(values: values, color: color))),
  _buildAxisLabels(minV, maxV),                  // 5 return labels down the right edge
]);
```

Three things to notice:
- **The range selector is real, not decorative.** `_kRanges` (`:30`) maps
  `3M/6M/1Y` to `3/6/12` trailing months; `_RangeChip` (`:617`) writes
  `_rangeMonths` via `setState`, and the slice above re-derives the visible
  window. Because `setState` re-runs `build`, the chart's `Watch` re-reads
  `chartValues` and redraws — signals and local state cooperating.
- **The line colour tracks the trend** of the *visible* window (green if it ends
  higher than it starts, red otherwise) — which is why a money-market fund draws
  green and a weak equity fund draws red, with no hardcoding.
- **`_buildAxisLabels`** (`:316`) prints five evenly-spaced return values down
  the right edge, from the window's max at top to its min at bottom.

**`_AreaChartPainter`** (`fund_detail_screen.dart:654`) is the one piece of
"hard" code — pure canvas math, no chart package. Worth reading in four steps:

1. **Normalise** (`:669-680`): find `min`/`max` of the visible series, then map
   each value to a `0..1` height within that range (with `_pad` breathing room).
   `range` guards against divide-by-zero when all values are equal.
2. **Smooth curve** (`:682-696`): rather than a raw polyline, the points are
   joined with a **Catmull-Rom spline expressed as cubic Béziers** (`cubicTo`,
   tension 0.5). For each segment the two Bézier control points are derived from
   the neighbouring points, so the line flows through every month's actual value
   with soft peaks and valleys instead of hard corners.
3. **Fill path** (`:699-711`): clone the smoothed line, drop it to the bottom
   corners and `close()` it, then paint with a top-to-bottom gradient that fades
   to transparent — the "area chart" look.
4. **Stroke + dot** (`:713-722`): draw the curve on top, then a filled circle on
   the latest month.

`shouldRepaint` (`:726-727`) returns true only when `values` or `color` changed,
so the canvas isn't redrawn needlessly.

**The stats card** (`fund_detail_screen.dart:367`) is a grey rounded card with a
two-column grid, built inside a `Watch` that reads `history` and the performance
computeds. It surfaces real fund + performance figures — latest return, 12-mo
average, best rank, this-month rank, best/weakest month (min/max over `history`),
management fee, currency, category, and risk level — each rendered by a small
`_statCell` helper.

**The manager card** (`fund_detail_screen.dart:466`) is wrapped in `Watch`
because it resolves a foreign key through the `companiesById` computed lookup,
which may populate *after* the screen first builds. It returns
`SizedBox.shrink()` (renders nothing) if the company isn't found.

**The history card** (`fund_detail_screen.dart:504`) reads `history` reversed
(newest first) and lays out a `date | return% | #rank` row per month, using
`intl`'s `DateFormat('MMM yyyy')` for the month labels.

### 9.3 `FundFormScreen` — create and edit in one screen

This is the app's only *input* screen, and it demonstrates the **deliberate
boundary between signals and local state**. Like the other two, it was restyled
to match the theme — filled rounded inputs with a gold focus ring (a shared
`_decoration` helper at `fund_form_screen.dart:95`) and a full-width gold primary
button — with **no change to its logic**.

**One widget, two modes** (`fund_form_screen.dart:15-50`): the constructor takes
an optional `existingFund`. Null → "Add" mode; non-null → "Edit" mode with
fields pre-filled. `_isEditing` is just `existingFund != null`.

**Local state, *not* signals** (`fund_form_screen.dart:35-48`). The text fields
use `TextEditingController`s and the dropdowns use plain fields mutated with
`setState`:

```dart
late final _nameController = TextEditingController(text: widget.existingFund?.fundName);
// …
late int? _categoryId = widget.existingFund?.categoryId;
late String _currency = widget.existingFund?.currency ?? 'KES';
```

The comment at `fund_form_screen.dart:32-34` states the rule explicitly:

> Text inputs use controllers; dropdowns use plain fields + setState, because
> this is *ephemeral, screen-local* state — signals are reserved for state that
> outlives a screen or is shared between screens.

This is a key architectural judgement. A half-typed form is nobody else's
business, so it stays local; it would be wrong to pollute app-wide signals with
it. Signals are for *shared or surviving* state; `setState`/controllers are for
*throwaway* state. (And because controllers hold native resources, `dispose()`
at `:54-61` tears them down.)

**The dropdowns still read signals**, so they're wrapped in `Watch`
(`fund_form_screen.dart:223` onward): the Category options come from
`_categoryController.categories` and the Fund-manager options from
`_fundController.companies`. That means the pickers populate automatically once
those async loads finish — even though the *selection* is local state. Currency
is a plain, non-`Watch` dropdown because nothing it depends on is async
(`:257`).

**Saving** (`fund_form_screen.dart:65-87`) is the round-trip back down through
the layers:

```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;   // run all validators
  final fund = Fund(
    fundId: base?.fundId ?? 0,          // 0 = create (FundController convention)
    fundName: _nameController.text.trim(),
    fundCode: _emptyToNull(_codeController.text),
    // …assembled from local field state…
    isActive: base?.isActive ?? true,
    createdAt: base?.createdAt ?? now,  // preserve original creation time on edit
    updatedAt: now,
  );
  final success = await _fundController.saveFund(fund);
  if (success && mounted) Navigator.of(context).pop();
}
```

Three things close the loop:

- The screen **never touches a repository** — it builds a `Fund` and hands it to
  `_fundController.saveFund`. The controller decides create-vs-update from the
  `fundId == 0` convention.
- `_emptyToNull` (`:91`) turns whitespace-only inputs into `null`, so optional DB
  columns stay `NULL` rather than storing empty strings.
- On success the form pops. Back on the list screen, `filteredFunds` already
  reflects the change (the controller updated `funds`), so the new/edited fund is
  simply *there* — no manual refresh.

The save button itself is wrapped in `Watch` (`fund_form_screen.dart:182`) so it
disables and shows an inline spinner while `_fundController.isLoading` is true —
reusing the very same signal the list screen reads.

**Validation** uses standard Flutter `Form` machinery: the `GlobalKey<FormState>`
runs every field's `validator` at once. Only `fundName` is required (mirroring a
`NOT NULL` column, `:131-133`); the fee is optional but must parse as a number if
present (`:157-162`).

---

## 10. Putting it together — three end-to-end journeys

The best way to cement the architecture is to trace real interactions through
every layer.

### Journey A — the app starts

1. `main()` runs `DI.init()`, constructing dummy repositories and the three
   controllers with empty signals, then `runApp`.
2. `FundsListScreen.initState` fires `loadFunds()`, `loadCategories()`,
   `loadLatestReturns()` — none awaited.
3. First frame paints immediately: the list body's `Watch` sees
   `isLoading == true && funds.isEmpty`, so it shows a spinner.
4. ~350ms later `loadFunds` sets `funds` and `companies`. `filteredFunds`
   recomputes (10 funds), the list `Watch` repaints into rows.
5. `loadLatestReturns` finishes; each `_FundTile`'s `Watch` sees `latestReturns`
   change and paints its return column + green/red pill in.
6. `loadCategories` finishes; the tab strip's `Watch` sees `categories` and
   renders the category tabs.

Each async result lands independently and repaints only the widgets that read
the signal it touched. The three loads race in parallel and each paints in when
it resolves:

```mermaid
sequenceDiagram
    participant M as main()
    participant DI as DI
    participant LS as FundsListScreen
    participant FC as FundController
    participant PC as FundPerformanceController
    participant CC as FundCategoryController
    participant R as Dummy repositories

    M->>DI: DI.init() (build repos + controllers)
    M->>LS: runApp → first frame
    Note over LS: paints instantly with a spinner<br/>(isLoading && funds empty)

    LS->>FC: loadFunds() (not awaited)
    LS->>PC: loadLatestReturns() (not awaited)
    LS->>CC: loadCategories() (not awaited)

    par funds + companies
        FC->>R: getFunds() + getCompanies()
        R-->>FC: lists (~350ms)
        Note over FC: funds/companies signals set<br/>→ filteredFunds recomputes → list repaints
    and latest returns
        PC->>R: getLatestReturns()
        R-->>PC: {fundId: rate}
        Note over PC: latestReturns set<br/>→ each row's badge repaints
    and categories
        CC->>R: getCategories()
        R-->>CC: categories
        Note over CC: categories set<br/>→ chip row repaints
    end
```

### Journey B — the user searches for "equity"

1. Keystrokes call `onChanged`, writing `_fundController.searchQuery.value`.
2. `filteredFunds` reads `searchQuery`, so it recomputes on every keystroke —
   keeping only active funds whose name/code contains the query, sorted by name.
3. The list body's `Watch` read `filteredFunds`, so it repaints with the
   narrowed set. The search box itself never rebuilds (it doesn't read a signal).
4. Tapping the "Equity" chip writes `selectedCategoryId`; `filteredFunds`
   recomputes again, now applying *both* predicates. Tapping the same chip again
   writes `null` and clears the category filter.

No filtering code runs in any widget — the `computed` dependency graph does all
of it. As a sequence:

```mermaid
sequenceDiagram
    actor User
    participant TF as TextField (search box)
    participant SQ as searchQuery (signal)
    participant FF as filteredFunds (computed)
    participant W as Watch (list body)

    User->>TF: types "equity"
    TF->>SQ: searchQuery.value = "equity"
    Note over SQ,FF: signal change invalidates<br/>every computed that read it
    SQ-->>FF: recompute (filter + sort)
    FF-->>W: value changed → repaint subtree
    W-->>User: narrowed list shown
    Note over TF: the TextField never rebuilds —<br/>it writes a signal but reads none
```

### Journey C — the user edits a fund's fee

1. Detail screen → edit icon → `FundFormScreen(existingFund: fund)`; controllers
   pre-fill the text controllers and local dropdown fields.
2. The user changes the fee and taps Save. `_save` validates, then builds a new
   `Fund` via the field values, preserving `fundId` and `createdAt`, stamping a
   fresh `updatedAt`.
3. `FundController.saveFund` sees `fundId != 0`, calls
   `_fundRepository.updateFund`, and replaces that fund in `funds` with a
   rebuilt list.
4. `funds` changed → `filteredFunds` recomputes. The form pops; the list screen
   is already showing the updated fee. If the detail screen is revisited, its
   cards reflect the change too, since they read the same shared controller.

The write flowed **down** (screen → controller → repository → model) and the
result flowed **up** (signal change → computed → `Watch` repaint) — the full
loop.

---

## 11. The test, and why it's tiny

**File:** `test/fund_controller_test.dart`

There's a single test, and it's revealing precisely *because* it needs no
widgets (`fund_controller_test.dart`):

```dart
final controller = FundController(
  DummyFundRepository(),
  DummyFundManagementCompanyRepository(),
);
await controller.loadFunds();
expect(controller.filteredFunds.value.length, 10);

controller.searchQuery.value = 'money market';        // "type" in the box
expect(controller.filteredFunds.value.length, 4);

controller.selectedCategoryId.value = 1;              // "tap" the MMF chip
expect(controller.filteredFunds.value.length, 4);

controller.searchQuery.value = '';                    // clear search, keep chip
expect(controller.filteredFunds.value.every((f) => f.categoryId == 1), isTrue);
```

Because all the real logic lives in the controller (pure Dart) and not the
widgets, the test drives the app's core behaviour by **writing signals directly**
and asserting on a **computed** — no `pumpWidget`, no emulator, no mocks beyond
the dummy repositories. This is the concrete payoff of the layered design: the
brains of the app are testable in isolation, which is why the test suite runs in
milliseconds. (This is the test the CI **Tests** badge tracks.)

---

## 12. Iteration 2 — the Supabase swap

We've now traced the whole app, so the promised punchline lands with full
weight. To move from dummy data to a live backend:

1. Add `supabase_flutter` (+ `flutter_dotenv`) to `pubspec.yaml`.
2. Implement `SupabaseService.init()` — the placeholder already documents the
   exact call (`services/supabase_service.dart:11-22`).
3. Add `SupabaseFundRepository` etc., implementing the **same abstract
   contracts**, using `client.from('funds').select()` mapped through
   `Fund.fromJson`. This is why the models' JSON keys match the Postgres columns
   exactly — the rows deserialize with zero changes.
4. Change the **four constructors** in `dependency_injection.dart` from
   `Dummy*Repository()` to `Supabase*Repository(...)`.
5. Delete the seed sources: `lib/repositories/fund_catalog.dart` and
   `lib/repositories/real_fund_data.dart`.

**Nothing in `controllers/` or `screens/` changes.** Every one of them depends
only on the abstract repository types and on signals, both of which are
untouched. That single fact — that a whole-backend swap is a four-line edit — is
the thesis the entire architecture exists to prove.

---

### One-page recap

| Layer | Files | Owns | Talks to |
|---|---|---|---|
| **Models** | `models/` | Immutable data shapes + JSON | nobody |
| **Data** | `repositories/`, `fund_catalog.dart`, `real_fund_data.dart` | Fetch/persist behind abstract contracts | Models |
| **Wiring** | `dependency_injection.dart` | The one place concrete classes are chosen | Repos + Controllers |
| **State** | `controllers/` | Signals + computed derived state; async actions | Abstract repos |
| **UI** | `screens/`, `main.dart` | Layout; reads signals via `Watch`, writes on interaction | Controllers via `DI` |

**The one loop to remember:** widgets write signals → `computed` values
recalculate → `Watch` widgets repaint. Everything else is just giving that loop
clean data to run on.