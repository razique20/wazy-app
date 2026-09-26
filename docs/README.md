# Finavig — Documentation

Everything you need to understand, run, and evaluate Finavig.

> **Finavig** is an AI-powered financial budgeting & cash-flow intelligence app with built-in document expiry tracking, built for the UAE: plan budgets, forecast cash, and keep every trade licence, visa, Emirates ID, insurance and subscription countdown — and the money to renew it — on one dashboard.

## 📚 Documents

| Document | What's inside |
|---|---|
| **[Technical documentation](technical-documentation.md)** | System architecture, data model & schema, the offline-first sync engine (outbox + LWW merge), every feature explained with screenshots, notifications, build & test guide, migrations, known limitations |
| **[Market study](market-study.md)** | The UAE expiry problem in numbers, target segments, competitive landscape (government apps vs calendars vs PRO agents), positioning, demand estimate, monetization options, market risks |
| **[Feasibility study](feasibility-study.md)** | Technical / operational / financial / legal verdicts, remaining risks, effort-to-launch estimate, go-to-market channels, validation metrics, and the go/no-go pilot checklist |

Other project-level docs (repo root): [`../PRODUCTION_READINESS.md`](../PRODUCTION_READINESS.md) (pre-launch audit), [`../FINTECH_ROADMAP.md`](../FINTECH_ROADMAP.md), [`../README.md`](../README.md) (quick start).

## 🖼️ Screenshot gallery

Captured from a real release web build with seeded demo data (`tool/capture_screens.mjs`). Click any image for full size.

| | |
|---|---|
| **Splash & version gate** — checks `app_versions` for updates on every launch | **Onboarding** — three-panel first-run intro |
| ![Splash](images/01_splash.png) | ![Onboarding](images/02_onboarding.png) |
| **Home dashboard** — attention banner, stat tiles, this-month cash summary with pace, renewal outlook | **Documents radar** — urgency colors, renewal-window progress, fees, filters |
| ![Home](images/03_home.png) | ![Documents list](images/04_documents_list.png) |
| **Document detail** — urgency timeline, custom alert days, renewal checklist, history, mark-as-renewed | **Upload & OCR scan** — ML Kit pre-fills title, type, expiry, emirate & authority from an image |
| ![Document detail](images/05_document_detail.png) | ![Upload/scan](images/06_upload_scan.png) |
| **Expiry list** — flat chronological view with CSV/PDF export | **Global search** — across names, notes, authorities, files, all collections |
| ![Expiry list](images/07_expiry_list.png) | ![Global search](images/08_global_search.png) |
| **Money dashboard** — budgets with 80/100% alerts, bill-spike detection, spending pace, renewal outlook | **90-day cash-flow forecast** — daily balance simulation including renewal outflows |
| ![Money](images/09_money.png) | ![Cash-flow forecast](images/10_cash_flow.png) |
| **Profile** — collections, alert preferences, theme, account | |
| ![Profile](images/11_profile.png) | |

## 🗂️ Database & migrations

| File | Purpose |
|---|---|
| [`../supabase/schema.sql`](../supabase/schema.sql) | Core schema: collections, documents, reminders, custom types + RLS + pg_cron reminder scan (idempotent) |
| [`../supabase/finance_schema.sql`](../supabase/finance_schema.sql) | Finance tables: transactions, budgets, envelopes, recurring |
| [`../supabase/migrate_documents_local_only_fields.sql`](../supabase/migrate_documents_local_only_fields.sql) | Adds `location`, `renewal_history`, `custom_reminder_days` to existing projects |
| [`../supabase/migrate_companies_to_collections.sql`](../supabase/migrate_companies_to_collections.sql) | Legacy single-company model → collections |
| [`../supabase/app_version_schema.sql`](../supabase/app_version_schema.sql) | Splash update-check table |

## 🔧 Maintenance

- **Regenerate all screenshots:** `flutter build web --release && node tool/capture_screens.mjs` (requires a local-only build — blank the Supabase credentials first, then `git checkout -- lib/config/app_credentials.dart`; the script seeds demo data via localStorage).
- **Tests:** `flutter test` (20 suites). **Analyzer:** `flutter analyze`.
- When a feature changes the UI materially, re-capture the relevant screenshot and update both the gallery above and the feature section in the technical documentation.
