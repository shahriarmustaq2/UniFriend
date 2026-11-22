# UniFriend

A complete companion for university students, built with Flutter and Supabase.
One app for semesters and vacations, the class routine (including alternate-week
labs and cancelled classes), attendance, theory and sessional marks with a marks
table, CGPA, a study plan with exam countdowns, and expenses with a safe daily
spend.

## Quick start

1. Run the SQL in `supabase/migrations/`, in order, on your Supabase project.
2. Run the app:

   ```sh
   flutter pub get
   flutter run
   ```

Full instructions are in [docs/SETUP.md](docs/SETUP.md).

## Notes

| Document | What it covers |
| --- | --- |
| [docs/PRODUCT.md](docs/PRODUCT.md) | Every feature, how it behaves, and the rules behind the numbers |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the code is organised, and how to add a feature |
| [docs/DATABASE.md](docs/DATABASE.md) | Tables, constraints and row level security |
| [docs/SETUP.md](docs/SETUP.md) | Database setup, running, testing and release builds |
| [docs/STATUS.md](docs/STATUS.md) | What is done, what was verified, known limits and next steps |

## Checks

```sh
flutter analyze
flutter test
```
