# Implementation Backlog

App: **Wazy** — a two-tier operations app for UAE SMEs:

- **Tier 1 — Documents (Home & Documents tabs):** expiry tracking, reminders, renewals, OCR scanning & natural-language input.
- **Tier 2 — Money (Money tab):** transaction log, category budgets, savings envelopes, 90-day cash flow forecast.

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
- Archived & expired documents view with status filter toggles
- Global live search across documents & transactions with debounced inverted matcher
- CSV & PDF report export via native share sheet
- Recurring transaction templates (monthly/quarterly/yearly) with auto-logging & catch-up
- Budget threshold alerts (80% & 100% warnings via OS notification, snackbars, & tab badge dots)
- Renewal payment loop (Tier 1 & Tier 2 integration in both directions)
- Duplicate transaction detection with soft warning dialogs
- Cash-flow 90-day forecast chart with daily balance projections & renewal dips
- OCR scan → auto-fill (Google ML Kit text recognition for UAE Trade License, Visa, Ejari, Mulkiya, Emirates ID) with pre-fill review & user confirmation
- Auto document-type detection from OCR text
- Natural-language quick add ("Add my trade licence, expires 12 March 2027 cost 1500 AED") with parser & interactive dialog
- Dark mode & system theme switching (`ThemeService`)
- Renewal history timeline per document (logs past renewal dates, fees, notes, and renewed-by user)
- Per-document reminder overrides (custom alert days preset chip picker & OS notification rescheduling)

---

## Remaining Backlog & Feature Ideas

### Tier 1 — Documents (core loop)

- [ ] **Notes & attachments** per document (photos of receipts, PDFs multi-attachment view).

### Tier 2 — Money

- [ ] **Categorization rules** — "any title containing DEWA → Utilities"; runs on save and can retro-apply to existing records.
- [ ] **Auto-envelope from outlook** — one tap on the renewal outlook card creates/refreshes an envelope per upcoming renewal (target = renewal fee).
- [ ] **Receipt photo attachment** per transaction (reuse `file_picker`).
- [ ] **VAT assistant** — 5% input/output VAT fields per transaction with a quarterly summary (UAE VAT readiness; no filing claims).

### Platform & UX

- [ ] **Arabic localization (RTL)** — table stakes for the UAE market.

### Security

- [ ] **App lock** — PIN / Face ID via `local_auth` (documents are sensitive).

### AI features

- [ ] **Arabic + English OCR** — ML Kit supports both scripts; bilingual extraction is a real differentiator for UAE documents.

---

## Suggested Next Build Priority

1. **Security:** App lock (PIN / Face ID).
2. **Document Enhancements:** Multi-attachment viewer.
3. **Money Automations:** Categorization rules & VAT assistant.
4. **Localization:** Arabic (RTL) support & bilingual Arabic/English OCR.
