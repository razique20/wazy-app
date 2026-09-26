# Finavig — Feasibility Study

> Technical, operational, financial and legal feasibility of shipping Finavig as a product · September 2026
> Companion to [technical-documentation.md](technical-documentation.md) and [market-study.md](market-study.md)

---

## 1. Executive summary

| Dimension | Verdict | Key finding |
|---|---|---|
| **Technical** | ✅ Feasible | Core product (offline-first tracker + local notifications + finance module) is built and tested; backend is standard Supabase. Remaining work is release engineering, not invention |
| **Operational** | ✅ Feasible | Single-maintainer friendly: free-tier infra, no servers to run, support surface small |
| **Financial** | ✅ Feasible | Runs inside free tiers to thousands of users; biggest cost is time, not cash |
| **Legal / regulatory** | ⚠️ Feasible with care | As a *tracker* it is low-regulation. The moment it touches payments or files anything with government, the compliance envelope changes materially |
| **Overall** | **GO** for a pilot launch after the release-blocking checklist (§7) | Validation-first: 20–50 real users before any paid marketing |

---

## 2. Technical feasibility

### 2.1 What already works (evidence)

- **Full feature set implemented and tested:** document CRUD with OCR pre-fill, urgency ladder, custom alert offsets, finance ledger with budgets/envelopes/recurring, 90-day cash-flow simulation, bill-spike detection, CSV/PDF exports. 20 test suites cover the pure-logic core (sync contract, finance math, recurrence, anomaly thresholds).
- **Offline-first architecture proven:** local-only mode is a first-class citizen (it is how unit tests and the docs screenshot pipeline run — see `tool/capture_screens.mjs`). Backend outages degrade to "sync later", never to data loss.
- **Backend is boring-on-purpose:** Supabase Postgres + RLS. The riskiest historical bug class (schema drift silently killing sync) is fixed at the root with client-side row sanitization against a column whitelist (technical documentation §4.2).

### 2.2 Remaining technical risk

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Attachment files are device-local; uninstall = loss | Certain today | Medium — metadata survives, bytes don't | Supabase Storage bucket (schema-ready; ~1 day of work). Before that, document the limitation prominently |
| ML Kit OCR accuracy on real-world scans | Medium | Low–medium | The flow already treats OCR as *pre-fill for human review*, never auto-save. Worst case is manual entry |
| Local-notification reliability across OEM battery savers (esp. Android) | Medium | **High** — missed alert is the core promise broken | Test on Xiaomi/Huawei/Samsung early; the server-side `reminders` table + FCM path (§6) is the durable fix |
| Single-postgres-vendor lock-in | Low | Low | Schema is plain SQL; portable |
| Flutter web as a demo surface | Known | Low | Web is docs/demo only; ML Kit and notifications degrade there by design |

### 2.3 Engineering effort to public launch

| Workstream | Estimate |
|---|---|
| Android release signing + iOS distribution setup | 0.5–1 day |
| Supabase Storage for attachments + UI upload/progress | 1–2 days |
| Crash reporting (Sentry) + basic analytics | 0.5 day |
| CI (analyze + test on PR) | 0.5 day |
| Store listing assets, privacy policy, data-safety forms | 1 day |
| Real-device notification QA (3–5 Android OEMs + iOS) | 1–2 days |
| **Total** | **~5–8 focused days** |

## 3. Operational feasibility

- **Team:** the codebase was built and is maintained by one developer. Services are singletons with pure-logic cores — the architecture explicitly optimizes for this: features are testable without a backend, and docs/screenshots regenerate with one command.
- **Support surface:** no servers to operate (Supabase free/pro tier is managed). User issues will concentrate on (a) notifications not firing on aggressive OEMs and (b) OCR misses — both have in-app mitigations already (manual re-scan, manual entry).
- **Release cadence:** the `app_versions` splash check already supports force-update gating, so shipping hotfixes to the whole base without app-store latency is possible.

## 4. Financial feasibility

### 4.1 Cost structure (bootstrapped pilot → early scale)

