# Feature Ideas & Product Backlog

App: **Wazy** — a two-tier operations app for UAE SMEs:

- **Tier 1 — Documents (Home tab):** expiry tracking, reminders, renewals.
- **Tier 2 — Money (Money tab):** transaction log, category budgets, savings envelopes.

Tier 1 owns _what must be renewed and when_; Tier 2 owns _the money around it_.

---

## Part 1 — Why the home screen feels busy

> **✅ Implemented.** Home now shows header → one attention banner (green
> "all clear" / red "needs attention") → next 3 renewals. Static pills, alert
> cards, stat cards, the 13-type grid and the Money card were removed; Money
> lives in its own bottom-nav tab (`StatefulShellRoute` in `lib/router.dart`).

### Diagnosis

The home screen currently stacks **5 dense sections** on top of each other:

1. Header (avatar + collection switcher + 5 notification pills)
2. Urgency banner
3. "Active alerts" — 4 cards (90/60/30/7 days)
4. "Overview" — 4 stat cards (On track / Upcoming / Critical / Total)
5. "Document types" — 13-item grid
6. "Upcoming" — 5-item list

Specific problems:

- **Duplicated data.** The alert cards and stat cards show the same information twice
  (90/60/30/7-day counts vs On-track/Upcoming/Critical counts — same items, different buckets).
- **Static, fake pills.** The "90-day reminder / 60-day task / 30-day escalation / 7-day WhatsApp /
  UAE-wide coverage" pills are hardcoded labels — they never change and say nothing about the
  user's actual data. They're marketing copy, not UI.
- **13-type grid overwhelms.** All 13 `DocumentType` values always render, even with count 0.
- **No visual hierarchy.** Urgency banner, alert cards, stat cards, and type chips all compete
  with similar size, color, borders, and shadows — nothing reads as "the one thing to do".

### Recommended redesign

| Change                          | Detail                                                                                                                                                                                 |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **One hero: "Needs attention"** | The urgency banner becomes the only prominent element. When there's nothing urgent, show a calm green "All documents on track ✓" instead.                                              |
| **Merge stats into one strip**  | Replace the 8 cards (alerts + stats) with a single compact row: `Total · Critical · Upcoming · Expiring 90d` as tappable filter chips that deep-link into `/expiry-list` pre-filtered. |
| **Delete the static pills**     | Move the escalation-tier explanation (90/60/30/7-day policy) into Profile → "How reminders work" or onboarding. Home shows _live counts_, not policy text.                             |
| **Hide empty doc types**        | Only show types with `count > 0` (plus an "All types" entry). With few documents the grid collapses to 2–3 chips instead of 13 tiles.                                                  |
| **Shorten Upcoming list**       | Show 3 items + "View all (n)". Five full-width tiles push everything below the fold.                                                                                                   |
| **Bottom navigation**           | `Home / Documents / Activity / Settings` — moves Documents, alerts history, and settings off the home stack.                                                                           |
| **Calm the palette**            | One accent color for urgency (red → orange → neutral). Mute the rainbow of per-type colors; keep type colors only inside the detail/list screens.                                      |
| **First-run empty state**       | When a collection has 0 documents, show a single centered onboarding card ("Scan your first document") instead of all 6 empty sections.                                                |

Suggested new section order:
`Header (greeting + collection switcher)` → `Attention banner` → `Next 3 renewals` →
`Compact stats strip` → `Add document CTA` → everything else behind tabs/sheets.

---

## Part 2 — Tier 1 features (Documents) — non-AI

### Core tracking

- [ ] **"Mark as renewed" flow** — one tap sets `expiresAt += typicalRenewalDays`, logs renewal history.
- [ ] **Renewal history timeline** per document (who renewed, when, cost).
- [ ] **Custom document types** — let users add types beyond the 13 built-in ones.
- [ ] **Per-document reminder overrides** — custom alert days (e.g. 45 days instead of the tier default).
- [ ] **Notes & attachments** per document (photos of receipts, PDFs).
- [ ] **Cost fields** — `amount_due`, `last_paid_amount`, `currency` on `expiry_items`
      (already planned in FINTECH_ROADMAP Phase 0; powers payments later).
- [ ] **Archived / expired documents view** — history instead of deletion.
- [ ] **Multi-entity support** — collection = legal entity (already partly there); add TRN, licence number per entity.

### Notifications & alerts

