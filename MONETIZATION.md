# Wazy — Monetization Plans

> Consolidated view of how Wazy makes money. Sources: [`docs/market-study.md`](docs/market-study.md) §6,
> [`FINTECH_ROADMAP.md`](FINTECH_ROADMAP.md), [`docs/feasibility-study.md`](docs/feasibility-study.md) §4.2, and the app's Terms & Conditions (§7 Fees).

## Current state

- **Everything is free.** Terms & Conditions state: *"Core tracking features are provided free of charge; optional premium features or payment services may be introduced with clear pricing disclosed before purchase."*
- Cost structure makes this sustainable at pilot scale: the alert engine is on-device and Supabase runs on free/Pro tiers (≈ $125 first-year burn).
- Revenue validation target: **5–15k registered users in 12 months, 2–5% conversion to a paid tier.**

---

## Track 1 — Freemium SaaS tiers (launch monetization)

The core business model: free tracking drives volume and habit formation; power features pay.

| Tier | Price | Contents | Audience |
|---|---|---|---|
| **Free** | AED 0 | 1 collection, up to ~10 documents, local 30/60/90-day reminders, basic budgets | Volume + habit formation |
| **Plus** | ~AED 5–10 / month (or ~AED 50 / year) | Unlimited documents, company collections, 90-day cash-flow forecast, PDF/CSV exports, custom alert days | Individual power users |
| **Business** | ~AED 25–50 / month | Multiple company workspaces, document assignment, renewal audit history, team exports | PROs & small SMEs — **highest ARPUs** |

### Candidate paid-feature gates (mapped to what's already built)

| Feature (shipped) | Tier gate |
|---|---|
| Unlimited documents & custom collections | Plus |
| 90-day cash-flow forecast + dip detection (`FinanceMath.calculate90DayCashFlow`) | Plus |
| PDF/CSV export (`expiry_report.dart`, printing) | Plus |
| Custom reminder offsets / custom alert days | Plus |
| AI monthly executive summary with LLM polish (`MonthlySummaryService` + Gemini) | Plus |
| Multiple company workspaces (multi-collection per client) | Business |
| Renewal audit history, assignment, team exports | Business |
| Voice quick-add, OCR scan-to-fill beyond free quota | Plus (metered) |

### Why the Business tier matters most

From the feasibility study: *"The PRO/business tier (AED 25–50/mo) is the economically interesting one; 20 business accounts alone would exceed the consumer tier at 10× the effort."*

Revenue plausibility at pilot scale:
- 10k registered users × 3% paid × ~AED 50/yr ≈ **AED 15k/yr** — covers costs, proves willingness to pay.
- Break-even is trivially reachable; the real question is retention.

### Adjacent (post-PMF, deliberately parked)

- **Renewal concierge** — partnered PRO filing for a fee per renewal. "Where the market's real money is," but a services business; out of scope before PMF.
- **WhatsApp escalation channel** — server-side via official Meta Cloud API; billed per conversation or bundled into Plus/Business.

---

## Track 2 — Fintech layers (phased, partner-first)

The strategic evolution: Wazy already owns the deadline; monetize the money that meets it. Every tracked document is a guaranteed, recurring payment intent with a known amount — trust peaks exactly when money must move.

### Phase 1 — Embedded payments (first fintech revenue)

- **Pay renewals in-app** for the top 3 document types (typically trade licence, Ejari, insurance): reminder → "Renew now" → PSP checkout → receipt attached → status auto-renews.
- **Apple Pay / Google Pay** first (highest UAE conversion).
- **Card-on-file auto-renew** ("Auto-pay 14 days before expiry") — the killer feature: recurring revenue + lock-in.
- **BNPL for large renewals** (AED 10k+ trade licences) via Tabby/Tamara.
- **Service fee / take-rate per transaction: 1–3%** (check PSP surcharging terms).
- Posture: payment *facilitator* via licensed PSP (Checkout.com, Network International, Telr, PayTabs, Stripe). Never touch card data.

### Phase 2 — Money features (wallet & collections)

- **Renewal Wallet ("set aside")** — round-ups/micro-deposits pre-funding renewals. Start tracking-only (no custody = no licence), then partner-bank escrow.
- **Multi-document auto-pay rules** — "never miss a renewal" subscription tier on top of Business.
- **Invoicing / get paid** — SMEs invoice clients; Wazy takes a cut. Adds AR data feeding lending.
- **Corporate expense cards** via BIN sponsor (e.g., Nymcard) — interchange share + completes the financial picture.
- Regulatory note: holding client money in the UAE = CBUAE Stored Value Facility / Retail Payment Services licence, or partner-bank escrow.

### Phase 3 — Credit & insurance (data monetization)

- **SME credit line / invoice financing** — renewal-payment history underwrites working-capital offers *with* a licensed lender (revenue share) first.
- **SME credit score product** (consent-based, bureau-aligned).
- **Embedded insurance distribution** (liability, property, cyber) at renewal moments via a licensed broker — commission revenue.

### Phase 4 — Open finance & platform

- **Bank account aggregation** under UAE Open Finance — auto-detected subscriptions/renewals turn manual tracking into automatic (major moat).
- **Full business account** via banking-as-a-service partner.
- **API platform** — accountants/ERP tools read expiry + payment data; per-seat / per-call fees.

### Business model evolution summary

1. **Now:** free tracking → premium SaaS tier (Track 1).
2. **Phase 1:** take-rate on renewals (1–3%) + autopay subscription.
3. **Phase 2:** interchange share on cards, float income (once licensed), invoice SaaS.
4. **Phase 3:** lending margin share, insurance commission.
5. **Phase 4:** API / platform fees.

---

## Prerequisites before monetizing

From the fintech roadmap Phase 0 (build while growing users):

- [ ] Feature-flag system — paid features roll out per cohort (none exists yet).
- [ ] Move money-adjacent logic server-side (Supabase Edge Functions); never trust the Flutter client with pricing.
- [ ] Store-backed paywall (RevenueCat / in-app purchases) for Plus/Business on iOS & Android.
- [ ] Consent ledger + immutable audit log — legal backbone for later data monetization.
- [ ] Instrument the funnel: which document types renew most = first payment verticals.
- [ ] Survey 20 users: "Would you pay this renewal here?" before building Phase 1.

## Guardrails

- ❌ Never take custody of client funds before licensing; partner-first keeps you legal.
- ❌ Never store card numbers (PCI stays with the PSP).
- ❌ Never extend credit yourself before a licensed partner validates demand.
- ✅ Always disclose pricing before purchase (Terms §7 commitment).
