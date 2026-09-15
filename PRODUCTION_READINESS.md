# Wazy — Production Readiness Report

_Generated: 2026-09-12 · Audit scope: full `lib/`, `android/`, `ios/`, `test/`, CI/config_

---

## Verdict

> # ❌ NOT production-ready
>
> The app is a well-structured **local-only prototype**. All data lives in
> `SharedPreferences` (plain JSON on-device), notifications and WhatsApp/email
> alerts are **stubbed out**, and the release build is **signed with debug keys**.
> It works as a single-user demo but will lose users' data, send zero alerts,
> and fail store review as-is.

**Ready when:** backend + DB integrated, notifications implemented, release
signing configured, and basic tests pass.

---

## 1. Findings by Area

### ✅ What's already good

| Area | Status | Notes |
|---|---|---|
| Project structure | ✅ | Clean `screens/`, `services/`, `models/`, `widgets/` separation |
| Routing | ✅ | `go_router` configured (`lib/router.dart`) |
| State handling | ✅ | Service layer with cached items, `ChangeNotifier`-ready |
| Urgency engine | ✅ | Pure logic, easy to unit-test (`lib/services/urgency_engine.dart`) |
| Lint rules | ✅ | `flutter_lints ^5.0.0` enabled via `analysis_options.yaml` |
| Analyzer | ✅ | 0 errors — only 4 warnings + ~50 deprecation infos (`withOpacity` → `withValues`) |
| Localization-ready | ✅ | All strings are inline, easy to extract later |

### 🔴 Blockers (must fix before shipping)

| # | Finding | Where | Why it blocks |
|---|---|---|---|
| B1 | **No backend / no database.** All data (`expiry_items`, `company_data`) stored as a single JSON string in `SharedPreferences` | `lib/services/document_scanner_service.dart`, `lib/services/company_service.dart` | Data is device-bound: uninstall/clear-storage = total data loss. No multi-device, no team features the UI already implies (assignees, WhatsApp alerts). SharedPreferences is not meant for relational records |
| B2 | **NotificationService is an empty shell** — `scheduleReminder`, `sendWhatsAppAlert`, `sendEmailAlert` are empty methods | `lib/services/notification_service.dart` | The app's core promise (never miss a renewal) does nothing. Users will silently miss renewals |
| B3 | **Android release signed with debug keys** | `android/app/build.gradle.kts` (`signingConfig = signingConfigs.getByName("debug")`) | Play Store will reject; also insecure |
| B4 | **Release signing (iOS) not verified** — no evidence of a distribution provisioning profile in the repo | `ios/` | App Store submission will fail |
| B5 | **Zero meaningful tests.** Only 1 smoke test that checks the app builds | `test/widget_test.dart` | Urgency logic, date rollover, and JSON (de)serialization are untested; date bugs will slip through |

### 🟠 High priority (fix before public launch)

| # | Finding | Where | Notes |
|---|---|---|---|
| H1 | **Photo/document scanner is mocked** — returns a fake random confidence value | `lib/screens/document_scan_screen.dart:256` | The "scan" feature doesn't actually OCR/parse anything yet |
| H2 | **No crash reporting / analytics** | — | You'll be blind to production crashes |
| H3 | **No error boundaries** — JSON decode failures are silently swallowed (`catch (_) {}`) | `document_scanner_service.dart:21` | Corrupt data = silent total reset, no way to diagnose |
| H4 | **`main.dart` pre-warms services with unhandled futures** | `lib/main.dart` `_prewarmServices()` | An init failure = crash or broken state with no surface |
| H5 | **Untrusted external image host** (`picsum.photos`) hardcoded for company logo | `lib/screens/home_screen.dart:140`, `lib/widgets/indicators/company_header.dart:38` | Broken/random images in production; no `NSAppTransportSecurity`/Cleartext consideration |
| H6 | **No CI/CD pipeline** (no `.github/workflows/`, no fastlane, no Codemagic) | — | Manual builds invite signing/config drift |
| H7 | **Placeholder app name** `uae_business_radar` as `android:label` and `CFBundleDisplayName` | `AndroidManifest.xml`, `Info.plist` | Reviewers/users see an underscore-style internal name (resolved: app renamed to Wazy) |

### 🟡 Medium priority (polish)

