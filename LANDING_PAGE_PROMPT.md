# Finavig Landing Page — AI Generation Prompt

> **Instructions**: Copy and paste the prompt below into ChatGPT, Claude, Cursor, v0, Bolt.new, or Lovable to automatically generate a production-grade marketing **Landing Page** (with Terms & Conditions and Privacy Policy pages) for the **Finavig** application.
>
> **Screenshots**: App screenshots live in [`docs/images/`](docs/images/) (`01_splash.png` … `11_profile.png`). Copy them into the generated project's `public/screenshots/` folder before building, or drop in your own — the prompt references them by filename with ready-made captions.

---

```markdown
You are an expert Frontend Web Developer specializing in Next.js (App Router), TypeScript, Tailwind CSS, and modern conversion-focused landing page design.

Build a modern, production-grade **marketing website** for the **Finavig** application — an AI-powered financial budgeting & cash-flow intelligence app with document expiry tracking and renewal alerts, built for personal and small-business use in the UAE.

The site must include **three routes**:
1. `/` — the landing page
2. `/terms` — Terms & Conditions (full legal copy provided below)
3. `/privacy` — Privacy Policy (full legal copy provided below)

---

## 1. Product Story (use this for all copy)

**Finavig** turns paperwork into clarity. Users upload company and personal documents (trade licences, visas, Emirates ID, tenancy contracts, insurance, subscriptions) — AI extracts the dates, amounts and vendors automatically. Finavig tracks spending, budgets and 90-day cash-flow forecasts in one place, and sends renewal alerts 30/60/90 days before every deadline — so the money is always ready when the renewal is due.

**Three feature pillars:**

1. 💸 **Financial Intelligence & Budgeting** — Unified ledger for income & expenses, monthly category budgets with 80/100% alerts, savings envelopes, recurring transaction templates, and a 90-day cash-flow forecast with dip detection.
2. 📁 **Document Expiry Tracking** — Multi-entity collections (Personal / Company), expiry horizon tracking for Emirates ID, trade licences, visas, passports, vehicle registrations, tenancy contracts, insurance and subscriptions, smart 30/60/90-day reminders, and OCR scan-to-fill powered by Google ML Kit.
3. 🧠 **Smart AI Engine** — Natural-language quick add ("Paid AED 450 for DEWA utilities yesterday" → structured transaction), auto-categorization with UAE vendor dictionaries (DEWA, Salik, Talabat, Etisalat…), and bill-spike & anomaly detection vs the 3-month baseline.

**Hero headline (use this or improve it):**
"Every renewal. Every dirham. One dashboard."
Subheadline: "Finavig forecasts your cash flow and tracks every document expiry — trade licences, visas, Emirates ID, insurance — with alerts 30/60/90 days before they're due."

**CTA buttons:** "Download on iOS" / "Get it on Android" (placeholder `#` store links) and a secondary "See how it works" that scrolls to the features/screens section.

---

## 2. Tech Stack

- **Framework**: Next.js 14+ App Router with TypeScript, static export friendly (no server actions needed).
- **Styling**: Tailwind CSS (no config overrides needed inline — use arbitrary values for brand colors).
- **Icons**: `lucide-react`.
- **Components**: Shadcn/Radix primitives where useful (Accordion for FAQ, Dialog, Button). Keep dependencies minimal.
- **Fonts**: `Space Grotesk` via `next/font/google` (same font as the app). Weights 400–700.
- **SEO**: Full metadata (title, description, Open Graph, Twitter card, canonical), `sitemap.ts` and `robots.ts`. Favicon from the logo.

---

## 3. Design System (match the app exactly)

| Token | Hex | Usage |
|---|---|---|
| `navy-primary` | `#23236B` | Primary brand, buttons, headings |
| `navy-dark` | `#1E1B4B` | Gradient partner for navy |
| `cyan` | `#00E5FF` | Accent, links, highlights, CTA glow |
| `cyan-dark` | `#00B8D4` | Accent hover |
| `emerald` | `#00E676` | Success/savings accents |
| `obsidian` | `#0A0E1A` | Dark hero/footer background |
| `charcoal` | `#111827` | Dark cards |
| `slate` | `#1E293B` | Dark borders/surfaces |
| `snow-white` | `#F8FAFC` | Light sections background |
| `safe-green` | `#10B981` | "On track" indicators |
| `warning-amber` | `#FFD740` | "Due soon" indicators |
| `danger-red` | `#FF5252` | "Expiring/expired" indicators |

