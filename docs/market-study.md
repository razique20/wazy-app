# Wazy — Market Study

> UAE financial budgeting intelligence & document-expiry tracking · September 2026
> Companion to [technical-documentation.md](technical-documentation.md) and [feasibility-study.md](feasibility-study.md)

> **Methodology note:** figures below are directional estimates assembled from public knowledge of the UAE market (population, visa/ID cycles, published fine schedules, SME contribution to GDP) and from the app's own category model. They are good enough for a go/no-go and pricing-shape decision, not for an investor deck. Replace with sourced numbers before external use.

---

## 1. The problem

UAE residents and SMEs operate under a dense web of expiry-gated documents: trade licences, Ejari tenancy registrations, residence visas, Emirates IDs, labour cards, vehicle registrations (Mulkiya), driving licences, health and vehicle insurance, and dozens of recurring permits and subscriptions. Missing a renewal is not a minor inconvenience — it triggers a predictable cascade:

| Missed item | Typical immediate consequence |
|---|---|
| Trade licence | Fines plus activity suspension; banks and counterparties freeze dealings on an expired licence |
| Residence visa | Overstay fines; the sponsor (individual or company) is liable |
| Emirates ID | Service access breaks: banking, SIM, government portals |
| Vehicle registration | Fines plus possible impoundment; insurance becomes invalid |
| Insurance (vehicle/health) | Coverage gap — claims denied, retroactive liability |
| Ejari | DEWA and tenancy processes stall |

The pain is **structural, not episodic**: a single SME founder tracks 10–30 live expiry dates across personal and company documents; a family household tracks 5–15. Every item has a different renewal cycle (1–3 years), a different authority (GDRFA, ICP, MOHRE, DED, RTA, MOI, insurers…), and a different fee — which is why people currently manage this with calendar events, WhatsApp reminders from PRO agents, sticky notes, and memory.

The second half of the pain is **financial**: renewals arrive as lumpy, predictable-but-forgotten cash outflows (a licence renewal alone can run AED 10k+). Households and small businesses get blindsided by the *total* quarterly renewal bill, not by any single fee.

## 2. Target market

### 2.1 Segments (by fit)

| Segment | Size signal | Willingness to pay | Wazy fit |
|---|---|---|---|
| **Solo founders & freelancers** (free-zone licences) | Large and growing free-zone base (Dubai alone hosts tens of thousands of active free-zone entities) | Medium — will pay to avoid one fine | **Primary.** Tracks both personal (visa/EID) and company (licence/Ejari) docs; renewal-cost outlook is exactly their cash-flow anxiety |
| **PRO / corporate services providers** (manage renewals for dozens of clients) | Meaningful niche with high concentration of pain | **High** — this is their operational software | **Expansion.** Multi-collection model already mirrors "one workspace per client" |
| **Expatriate households** | UAE population ~9–11M, roughly 85%+ expatriate — nearly every household has visa + EID + insurance cycles to track | Low–medium (consumer app) | **Volume.** Free tier drives adoption; family sharing is the upsell |
| **SMEs with 5–50 staff** | SMEs contribute ~50%+ of Dubai's GDP; every one runs visa/labour/insurance renewals | Medium–high | **Secondary.** Needs assignment + shared collections (partially built: `assigned_to`) |
| Landlords / vehicle-heavy individuals | Portfolio owners with multiple Mulkiya/Ejari cycles | Medium | Niche |

### 2.2 Why the UAE specifically

- **Expiry density:** residency (visa + EID) cycles every 1–2 years for nearly every resident, on top of business and vehicle documents — few markets stack this many government expiries per person.
- **Digitized government rails (ICP/GDRFA/DED apps) handle the transaction, not the remembering.** None of them offer a unified "what do I owe renewal on, across my whole life, and when" view — that gap is Wazy's wedge.
- **Fine schedules are public and steep**, which makes the app's core value proposition ("never pay an avoidable fine again") concrete and quantifiable.
- **High smartphone payment culture**; consumers are habituated to paying for super-apps (Careem, Talabat Pro etc.), so a freemium utility is plausible.

## 3. Competitive landscape