- [ ] **Scheduled local notifications** (`flutter_local_notifications`) — currently the tiers are computed but nothing schedules OS-level reminders.
- [ ] **Email digest** (weekly summary of what's expiring) via Supabase Edge Function + Resend/SMTP.
- [ ] **WhatsApp alerts** via WhatsApp Business API (the 7-day tier implies it — make it real).
- [ ] **Calendar sync** — subscribable ICS feed of all expiries.

### Search, list & data

- [ ] **Global search** across documents (name, number, notes).
- [ ] **Filters & sort** in `/expiry-list` (type, status, collection, days remaining).
- [ ] **CSV / PDF export** of the expiry report (accountants love this).
- [ ] **Offline-first** — local cache with Supabase sync + conflict resolution.
- [ ] **Realtime updates** — Supabase realtime so team members see changes live.

### UX & platform

- [ ] **Dark mode**.
- [ ] **Home-screen widget** (iOS/Android) showing the next expiring document.
- [ ] **Calendar view** of expiries (month grid).
- [ ] **Arabic localization (RTL)** — table stakes for the UAE market.
- [ ] **Onboarding tour** — explains the 90/60/30/7 escalation model once, then gets out of the way.

### Security & teams

- [ ] **App lock** — PIN / Face ID via `local_auth` (documents are sensitive).
- [ ] **Team seats & roles** — share a collection with an accountant (view) or PRO (renew).
- [ ] **Audit log** — who changed what (also a FINTECH_ROADMAP Phase 0 prerequisite).

### Growth & monetization

- [ ] **Free / Pro tiers** — free: 10 documents; Pro: unlimited, teams, exports, autopay.
- [ ] **Feature flags** — cohort rollouts (FINTECH_ROADMAP prerequisite).
- [ ] **Referral program** — invite a business, both get Pro months.
- [ ] **Renewal marketplace** — later Phase 1: "Renew now" button → PSP checkout (see FINTECH_ROADMAP).

### Tier 1 — new additions

#### Intelligence on top of tracking

- [ ] **Document dependency graph** — a visa needs an Emirates ID, Ejari needs a
      trade licence. Flag documents whose dependency is expiring/expired
      ("your visa can't renew — Emirates ID expires first").
- [ ] **Emirate-specific rules** — renewal windows and authorities differ
      (Dubai DED vs Abu Dhabi ADDED). Encode per-emirate grace periods and portals.
- [ ] **Per-type renewal checklist** — "trade licence renewal needs: valid Ejari,
      tenancy contract, passport copy" shown on the detail screen.
- [ ] **Authority deep links** — one tap opens DED / GDRFA / RTA / MOHRE portals
      for that document type.

#### Capture & data quality

- [ ] **Duplicate detection on scan** — same document number or near-identical
      file → warn before creating a second record.
- [ ] **Bulk import** — CSV/spreadsheet import of existing documents (name, type,
      number, expiry) for fast onboarding of SMEs with 50+ documents.
- [ ] **Scan quality check** — blur/glare detection before saving, so evidence
      stays readable.
- [ ] **Renewal channel tracking** — record _how_ each renewal was done
      (portal / office / agent) next to the history timeline.

#### Workflow & sharing

- [ ] **Bulk actions in /expiry-list** — select many → mark renewed / assign /
      set reminder in one pass.
- [ ] **Reminder routing** — send the 60-day task to the accountant and the
      7-day WhatsApp to the owner (per-document or per-type contact rules).
- [ ] **Shareable compliance card** — export one document as a clean PDF/PNG
      card (name, number, valid-until) to send to landlords/partners.
- [ ] **HR visa audit report** — one PDF listing every employee visa with days
      remaining, exportable for PRO/HR reviews.
- [ ] **Notification tuning per alert tier** — silence the 90-day nudge, keep
      only 30-day and 7-day (user preference, not global).

---

## Part 3 — Tier 2 features (Money)

**Shipped:** transaction log (income/expense), monthly category budgets,
savings envelopes, 90-day renewal outlook, CSV export.

### Automation

- [ ] **Recurring transactions** — mark rent/salaries/software as monthly and
      auto-log them instead of manual repeats.
- [ ] **Categorization rules** — "any title containing DEWA → Utilities";
      runs on save and can retro-apply to existing records.
- [ ] **Auto-envelope from outlook** — one tap on the renewal outlook card
      creates/refreshes an envelope per upcoming renewal (target = renewal fee).
- [ ] **Envelope automations** — the monthly contribution executes itself
      (tracking only; no money moves, per FINTECH_ROADMAP licence posture).
- [ ] **Renewal payment loop (tier glue)** — logging a `renewals` transaction
      linked to a document offers "Mark document as renewed ✓", closing the
      loop between the two tiers.

### Insight & forecasting

- [ ] **Cash-flow forecast chart** — 90-day line: projected balance vs upcoming
      renewal outflows.
- [ ] **Runway indicator** — "at current burn: 4.2 months" derived from the net
      trend and envelope commitments.
- [ ] **Budget alerts** — snackbar/notification at 80% and 100% of a monthly
      budget; surface a badge on the Money tab.
- [ ] **Month-over-month comparison** — per-category delta vs last month
      ("Marketing +AED 1,200 vs October").
- [ ] **Vendor insights** — top payees this quarter; flags subscription creep.

### Data entry & quality

- [ ] **Receipt photo attachment** per transaction (reuse `file_picker`).
- [ ] **Transaction splitting** — one AED 5,000 receipt split across
      rent + utilities.
- [ ] **Duplicate transaction detection** — same amount/title/day → confirm
      before saving.
- [ ] **Bank statement import** — CSV with column mapping + suggested rules.

### Reporting & compliance

- [ ] **Accountant pack (PDF)** — monthly P&L, budget progress and upcoming
      renewals behind one share button.
- [ ] **VAT assistant** — 5% input/output VAT fields per transaction with a
      quarterly summary (UAE VAT readiness; no filing claims).
- [ ] **AR tracking** — simple "who owes the business" invoice list with aging;
      feeds the Phase 3 credit data in FINTECH_ROADMAP.
- [ ] **Per-entity view** — budgets/transactions filtered by collection (legal
      entity), with an all-entities roll-up.
- [ ] **Multi-currency** — non-AED expenses converted at entry rate; AED stays
      the reporting currency.

---

## Part 4 — AI features

### Quick wins (on-device, cheap, private)

| #   | Feature                          | How                                                                                                                                                                                                                           |
| --- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **OCR scan → auto-fill**         | `google_mlkit_text_recognition` (on-device, free). Scan a trade licence / visa / Ejari certificate → pre-fill name, number, expiry date, emirate. Biggest UX upgrade available — the scan flow currently has zero extraction. |
| 2   | **Auto document-type detection** | Classify the OCR text into one of the 13 `DocumentType` values (keyword rules first, tiny model later). Removes the manual type-picker step.                                                                                  |
| 3   | **Arabic + English OCR**         | ML Kit supports both scripts. Bilingual extraction is a real differentiator for UAE documents.                                                                                                                                |
| 4   | **Natural-language add**         | "Add my trade licence, expires 12 March 2027" → parsed into an `ExpiryItem` (regex/date parser + small LLM call).                                                                                                             |
| 5   | **Smart expiry-date extraction** | Specialized parsing for visa stickers, Mulkiya, Ejari certificates — date formats on UAE docs are irregular.                                                                                                                  |

### Medium effort (server-side, needs an LLM/embedding budget)

| #   | Feature                          | How                                                                                                                                     |
| --- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 6   | **Ask-your-documents assistant** | RAG: embed documents + notes into Supabase `pgvector`, chat UI answers "which visas expire before Christmas?"                           |
| 7   | **Weekly AI summary**            | LLM-written digest: "3 renewals this month, ~AED 4,200 total; your trade licence is the most overdue-prone." Push notification + email. |
| 8   | **Renewal cost prediction**      | Predict next renewal cost from history + type averages; feeds the "set aside" wallet idea in the fintech roadmap.                       |
| 9   | **Auto-categorize uploads**      | Drop-in PDFs/photos get classified, named, and attached to the right entity without manual entry.                                       |
| 10  | **Missing-info detection**       | Model checks scanned docs for missing fields (e.g. licence number unreadable) and prompts the user to fix before saving.                |
| 11  | **Smart prioritization**         | Learn per-user behavior (which renewals are habitually late) and re-rank the "Needs attention" queue accordingly.                       |

### Advanced / differentiated

| #   | Feature                                                         | How                                                                                                                                                                          |
| --- | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 12  | **Compliance copilot**                                          | Step-by-step renewal guidance per authority (DED, GDRFA, RTA, MOHRE): required documents, fees, portals. LLM + curated UAE process knowledge base, served via Edge Function. |
| 13  | **Email auto-detection**                                        | User forwards renewal emails to an app address; LLM extracts the document + expiry and files it automatically. Turns tracking from manual to passive — biggest moat feature. |
| 14  | **Document tamper/anomaly checks**                              | Flag mismatched fonts, edited dates on uploaded PDFs — valuable for teams verifying employee-submitted documents.                                                            |
| 15  | **Bank/Open-finance auto-detection** (Phase 4, fintech roadmap) | Recurring charges detected from bank data → auto-create subscription/domain expiry items.                                                                                    |

### AI infrastructure notes

- Keep **all LLM calls server-side** (Supabase Edge Functions) — API keys never ship in the app.
- **On-device ML Kit** for OCR/classification: free, private, works offline — do extraction on-device, only complex reasoning server-side.
- `pgvector` (Supabase) for embeddings/RAG; store the consent record per FINTECH_ROADMAP's consent ledger.
- Log token/cost per feature so AI features don't silently eat margin on the free tier.

---

## Suggested build order

1. ✅ **Home screen redesign** (Part 1) — shipped with the two-tier bottom nav.
2. **OCR auto-fill + type detection** (AI #1–#3) — transforms the scan flow.
3. **"Mark as renewed" + scheduled notifications** — closes the core Tier 1 loop.
4. **Tier 2 automation** (Part 3): recurring transactions + categorization rules
   - budget alerts — makes Money feel alive without manual entry.
5. **Tier glue**: auto-envelope from outlook + renewal payment loop.
6. **Forecasting**: cash-flow chart + runway + accountant pack.
7. **AI differentiators** (Part 4): weekly summary → RAG assistant → email
   auto-detection.