**Design language:**
- Dark hero + dark footer (`obsidian`), light body sections (`snow-white`) — mirror the app's look.
- Frosted-glass cards: white at low opacity, 1px subtle border, soft blur backdrop, rounded-2xl (the app uses a signature "glass" style).
- Gradient text accents: cyan → navy.
- The hero should feature a phone-frame mockup of the app's Home dashboard screenshot (see section 4) with a subtle glow, tilted slightly.
- Use the app's **urgency color semantics** in UI mockups: green = safe, amber = due soon, red = expiring.
- Fully responsive; mobile-first. Respect `prefers-reduced-motion`. Subtle scroll-reveal animations (fade + translate) only.
- Logo: place `logo.png` (provided with the screenshots) in `public/`; use a white/knockout version on dark backgrounds.

---

## 4. Screenshots Section

Create a `components/ScreenshotShowcase.tsx` that renders framed app screenshots with captions. Images go in `public/screenshots/`. Use these files (from `docs/images/`) and captions:

| File | Caption | Where to use |
|---|---|---|
| `03_home.png` | **Home dashboard** — attention banner, stat tiles, this-month cash summary with pace, renewal outlook | Hero phone mockup |
| `04_documents_list.png` | **Documents radar** — urgency colors, renewal-window progress, fees, filters | Features section |
| `05_document_detail.png` | **Document detail** — urgency timeline, renewal checklist, history, mark-as-renewed | Features section |
| `06_upload_scan.png` | **Upload & OCR scan** — AI pre-fills title, type, expiry, emirate & authority from an image | AI Engine pillar |
| `09_money.png` | **Money dashboard** — budgets with 80/100% alerts, bill-spike detection, spending pace | Finance pillar |
| `10_cash_flow.png` | **90-day cash-flow forecast** — daily balance simulation including renewal outflows | Finance pillar |
| `08_global_search.png` | **Global search** — across names, notes, authorities, files, all collections | Optional extras |
| `07_expiry_list.png` | **Expiry list** — flat chronological view with CSV/PDF export | Optional extras |

Render as a tabbed or horizontally scrollable gallery with device frames; lazy-load below the fold.

---

## 5. Landing Page Sections (in order)

1. **Sticky navbar** — logo, anchor links (Features, Screenshots, How it works, FAQ), CTA button. Glass blur on scroll.
2. **Hero** — headline, subheadline, store badges, phone mockup of `03_home.png`, trust chips ("90-day cash forecast", "OCR scan", "30/60/90-day alerts").
3. **Problem strip** — three stat-style cards: missed trade-licence renewals = fines; scattered renewal dates across calendars & WhatsApp; renewal fees that surprise cash flow.
4. **Feature pillars** — three-column section (Financial Intelligence / Document Expiry / AI Engine) each with icon, copy, and a supporting screenshot.
5. **Screenshot showcase** — the gallery from section 4.
6. **How it works** — 4 steps: ① Create collections (Personal / Company) → ② Scan or upload documents (OCR fills the details) → ③ Get 30/60/90-day alerts → ④ Watch the 90-day cash forecast reserve the money.
7. **Built for the UAE** — mention Emirates ID, Ejari/tenancy, trade licences, RTA vehicle registration, DEWA/Etisalat vendor recognition, AED-first.
8. **FAQ** — accordion with 6–8 questions (What platforms? Is my data safe? Does AI train on my documents? (No.) Can I export data? (CSV/PDF.) Is it free?).
9. **Final CTA** — big gradient band with store badges.
10. **Footer** — logo, tagline, links to `/terms`, `/privacy`, `mailto:support@wazy.app`, WhatsApp, socials (placeholders). Include "© 2026 Finavig. All rights reserved." and "Made in the UAE 🇦🇪".

---

## 6. `/terms` — Terms & Conditions (render this copy verbatim, styled as a legal page with a sticky table of contents)

**Title:** Terms & Conditions — **Last updated: September 2026**

These terms govern your use of Finavig — the financial and document intelligence platform for UAE businesses and individuals. By creating an account, downloading, or using the app or website, you agree to these terms.