| Player (category) | What they do | Gap Wazy exploits |
|---|---|---|
| **Government super-apps** (ICP UAEICP, GDRFA Dubai, DED, RTA) | The authoritative way to renew *one* document, often with own notifications | Each silo only knows its own documents. No cross-document radar, no fees outlook, no finance layer |
| **Calendar / reminders** (iOS/Google Calendar, Todoist) | Generic date reminders | Zero domain knowledge: no renewal windows, no urgency ladder, no fee tracking, no authority metadata |
| **Generic expense trackers** (Money Manager, spends apps) | Budgets and categories | No documents. Wazy's wedge is that renewals are a *predictable expense stream* they don't model |
| **PRO agencies / hard-copy desk files** | Human-run renewal management for SMEs | High cost, no self-service dashboard, opaque fees |
| **Regional SME admin tools** (Zoho etc.) | Broad ERP suites | Renewal expiry tracking is incidental, not the product; heavy for a solo founder |

**Positioning statement:** *Wazy is the financial intelligence hub for life and business in the UAE — budgets, cash-flow forecasts and every licence, visa, ID and insurance countdown on one dashboard, with the money to renew it planned ahead.*

The defensible wedge is the **document↔finance join**: renewal fees feed a cash-flow forecast, and the forecast surfaces "you need AED 16,420 in renewal outflows in the next 90 days" — neither document trackers nor finance apps do both.

## 4. Product–market signals (from the build so far)

- The app's category model mirrors how users actually think: 15 built-in UAE document types, each with its typical renewal authority and cycle, plus custom types — established from the domain, not invented.
- The urgency ladder (90/60/30/7 → WhatsApp escalation) matches how PRO agents actually escalate; the detail screen renders it natively.
- Bill-spike detection and budget alerts were built for the second-order pain: renewal *and* running costs landing in the same month.
- Custom reminder offsets and the 90-day cash-flow forecast came from the same insight: people need to *plan around* renewal dates, not just be reminded of them.

## 5. Demand estimate (order-of-magnitude)

- UAE addressable individuals (expatriate adults + SME owners): **several million**.
- Realistically reachable early audience (English-first, SME/solo-founder networks, free-zone communities, Reddit/Facebook UAE groups): **tens of thousands**.
- A realistic 12-month objective for a bootstrapped launch: **5–15k registered users**, conversion of **2–5% to a paid tier** — sufficient to validate willingness to pay before investing in PRO-team features.

## 6. Monetization options (to be validated)

| Tier | Contents | Shape |
|---|---|---|
| Free | 1 collection, up to ~10 documents, local reminders | Volume + habit formation |
| Plus (~AED 5–10 / month or ~AED 50/yr) | Unlimited docs, company collections, cash-flow forecast, PDF/CSV exports, custom alert days | Individual power users |
| Business (~AED 25–50 / month) | Multiple company workspaces, assignment, renewal audit history, exports | PROs & small SMEs — highest ARPUs |

Adjacent revenue once trust exists: **renewal concierge** (partnered PRO filing for a fee per renewal) — this is where the market's real money is, but it is a services business and deliberately out of scope pre-PMF (see feasibility study §5).

## 7. Risks specific to the market

| Risk | Mitigation |
|---|---|
| Government apps add expiry dashboards | They optimize their own silo; a neutral cross-document layer + finance join stays differentiated. Move fast on habit formation |
| Reminder fatigue → uninstalls | Escalation ladder is frequency-capped and user-tunable (custom alert days); alerts respect per-user toggles |
| Trust: users store sensitive document metadata | Local-first architecture (data stays on device in local-only mode), RLS-scoped backend, no server-side document bytes yet — privacy is a *feature* to market |
| iOS/Android notification permissions friction | Onboarding explains value before the prompt; local notifications (not push) keep the free tier cost-free to operate |

## 8. Conclusion

The UAE market has a dense, recurring, fine-backed set of expiry obligations and no incumbent that unifies them with the money to renew them. The pain is severe for solo founders and SMEs, chronic for expatriate households, and the current solutions (government silos, calendars, PRO agents) are all partial. Wazy's document+finance join is a credible wedge into a freemium utility with a clear expansion path into PRO/SME team workflows. The immediate next step is the validation loop described in the feasibility study (§6): a real-device pilot with 20–50 solo founders, measuring 30-day retention and the alert-to-renewal conversion rate.
