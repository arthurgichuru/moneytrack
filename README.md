# MoneyTrack

[![CI](https://github.com/arthurgichuru/moneytrack/actions/workflows/ci.yml/badge.svg)](https://github.com/arthurgichuru/moneytrack/actions/workflows/ci.yml)
[![Tests](https://github.com/arthurgichuru/moneytrack/actions/workflows/tests.yml/badge.svg)](https://github.com/arthurgichuru/moneytrack/actions/workflows/tests.yml)

Flutter app for browsing unit-trust fund performance. Iteration 1 runs
entirely on dummy data; iteration 2 swaps in Supabase.

## Architecture

```
UI (screens)  →  Controllers (signals)  →  Repositories (abstract)  →  Data
   Watch()         signal/computed           Dummy* today,             DummyData
                                             Supabase* next            (Supabase later)
```

- **Models** mirror the Postgres schema column-for-column (`fromJson`/`toJson`
  use the exact column names), so Supabase rows will deserialize unchanged.
- **Repositories** are abstract contracts + `Dummy*` implementations with
  simulated latency. Iteration 2 adds `Supabase*` implementations.
- **Controllers** own app state as signals. Widgets write to signals
  (search text, chip selection); `computed` values derive the filtered
  list, stats and chart data automatically.
- **Screens** read state through `Watch(...)`, which rebuilds only the
  subtree that actually depends on a changed signal.
- **DI** (`dependency_injection.dart`) is the single place where concrete
  classes are chosen — the only file that changes for iteration 2 besides
  adding the new repository implementations.

## Signals cheat-sheet used here

| API | Meaning |
|---|---|
| `signal(x)` | writable reactive value (`.value` to read/write) |
| `listSignal([])` / `mapSignal({})` | reactive List / Map |
| `computed(() => …)` | cached derived value, auto-recomputes |
| `Watch((context) => …)` | widget that rebuilds when signals it reads change |

## Run it

```bash
flutter pub get
flutter run
flutter test   # controller test, no emulator needed
```

## Iteration 2 checklist

1. `flutter pub add supabase_flutter flutter_dotenv`
2. Implement `SupabaseService.init()` (see comments in the file).
3. Add `SupabaseFundRepository` etc. implementing the same abstract classes
   (queries like `client.from('funds').select()` mapped through `Fund.fromJson`).
4. Swap the four constructors in `dependency_injection.dart`.
5. Delete `lib/repositories/dummy_data.dart`.