1. **The service.** Finavig lets you upload company and personal documents (trade licences, visas, invoices, receipts, tenancy agreements and more), automatically extracts dates, amounts and vendors with AI, tracks spending, budgets and cash-flow forecasts, and sends renewal reminders. Features may evolve; material changes will be communicated in-app or on this site.
2. **Your account.** You are responsible for the accuracy of the email you register and for keeping your password secure. One account per person; company data belongs to the registering organisation. You must be at least 16 years old to use Finavig.
3. **Your documents & data.** You keep full ownership of everything you upload. We process your documents only to provide the service — expiry extraction, reminders, renewal tracking — and never sell your data.
4. **Acceptable use.** Do not upload documents you are not authorised to handle, attempt to access other users' data, reverse-engineer or abuse the service, or use it to store unlawful content. We may suspend accounts that violate these terms.
5. **Insights are assistance, not professional advice.** Finavig highlights upcoming deadlines, spending patterns and cash projections, but it does not replace professional legal, PRO, accounting, tax or compliance advice. Always confirm deadlines with the issuing authority and figures with your accountant. Finavig is not liable for fines, penalties or losses arising from missed deadlines where reminders were delivered as configured.
6. **Availability & changes.** The service is provided "as is" and we aim for high availability but do not guarantee uninterrupted access. We may add, change, or discontinue features; material changes to these terms will be communicated in advance.
7. **Fees.** Core tracking features are provided free of charge; optional premium features or payment services may be introduced with clear pricing disclosed before purchase.
8. **Termination.** You can delete your account at any time from the profile screen. We may suspend or terminate accounts that violate these terms. On termination, sections concerning data ownership, disclaimers and liability survive.
9. **Limitation of liability.** To the maximum extent permitted by law, Finavig's aggregate liability for any claim relating to the service is limited to the amount you paid us in the 12 months preceding the claim (or AED 100 if no fees were paid).
10. **Governing law.** These terms are governed by the laws of the United Arab Emirates. Disputes are subject to the exclusive jurisdiction of the UAE courts.
11. **Contact.** Questions about these terms: `support@wazy.app`.

---

## 7. `/privacy` — Privacy Policy (render this copy verbatim, styled as a legal page with a sticky table of contents)

**Title:** Privacy Policy — **Last updated: September 2026**

Your documents and financial data are sensitive. This policy explains, in plain language, what Finavig collects, why, and how it stays protected. It complies with the UAE Federal Personal Data Protection Law (PDPL, Federal Decree-Law No. 45 of 2021).

1. **What we collect**
   - **Account details**: email address (and optional phone number for renewal and cash alerts).
   - **Documents you upload**: scans, photos, and PDFs of company and personal documents, invoices and receipts.
   - **Extracted data**: dates, amounts, vendors and document types derived from your uploads.
   - **Financial records**: transactions, budgets, savings envelopes and categories you create or import.
   - **Technical data**: app version and platform, used to keep your installation up to date and to diagnose issues.
2. **What we do NOT do**
   - We never sell your data.
   - We never share your documents with third parties for marketing.
   - We do not use your documents to train public AI models.
   - No advertising trackers, no data brokers.
3. **Why we process data (legal basis)** — To provide the service you signed up for: storing your documents, extracting expiry information, and delivering reminders you configured. Your documents belong to you; we process them on your instruction (contractual necessity) and, where applicable, with your consent (e.g., optional alerts channels).
4. **Where data lives** — Documents, financial records and account data are stored in Supabase (cloud infrastructure) with encryption in transit and at rest, protected by Row Level Security so only you can access your data. AI extraction runs on document content solely to locate dates, amounts and document attributes.
5. **Retention & deletion** — Your data is kept while your account is active. Deleting a document removes it from your workspace. Deleting your account initiates removal of your personal data within 30 days, except where retention is required by law.
6. **Your rights** — You can access, correct, export, or delete your data at any time from the app (CSV/PDF export built in). Under PDPL you may also request portability, restriction or objection to processing; contact us and we will respond promptly.
7. **Children** — Finavig is a business and productivity tool and is not directed at children under 16. We do not knowingly collect data from children.
8. **Security** — Encryption in transit (TLS) and at rest, isolated per-user data access, and least-privilege infrastructure. No system is perfectly secure, but we design to industry standards and will notify affected users and regulators of any breach as required by UAE law.
9. **International transfers** — Where data is processed outside the UAE, we use providers that offer adequate safeguards consistent with PDPL requirements.
10. **Changes to this policy** — Material changes will be announced in-app and the "last updated" date above revised.
11. **Contact** — Privacy questions or requests: `support@wazy.app`.

---

## 8. Project Structure & Deliverables

```
app/
  layout.tsx          // fonts, metadata, footer
  page.tsx            // landing page
  terms/page.tsx
  privacy/page.tsx
  sitemap.ts
  robots.ts
components/
  navbar.tsx
  hero.tsx
  problem-strip.tsx
  feature-pillars.tsx
  screenshot-showcase.tsx
  how-it-works.tsx
  built-for-uae.tsx
  faq.tsx
  final-cta.tsx
  footer.tsx
  legal-page.tsx      // shared layout for /terms and /privacy (prose + sticky TOC)
public/
  logo.png
  screenshots/*.png
```

Deliver complete, runnable code: `package.json`, `tailwind.config.ts`, `app/layout.tsx`, all components, and both legal pages. Ensure `npm run build` passes with zero errors. Copy should be final (no lorem ipsum). Add JSON-LD `SoftwareApplication` schema on the landing page (name: Finavig, applicationCategory: FinanceApplication, operatingSystem: iOS, Android).
```