| Item | Pilot (0–1k users) | Growth (10–50k users) |
|---|---|---|
| Supabase | **Free** (500 MB DB / 1 GB storage / 50k MAU) | **$25/mo** Pro, likely sufficient for years at this usage profile |
| Local notifications (the alert engine) | **$0** — on-device | $0 + push infra only if FCM path is added (Firebase free tier) |
| Crash reporting | **Free** (Sentry/Crashlytics dev tiers) | ~$26/mo |
| App-store fees | $100/yr Apple + $25 one-off Google | same |
| **Total cash burn** | **≈ $125 first year** | **≈ $600–1,200/yr** |

The economics are dominated by the fact that the core alert engine is on-device. The database stores small rows; even 50k documents is well under 100 MB.

### 4.2 Revenue plausibility (from market study §6)

- 10k registered users × 3% paid × ~AED 50/yr ≈ **AED 15k/yr** — covers costs and proves willingness to pay.
- The PRO/business tier (AED 25–50/mo) is the economically interesting one; 20 business accounts alone would exceed the consumer tier at 10× the effort of none of the regulatory complexity of payments/filing.

**Break-even is trivially reachable; the question is not money, it is retention.**

## 5. Legal & regulatory feasibility (UAE)

> Not legal advice; a checklist of the envelopes that matter.

| Topic | Assessment |
|---|---|
| **App category** | A personal productivity/tracker app is **low-regulation**. No licence is required merely to remind users of dates or to keep a private expense ledger |
| **Handling payments / filing renewals on users' behalf** | This **would** change the picture (payment-service and agency/BPO considerations). The roadmap explicitly parks "renewal concierge" until post-PMF, and the savings-envelope feature is tracking-only by design |
| **Data protection** | UAE PDPL applies: privacy policy, purpose limitation, secure storage, deletion on request. The architecture helps: local-first (data on device), RLS-scoped server rows, no third-party analytics required at pilot. Store listings require a privacy policy URL and data-safety declarations either way |
| **Document attachments** | Storing scans of IDs/licences raises sensitivity; the current device-local design is the *most* defensible posture. If/when Storage sync ships: bucket stays private, per-owner path policy, and consider optional encryption at rest client-side |
| **Gemini API (optional AI features)** | Key is user-provided and optional; if enabled server-side later, keep it out of the client bundle |
| **WhatsApp alerts** | Only via official Meta Cloud API from a server; UI already labels it "coming soon" |

## 6. Go-to-market feasibility

- **Channel 1 — communities:** UAE expat and founder groups (Reddit r/dubai, Facebook UAE business groups, free-zone newsletters). The product screenshots are self-explanatory; the fine-avoidance angle writes its own copy.
- **Channel 2 — PRO/service agents:** they feel the multi-client pain daily; the multi-collection model maps 1:1 to "one workspace per client". A handful of friendly PROs would be ideal design partners.
- **Channel 3 — ASO:** "document expiry reminder UAE", "trade licence renewal", "visa expiry tracker" are searched, specific, and contested only by government apps that don't do this job.
- **Validation metrics (pilot, 30 days):** D7 retention >25%, ≥40% of users with ≥1 tracked document firing an alert, ≥25% alert→renewal completion within window, <2% uninstall-within-48h-after-alert (the fatigue tell).

## 7. Go / no-go checklist

**Must be green before pilot launch:**

- [ ] Android release signing; iOS distribution profile
- [ ] Supabase fields migration applied to the production project (`migrate_documents_local_only_fields.sql`) and smoke-tested
- [ ] Attachment limitation either fixed (Storage bucket) or explicitly messaged in-app
- [ ] Notification QA passed on Samsung + Xiaomi + iOS (the OEM battery-saver pass)
- [ ] Sentry wired; CI running analyze+test on PR
- [ ] Privacy policy live; store data-safety forms completed
- [ ] 20–50 pilot users recruited from §6 channels with a feedback channel open

**Deliberately out of scope for the pilot:** push notifications (FCM/APNs), WhatsApp/email alerts server wiring, payments, renewal concierge, team collaboration features, Arabic localization.

## 8. Conclusion

Finavig is feasible on every axis that matters at this stage: the hard software is written and tested, the operating costs are negligible, the regulatory envelope for a tracker is light as long as the product stays a tracker, and the market study identifies reachable early adopters whose pain is quantifiable in avoided fines. The single highest-leverage technical investment before scale is the server-side push path (the `reminders` table is already the ready data source) because on-device notifications are the one component the developer cannot fully control. Proceed to the §7 pilot.
