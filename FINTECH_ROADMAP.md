# Fintech Transformation Roadmap

**From:** Wazy (financial budgeting & intelligence with document expiry tracking)
**To:** Financial operating system for UAE SMEs — where deadlines become transactions.

---

## Why this app is a strong fintech wedge

Every tracked document (trade licence, Ejari, visa, insurance, domain, subscription)
has three things fintech monetizes:

1. **A payment due date** — renewal is a guaranteed, recurring payment intent.
2. **A known amount** — the business must pay to stay compliant.
3. **Trust at the moment of urgency** — users open the app when money must move.

The current product already owns the deadline. The pivot is to own the money that
meets the deadline.

---

## Phase 0 — Foundations to build NOW (while growing users)

Do these before any payment feature; they cost little now and are painful to retrofit.

### Product / architecture
- [ ] **Move all money-adjacent logic server-side.** Supabase Edge Functions for
      anything involving amounts, fees, or vendor calls. The Flutter client should
      never be trusted with pricing.
- [ ] **Design a double-entry ledger schema** (immutable, append-only):

  ```sql
  -- sketch, add to supabase/ when Phase 1 starts
  transactions (id, owner_id, collection_id, document_id, kind, status,
                currency, amount, fee_amount, provider, provider_ref,
                idempotency_key, created_at)
  ledger_entries (id, transaction_id, account, direction, amount, created_at)
  payment_methods (id, owner_id, provider_token, brand, last4, expiry, is_default)
  consents (id, owner_id, scope, granted_at, revoked_at, policy_version)
  ```

- [ ] **Idempotency keys on every write** that can be retried (payments, webhooks).
- [ ] **Immutable audit log** (who did what, when) — regulators will ask.
- [ ] **Consent ledger** from day one: every data use tracked with a versioned
      policy the user accepted. This is the legal backbone for lending/scoring later.
- [ ] **Document `amount_due` / `last_paid_amount` fields** on expiry items —
      the data that later powers auto-pay, invoicing, and credit scoring.
- [ ] **Feature-flag system** so paid features roll out per cohort.

### Business
- [ ] Instrument the funnel: which document types are renewed most? Those are the
      first payment verticals (typically trade licence + Ejari + insurance).
- [ ] Talk to 20 users: "Would you pay this renewal here?" — validate before building.

---

## Phase 1 — Embedded payments (first revenue)

**Licence posture:** you are a *payment facilitator / facilitation platform*, not a
money transmitter. Partner with a licensed PSP; funds flow through them.

### Features
- [ ] **Pay renewals in-app** for the top 3 document types. Flow: reminder →
      "Renew now" → amount preview → PSP checkout → receipt attached to the document
      → status auto-updates to renewed.
- [ ] **Apple Pay / Google Pay** (highest conversion in UAE).
- [ ] **Card on file / auto-renew** — one toggle per document: "Auto-pay 14 days
      before expiry." This is the killer feature: recurring revenue + real lock-in.
- [ ] **BNPL for large renewals** (trade licences can be AED 10k+) via Tabby/Tamara.
- [ ] **Service fee / take-rate** per transaction (e.g. 1–3%) — check PSP terms on
      surcharging.

### UAE PSP options to evaluate
| Provider | Notes |
|---|---|
| Checkout.com | Strong UAE presence, good APIs |
| Network International | Largest regional acquirer |
| Telr, PayTabs, Amazon Payment Services | SMB-friendly |
| Stripe | Available in UAE |
| Tabby / Tamara | BNPL, embeddable |

### Compliance prerequisites
- Company licence covering payment facilitation; agreement with the PSP.
- **Never store card numbers** — use PSP SDKs / hosted fields / tokenization (PCI scope stays with PSP).
- Clear pricing disclosure; receipts; refund flow.

---

## Phase 2 — Money features (wallet & collections)

**Licence posture:** holding client money in the UAE = Stored Value Facility /
Retail Payment Services licence from CBUAE, **or** an escrow/partner-bank structure.

- [ ] **Renewal Wallet ("set aside")** — round-up or scheduled micro-deposits per
      document so money for renewals is pre-funded. Start as *goal tracking only*
      (no custody = no licence), then enable custody via partner bank escrow.
- [ ] **Multi-document auto-pay rules** ("never miss a renewal" subscription tier).
- [ ] **Invoicing / get paid** — SMEs invoice their clients; you take a cut. Adds
      AR data that feeds lending later.
