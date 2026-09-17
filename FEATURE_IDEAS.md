# Implementation Backlog

App: **Wazy** — a two-tier operations app for UAE SMEs:

- **Tier 1 — Documents (Home tab):** expiry tracking, reminders, renewals.
- **Tier 2 — Money (Money tab):** transaction log, category budgets, savings envelopes.

**Already shipped:** 
- Home screen redesign with two-tier bottom nav & minimal branding
- Document tracking with 4 urgency tiers (Low, Medium, High, Critical)
- Offline-first local cache + Supabase sync (outbox queue, LWW conflict resolution, offline tombstones)
- Multi-device & shared collections
- Transaction log, category budget caps, savings envelopes
- 90-day renewal outlook & auto-calculated renewal fees
- Scheduled local OS notifications (90/60/30/7-day ladder with Asia/Dubai timezone support)
- Custom document types with dynamic icons, user creation flow, and Supabase sync
- Full filters & sort suite in `/expiry-list` (types, urgency, status, collection, days remaining)
- Global live search across documents & transactions with debounced inverted matcher
- CSV & PDF report export via native share sheet
- Recurring transaction templates (monthly/quarterly/yearly) with auto-logging & catch-up
- Budget threshold alerts (80% & 100% warnings via OS notification, snackbars, & tab badge dots)
- Renewal payment loop (Tier 1 & Tier 2 integration in both directions)
- Duplicate transaction detection with soft warning dialogs

---

## Non-AI features

### Tier 1 — Documents (core loop)

- [x] **"Mark as renewed" flow** — ✅ implemented: one tap on Document Detail or Expiry List extends expiry by typical cycle (1 year), reschedules 90/60/30/7-day local notifications, and auto-logs a renewals expense to the Money tab if a renewal fee is defined.
- [ ] **Renewal history timeline** per document (who renewed, when, cost).
- [x] **Scheduled local notifications** (`flutter_local_notifications`) — ✅ implemented: exact OS reminders fire at 09:00 (Asia/Dubai) on the 90/60/30/7-day ladder, scheduled/cancelled automatically on document add/update/renew/delete, re-synced on startup, with runtime permission prompt on Android 13+.
- [ ] **Per-document reminder overrides** — custom alert days (e.g. 45 days instead of the tier default).
- [x] **Archived / expired documents view** — ✅ implemented: status filter toggle (Active / Expired / All) on `/expiry-list` screen allows inspecting expired and archived documents without cluttering the main active documents list.
- [x] **Custom document types** — ✅ implemented: users can define their own types from the scan screen (name, renewal authority, renewal cycle), stored in the `custom_document_types` Supabase table with a local fallback; they appear in the type picker and all filter chips alongside the 13 built-ins, and documents store a stable `custom-<uuid>` type key.
- [ ] **Notes & attachments** per document (photos of receipts, PDFs multi-attachment view).
- [x] **Cost & fee tracking** — ✅ implemented: `renewalFee` on `ExpiryItem` tracks document renewal fees, driving renewal payment auto-logging and 90-day Money-tier outlook calculation.

### Tier 1 — Search, list & export

- [x] **Filters & sort** in `/expiry-list` (type, status, collection, days remaining) — ✅ implemented: pure `ExpiryFilterSpec` (type, urgency tier, reminder status, lifecycle status active/expired/all, collection, days-remaining presets, free-text query) with 5 sort modes; the screen loads every collection so the collection filter is real; the filter sheet scrolls and renders active-filter chips.
- [x] **Global search** across documents (name, number, notes) — ✅ implemented: `/search` screen with debounced live results over an inverted-field matcher (`DocumentScannerSearch.matchesQuery`: name, notes/record numbers, location, assignee, file name, type name); reachable from the Documents tab app bar; match rules unit-tested.
- [x] **CSV & PDF export** of the expiry report (accountants love this) — ✅ implemented: share-sheet export (CSV via `FilePicker.saveFile` with clipboard fallback, PDF via `Printing.sharePdf`) from `/expiry-list`; the export honours the active filters, and an explicit status filter lets accountants include expired rows.

### Tier 2 — Money

