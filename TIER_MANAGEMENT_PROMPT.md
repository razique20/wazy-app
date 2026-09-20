# Wazy Admin Console — Tier Management Prompt

> **Instructions**: Copy the prompt below into the AI agent working on the **Wazy Admin Console**
> codebase (the React/Next.js/Tailwind/TypeScript/Supabase project generated from
> [`ADMIN_CONSOLE_PROMPT.md`](ADMIN_CONSOLE_PROMPT.md)). It adds the Track 1 subscription
> tier-management feature that pairs with the paywall already shipped in the Flutter app
> (see [`MONETIZATION.md`](MONETIZATION.md)).

---

```markdown
You are an expert full-stack Web Developer specializing in React, Next.js, Tailwind CSS,
TypeScript, and Supabase. The Wazy Admin Console already exists — ADD a new feature to it:
**Subscription tier management for users**.

## Background

The Wazy Flutter app now ships a freemium paywall. The app resolves each signed-in user's
tier by reading the Supabase table `public.user_tiers`; the Admin Console is the only place
that grants tiers. Upgrade requests arrive by email at aethylglobal@gmail.com with the
subject `Wazy upgrade request — {tier} — user {userId}` and a body containing the user's ID,
account email, current tier, requested tier, the gated feature, app version and platform.
The admin's workflow is: read the email → look the user up in the console → set the tier.

## 1. Database migration

The schema is already written — do NOT re-create it or invent your own tables/policies.
Run the committed script **`supabase/user_tiers_schema.sql`** (from the Flutter repo)
once against the production Supabase project — Dashboard → SQL Editor → New query —
**before** using the tier UI. It creates:

* `public.user_tiers` — one row per user (`user_id` PK, `tier` ∈ `free` | `plus` | `business`),
  RLS enabled with a single **"users can read own tier"** select policy
  (`auth.uid() = user_id`). Writes stay service-role-only — never add write policies.
* `public.user_tier_audit` — immutable tier-change history, service-role only (no policies).

## 2. Admin UI (new "Subscriptions" section)

* Users list: every `auth.users` row (id, email, created_at) LEFT JOINed with
  `user_tiers` — a missing row means **Free**. Paginate; search by email or user ID.
* Per-user row: current tier badge (Free / Plus / Business), a tier dropdown, an
  optional note field, and a Save button.
* Save flow: confirmation dialog ("Grant Plus to user 3f2a…?") → server action →
  toast with the new tier. Writes go through a **Next.js route handler or server
  action using the `SUPABASE_SERVICE_ROLE_KEY`** (server-side only — never ship the
  service key to the browser). Validate the tier value server-side against the
  allowed set. Insert an audit row when `user_tier_audit` exists.
* Quick action: a "Paste user ID from upgrade email" box that accepts the raw user ID
  (or the whole email subject line `Wazy upgrade request — plus — user <ID>`, parse
  out the ID) and jumps straight to that user with the requested tier preselected.

## 3. Contract with the Flutter app (must match exactly — do not change)

* The app runs exactly: `client.from('user_tiers').select('tier').eq('user_id', userId).maybeSingle()`
  and reads the `tier` column.
* Valid values are the lowercase strings `free`, `plus`, `business`. Anything else —
  or a missing row — falls back to Free in the app.
* One row per user (primary key `user_id`) — always upsert, never insert duplicates.
* The app re-reads the tier on cold start, sign-in, and every time the Profile tab
  opens. So after saving in the console, the user sees the new entitlements by simply
  reopening the Profile tab — **no app update or reinstall needed**. Nothing needs to
  be pushed to the app.

## 4. Tier meaning (for labels and tooltips in the console)

| Tier | What it unlocks in the app |
|---|---|
| `free` | 10 documents, 0 company collections, standard 90/60/30/7-day reminders |
| `plus` | Unlimited documents, 1 company collection, 90-day cash-flow forecast, PDF/CSV export, custom alert days, AI monthly summary |
| `business` | Everything in Plus, unlimited company workspaces, document assignment, renewal audit history, team exports |

## 5. Acceptance criteria

- [ ] Migration creates `user_tiers` (+ optional audit table) with RLS enabled; the
      self-read policy is the only policy on `user_tiers`.
- [ ] Admin can search a user by email or ID, change their tier, and save with
      confirmation; the change is visible immediately in the list.
- [ ] All tier writes happen server-side with the service-role key; the anon key can
      never change a tier.
- [ ] Granting Plus in the console makes the paywalled features (90-day forecast,
      CSV/PDF export, custom alert days, AI summary, 11th document, first company
      collection) work in the app after the user reopens the Profile tab.
- [ ] Downgrading back to Free re-locks the features and restores the 10-document cap.
- [ ] Every tier change appends an audit row (who, when, old → new, note).
```