- [ ] **Corporate expense cards** via a BIN sponsor (e.g. Nymcard, partner banks) —
      card spend data completes the financial picture.
- [ ] **Tiered SaaS plans** layered on top (free tracking → paid payments + autopay
      → team seats, API access).

---

## Phase 3 — Credit & insurance (data monetization)

**Licence posture:** lending requires a banking/finance partner or a licence.
Insurance distribution requires an Insurance Authority registration (or embedded
partner model).

- [ ] **SME credit line / invoice financing** — you have years of renewal-payment
      history: who pays on time, revenue signals, business stability. With consent,
      this underwrites small working-capital offers. Do it *with* a licensed lender
      first (revenue share), get your own licence later.
- [ ] **Credit score product for SMEs** (consent-based, bureau-aligned).
- [ ] **Embedded insurance** — distribute business insurance (liability, property,
      cyber) at renewal moments via a licensed broker partnership.
- [ ] **Cross-border / supplier payments** if customers import — partner with
      licensed remitters.

---

## Phase 4 — Open finance & full stack

- [ ] **Bank account aggregation** under the UAE Open Finance framework — connect
      accounts to auto-detect subscriptions and renewals (turns manual tracking into
      automatic; massive product moat).
- [ ] **Full business account** (Wio-style) — only after Phases 1–3 and serious
      capital/licensing; likely via banking-as-a-service partner.
- [ ] **API platform** — let accountants/ERP tools read expiry + payment data.

---

## UAE regulatory map (know before you build)

| Activity | Regulator / requirement |
|---|---|
| Facilitating card payments via PSP | PSP merchant agreement; payment-facilitator terms |
| Holding client funds / wallet | CBUAE — Stored Value Facility / Retail Payment Services licence |
| Lending / credit | CBUAE banking licence **or** licensed partner model |
| Insurance distribution | Insurance Authority registration / broker partnership |
| Crypto-adjacent (if ever) | VARA (Dubai), FSRA (ADGM), DFSA (DIFC) |
| KYC / AML | goAML registration, KYC vendor (IDWise, Focal, Shufti Pro), UAE PASS for identity |
| Data protection | PDPL (Federal Decree-Law 45/2021) — consent, residency, breach rules |
| Sandboxes | CBUAE sandbox, ADGM RegLab, DIFC DFSA Testing Licence — cheapest way to pilot regulated features |

**Rule of thumb until licensed:** never take custody of client funds, never touch
card data, never extend credit yourself. Partner-first keeps you legal while you
validate demand.

---

## Technical prerequisites mapped to this codebase

| Concern | Current state | Action |
|---|---|---|
| Money logic in client | Flutter calls Supabase directly | Add Edge Functions layer for any transaction |
| Ledger | None | Double-entry tables (Phase 0 sketch above) |
| Webhooks | N/A | Idempotent webhook handler + signature verification |
| PCI | N/A (no cards) | Keep it that way — PSP SDK only |
| KYC | Email/password auth only | Add KYC step before first payment (vendor SDK) |
| Notifications | Local reminder engine (good!) | Extend: "Pay now" deep links from WhatsApp/email alerts |
| Collections | Already multi-tenant by owner | Reuse as per-legal-entity scoping for invoices/cards |
| Feature flags | None | Add before monetizing |

---

## Business model evolution

1. **Now:** free tracking → premium SaaS tier.
2. **Phase 1:** take-rate on renewals (1–3%) + autopay subscription.
3. **Phase 2:** interchange share on cards, float income (once licensed), invoice SaaS.
4. **Phase 3:** lending margin share, insurance commission.
5. **Phase 4:** API/platform fees.

---

## Anti-patterns to avoid early

- ❌ Storing card numbers or handling PANs (PCI nightmare, trust killer).
- ❌ Holding user money before licensing — use PSP settlement or partner escrow.
- ❌ Building your own lending stack before validating with a licensed partner.
- ❌ Shadow API-scraping banks — wait for Open Finance / official aggregation.
- ❌ Retrofitting a ledger after money is already flowing.

---

## Immediate next steps (this quarter)

1. Ship Phase 0 schema changes (transactions/consents tables) — no UI needed yet.
2. Add `amount_due` to the document model + scan flow.
3. Pick 2 PSPs, get sandbox accounts, spike "renew now" for ONE document type.
4. Survey users on willingness to pay renewals in-app (validates Phase 1).
5. Book a consult with a UAE fintech lawyer on facilitation-model setup.