| # | Finding | Where | Notes |
|---|---|---|---|
| M1 | Dead code: unused `_animation` field, unused imports (`uuid`, `widgets.dart`) | `progress_ring.dart:27`, `document_scanner_service.dart:4`, `profile_screen.dart:7` | Analyzer warnings |
| M2 | ~50 `withOpacity` deprecations | several files | Cosmetic; fix in one pass |
| M3 | Data model stores derived fields (`daysRemaining`, `urgency`, `isExpired`) in the persisted JSON | `expiry_item.dart` | Will desync from real dates over time — recompute on read after backend migration |
| M4 | `markAsRenewed` throws if the id is missing (uses `firstWhere` without `orElse`) | `document_scanner_service.dart:82` | Crash on stale UI taps |
| M5 | No app icon / splash customization check for store listing assets | — | Verify icons for both stores |

---

## 2. Should you set up a backend + DB? — YES. Here's the detailed plan.

Your data is inherently relational (`Company → Documents → Renewals →
Assignees`) and the UI already references team features. Recommended:
**Supabase** (Postgres + Auth + Storage + Realtime + Edge Functions in one
platform, generous free tier, official `supabase_flutter` SDK).

Why Supabase over the alternatives researched:
- **MongoDB Atlas** — solid DB, but you'd still need to build auth, storage, and a custom API layer yourself.
- **Appwrite** — good Flutter support, smaller ecosystem.
- **Raw Neon/Postgres** — great DB, but auth/storage/functions all DIY.

### 2.1 Architecture

```
┌─────────────┐    HTTPS (REST/Realtime)    ┌──────────────────┐
│ Flutter app │ ──────────────────────────► │ Supabase project │
│ (offline-   │                             │  ├─ Postgres DB  │
│  first      │ ◄────────────────────────── │  ├─ Auth         │
│  cache:     │      push notifications     │  ├─ Storage      │
│  drift/     │      (FCM via Edge Fn)      │  └─ Edge Fn      │
│  sqflite)   │                             │     (cron)       │
└─────────────┘                             └──────────────────┘
```

### 2.2 Database schema (run in Supabase SQL editor)

```sql
-- Companies
create table companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  trade_license_no text,
  emirate text default 'Dubai',
  logo_url text,
  created_at timestamptz default now()
);

-- Expiry-tracked documents
create table documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  doc_type text not null check (doc_type in (
    'tradeLicence','ejari','visa','emiratesId','labourDocuments','insurance',
    'vehicleRegistration','contracts','certificates','permits',
    'domainNames','softwareSubscriptions','supplierAgreements')),
  display_name text not null,
  expires_at date not null,
  reminder_days int default 30,
  status text default 'active' check (status in ('active','renewed','expired','archived')),
  assigned_to text,
  renewal_fee numeric(10,2),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_documents_company on documents(company_id);
create index idx_documents_expiry on documents(company_id, expires_at);

-- Reminders / notification log
create table reminders (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  remind_at date not null,
  channel text default 'push' check (channel in ('push','email','whatsapp')),
  sent_at timestamptz,
  created_at timestamptz default now()
);

-- NOTE: do NOT persist days_remaining / urgency / is_expired.
-- They are derived from expires_at and should be computed on read
-- (your current model stores them — migrate that away).

alter table companies enable row level security;
alter table documents enable row level security;
alter table reminders enable row level security;

create policy "own company" on companies
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy "own documents" on documents
  for all using (
    exists (select 1 from companies c
            where c.id = documents.company_id and c.owner_id = auth.uid())
  ) with check (
    exists (select 1 from companies c
            where c.id = documents.company_id and c.owner_id = auth.uid())
  );

create policy "own reminders" on reminders
  for all using (
    exists (select 1 from documents d, companies c
            where d.company_id = c.id and d.id = reminders.document_id
              and c.owner_id = auth.uid())
  ) with check (
    exists (select 1 from documents d, companies c
            where d.company_id = c.id and d.id = reminders.document_id
              and c.owner_id = auth.uid())
  );
```

### 2.3 Step-by-step setup

**Phase 1 — Provision (≈30 min)**

1. Create a Supabase project (pick the region closest to your users, e.g. `ap-south-1` Mumbai or `eu-central-1` — no UAE region exists; Dubai users will see ~30–60 ms latency, which is fine).
2. Run the SQL schema above in **SQL Editor**.
3. Enable **Auth → Email** (and optionally Google/Apple sign-in later).
4. Create a **Storage** bucket `documents` (private, 10 MB limit, allowed MIME: pdf/jpg/png).

**Phase 2 — Flutter integration (≈2–4 hours)**