- [x] **Recurring transactions** — ✅ implemented: `RecurringTransaction` templates (monthly/quarterly/yearly, day-of-month with short-month clamping, start/end dates, pause/resume) auto-log transactions via `FinanceService.runDueRecurrences` on app start — catch-up for missed cycles (capped at 12), idempotent through `lastLoggedAt`. Managed from a Recurring section on the Money tab; the Add Record sheet offers a "Repeat monthly" toggle to create templates inline. Local storage + `recurring_transactions` Supabase table with RLS; covered by test/recurring_test.dart (18 tests).
- [ ] **Categorization rules** — "any title containing DEWA → Utilities"; runs on save and can retro-apply to existing records.
- [x] **Budget alerts** — ✅ implemented: `BudgetAlertService` evaluates category budgets against the current month's spend on every finance change (including auto-logged recurring transactions at startup) and fires at 80% ("Close to budget") and 100% ("Budget exceeded") — once per budget per month per threshold, deduped via SharedPreferences so relaunches don't re-fire. Delivered as an OS local notification (`budget_alerts` channel), an in-app snackbar on the Money tab, and an amber/red badge dot on the Money tab icon (worst budget status via `FinanceMath.worstBudgetStatus`). Threshold logic (`BudgetThresholds`/`BudgetStatusResult`) is pure and covered by 12 tests in test/finance_test.dart.
- [x] **Renewal payment loop (tier glue)** — ✅ implemented, works from both directions:
  * **Money → Documents:** the Add Record sheet (expense) has a "Linked document" picker. Saving a `renewals` expense linked to a tracked document pops "Mark <doc> as renewed?" — confirming extends the expiry one year (`markAsRenewed(newExpiryDate:)`), reschedules the 90/60/30/7 reminders, and snacks the new expiry date.
  * **Documents → Money:** "Mark as renewed" on the document detail screen now renews in place (expiry +1 year, reminders rescheduled) and — when the document has a renewal fee — auto-logs a `renewals` transaction linked via `documentId`.
  * Service support: `DocumentScannerService.markAsRenewed(id, {newExpiryDate})` (renews in place instead of archiving), `getAllItemsSync()` snapshot for pickers. Legacy archive behaviour is preserved when no new expiry is passed.
- [ ] **Auto-envelope from outlook** — one tap on the renewal outlook card creates/refreshes an envelope per upcoming renewal (target = renewal fee).
- [ ] **Receipt photo attachment** per transaction (reuse `file_picker`).
- [x] **Duplicate transaction detection** — ✅ implemented: `FinanceMath.findDuplicateTransaction` (pure, unit-tested) flags an existing record with the same title (case/space-insensitive), amount and calendar day, scoped to the candidate's collection and ignoring its own id for the edit flow. The Add Record sheet shows a "Possible duplicate" dialog before saving with Discard / Save anyway — a soft guard, since a second same-day payment of the same amount is legitimate.
- [x] **Cash-flow forecast chart** — ✅ implemented: `FinanceMath.calculate90DayCashFlow` simulates 90 days of daily projected balances combining historical transaction balances, recurring income/expenses, and upcoming document renewal fees (`ExpiryItem.renewalFee`). Rendered on the Money tab via `CashFlowForecastCard` featuring a smooth `CustomPainter` line & area chart, visual renewal dip indicators, 90-day projected metrics, lowest-balance warning banner, and interactive tap/drag date inspection panel. Unit-tested in `test/cash_flow_test.dart` (4 tests).
- [ ] **VAT assistant** — 5% input/output VAT fields per transaction with a quarterly summary (UAE VAT readiness; no filing claims).

### Platform & UX

- [ ] **Dark mode**.
- [ ] **Arabic localization (RTL)** — table stakes for the UAE market.

### Security

- [ ] **App lock** — PIN / Face ID via `local_auth` (documents are sensitive).

---

## AI features

All AI runs **on-device via ML Kit** — free, private, works offline. Nothing here
needs an LLM budget or server-side calls.

- [x] **OCR scan → auto-fill** — ✅ implemented: `google_mlkit_text_recognition` scans uploaded document images (Trade License, Visa, Ejari, Mulkiya, Emirates ID) and extracts title, document number, document category, expiry date (with UAE date format support), emirate, and issuing authority. Forms are auto-filled with visual "⚡ Auto-filled" badges, and the user must review and explicitly tap **Confirm & Save Document** before saving.
- [ ] **Arabic + English OCR** — ML Kit supports both scripts; bilingual extraction is a real differentiator for UAE documents.
- [x] **Auto document-type detection** — ✅ implemented: automatic classification of OCR text into Wazy document categories (`tradeLicence`, `residencyVisa`, `ejari`, `vehicleRegistration`, `emiratesId`, `establishmentCard`, `healthInsurance`, `civilDefense`).
- [x] **Natural-language add** — ✅ implemented: `NaturalLanguageParserService` parses freeform English prompts (e.g. *"Add my trade licence, expires 12 March 2027 cost 1500 AED Dubai"*) into structured Wazy `ExpiryItem` fields (Title, Category, Expiry Date, Emirate, Issuing Authority, Fee). Interactive `NaturalLanguageAddDialog` renders live field previews as you type with quick sample chips and 1-tap **Confirm & Save**.

---

## Suggested build order

1. **Core loop:** "Mark as renewed" + scheduled local notifications. *(Completed)*
2. **Data hygiene:** archived/expired view, filters & sort, renewal history. *(Filters, sort, & status views completed)*
3. **Money automation:** recurring transactions, budget alerts, categorization rules. *(Recurring & budget alerts completed)*
4. **Tier glue:** renewal payment loop + auto-envelope from outlook. *(Payment loop completed)*
5. **AI:** OCR auto-fill + Arabic/English + type detection.
6. **Polish:** app lock, dark mode, Arabic localization, VAT assistant, forecast chart.