1. Add SDK: `flutter pub add supabase_flutter`
2. `lib/main.dart`:
   ```dart
   await Supabase.initialize(
     url: 'https://YOUR-PROJECT.supabase.co',
     anonKey: 'YOUR-ANON-KEY',  // public-safe, NOT the service_role key
   );
   ```
3. Refactor `DocumentScannerService` methods (`getAllItems`, `addItem`, `updateItem`, `removeItem`, `markAsRenewed`, `assignTo`, `updateExpiryDate`) to call Supabase instead of `_cachedItems`. Keep SharedPreferences **only as an offline cache** (offline-first: write locally → sync when online).
4. Refactor `CompanyService.getCompany/updateCompany` the same way.
5. Load keys via `--dart-define` (never hardcode):
   ```bash
   flutter build apk --release \
     --dart-define=SUPABASE_URL=... \
     --dart-define=SUPABASE_ANON_KEY=...
   ```
   ```dart
   const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
   ```

**Phase 3 — Notifications (fixes blocker B2)**

1. Add `flutter_local_notifications` (local reminders) + `firebase_core` + `firebase_messaging` (push).
2. Create a Supabase **Edge Function** on a daily cron (Supabase Dashboard → Edge Functions → schedule):
   ```ts
   // supabase/functions/daily-reminders/index.ts
   import { createClient } from 'jsr:@supabase/supabase-js@2'
   Deno.serve(async () => {
     const admin = createClient(
       Deno.env.get('SUPABASE_URL')!,
       Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // server-only
     )
     // select documents where expires_at - today <= reminder_days and sent_at is null
     // send FCM / email per channel, insert into reminders.sent_at
     return new Response('ok')
   })
   ```
3. WhatsApp alerts (the UI already has a button for it): Meta WhatsApp Cloud API or Twilio — call it from the same Edge Function. **Never call it from the app** (secret leakage).

**Phase 4 — Release hardening (fixes B3/B4, H2, H6)**

1. Android: create an upload keystore, wire `key.properties` + signing config (remove the debug signing).
2. iOS: set up distribution certificate + provisioning profile in Xcode.
3. Add Sentry (or Crashlytics) — one `Sentry.init(dsn: ...)` call in `main.dart`.
4. CI: GitHub Actions workflow — `flutter analyze && flutter test` on every PR, build release on tags.

### 2.4 Cost snapshot

| | Free tier covers | Paid |
|---|---|---|
| **Supabase Free** | 2 projects, 500 MB DB, 50 k MAU auth, 1 GB storage, 2 Edge Fns | Pro $25/mo when you outgrow it |
| **FCM / APNs** | Unlimited push | Free |
| **Sentry** | 5 k errors/mo | Team $26/mo |

A document-tracker MVP fits comfortably in the free tier for the first few hundred users.

---

## 3. Pre-launch checklist

```
Blockers
[ ] Supabase project created, schema + RLS applied
[ ] DocumentScannerService / CompanyService refactored to backend + offline cache
[ ] Local + push notifications implemented (B2)
[ ] Android release keystore + signing config (B3)
[ ] iOS distribution signing verified (B4)
[ ] Unit tests for UrgencyEngine, ExpiryItem JSON round-trip, date rollover (B5)

High
[ ] Real OCR/scan integration or ship without scan (H1)
[ ] Sentry/Crashlytics wired (H2)
[ ] Handle JSON decode errors → report, don't silently reset (H3)
[ ] Await/handle _prewarmServices futures (H4)
[ ] Replace picsum.photos with company-uploaded logo (H5)
[ ] CI pipeline running analyze + test (H6)
[ ] Real app name on both platforms (H7)

Medium
[ ] Stop persisting derived fields (daysRemaining/urgency) (M3)
[ ] firstWhere orElse crash fix (M4)
[ ] withOpacity → withValues cleanup (M2)

Store
[ ] App icons + splash for both platforms
[ ] Privacy policy URL (mandatory: app stores document/expiry data)
[ ] Data-safety form (Play) / privacy nutrition labels (App Store)
```

---

## 4. Bottom line

**Answer: yes — you should absolutely set up a backend and DB before
production.** The current SharedPreferences-only architecture cannot survive
real usage: data loss on reinstall, no notifications (the core feature), no
multi-device, and no team/alert features the UI already promises.

Supabase is the fastest path: one platform covers DB + auth + storage +
scheduled Edge Functions for the reminder cron, with a free tier that fits an
MVP. Plan on **~1–2 focused days** for backend + service refactor, plus a
day for signing, notifications, and CI. After the checklist above is green,
this is a legitimately shippable app.
