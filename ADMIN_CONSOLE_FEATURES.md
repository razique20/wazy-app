# Wazy Admin Console — Features & Database Reference

> Complete guide to every admin-manageable feature, its Supabase table, columns, and ready-to-use SQL helpers.
> Admin Console connects with the **service-role key** (bypasses all RLS).

---

## Table of Contents

1. [User Management](#1-user-management)
2. [Subscription & Tier Management](#2-subscription--tier-management)
3. [AI Quota Management](#3-ai-quota-management)
4. [Support Request Management](#4-support-request-management)
5. [Document Management](#5-document-management)
6. [Collection (Workspace) Management](#6-collection-workspace-management)
7. [Finance Management](#7-finance-management)
8. [App Version & Force Update Control](#8-app-version--force-update-control)
9. [Reminder & Notification Management](#9-reminder--notification-management)
10. [Custom Document Types](#10-custom-document-types)
11. [Tier Audit History](#11-tier-audit-history)
12. [Dashboard & Analytics](#12-dashboard--analytics)
13. [Full Database Schema Map](#13-full-database-schema-map)

---

## 1. User Management

### Source: `auth.users` (Supabase Auth built-in)

| Admin Feature | Description |
|---|---|
| **List all users** | View all registered users with email, sign-up date, last sign-in |
| **Search users** | Search by email, user ID, or name |
| **Disable / ban user** | Temporarily suspend a user account |
| **Delete user** | Permanently remove user and cascade-delete all their data |
| **View user details** | Email, ID, created_at, last_sign_in_at, email_confirmed_at |
| **Reset password** | Send password reset email to a user |

### SQL Helpers

```sql
-- List all users with sign-up date
SELECT id, email, created_at, last_sign_in_at, email_confirmed_at
FROM auth.users
ORDER BY created_at DESC;

-- Search user by email
SELECT id, email, created_at FROM auth.users
WHERE email ILIKE '%search_term%';

-- Count total users
SELECT COUNT(*) AS total_users FROM auth.users;

-- Users who signed up in the last 7 days
SELECT id, email, created_at FROM auth.users
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

## 2. Subscription & Tier Management

### Table: `public.user_tiers`
### Schema: `supabase/user_tiers_schema.sql`

| Column | Type | Description |
|---|---|---|
| `user_id` | UUID (PK, FK -> auth.users) | User reference |
| `tier` | TEXT | `'free'`, `'plus'`, `'business'` |
| `plan_duration` | TEXT | `'1_month'`, `'3_months'`, `'1_year'` |
| `plan_started_at` | TIMESTAMPTZ | When the paid plan started |
| `plan_ends_at` | TIMESTAMPTZ | When the paid plan expires |
| `updated_at` | TIMESTAMPTZ | Last modification time |
| `updated_by` | TEXT | Admin who made the change |
| `note` | TEXT | Admin note (e.g. "payment received via Stripe") |

### Tier Limits Reference

| Feature | Free | Plus | Business |
|---|---|---|---|
| Max documents | 10 | Unlimited | Unlimited |
| Company workspaces | 0 | 1 | Unlimited |
| Cash-flow forecast | No | Yes | Yes |
| PDF/CSV export | No | Yes | Yes |
| Custom reminder days | No | Yes | Yes |
| AI monthly summary | No | Yes | Yes |
| Document assignment | No | No | Yes |
| Renewal audit history | No | No | Yes |
| Team data export | No | No | Yes |
| AI Summary quota/month | 3 | 30 | 100 |
| AI Budget Plan quota/month | 2 | 20 | 60 |

### Admin Features

| Feature | Description |
|---|---|
| **Grant/upgrade tier** | Set a user's tier to plus or business |
| **Set plan duration** | Configure 1 month, 3 months, or 1 year |
| **Extend/renew plan** | Update plan_started_at & plan_ends_at |
| **Downgrade tier** | Revert to free (clears plan dates) |
| **View expiry** | See days remaining on paid plans |
| **Bulk expire check** | Find all expired plans still marked as paid |
| **Add admin notes** | Document payment references, promo codes, etc. |

### SQL Helpers

```sql
-- Grant Plus tier for 1 month
INSERT INTO public.user_tiers (user_id, tier, plan_duration, plan_started_at, plan_ends_at, updated_by, note)
VALUES (
  'USER_UUID_HERE',
  'plus',
  '1_month',
  NOW(),
  NOW() + INTERVAL '1 month',
  'admin@wazy.app',
  'Payment received'
)
ON CONFLICT (user_id) DO UPDATE SET
  tier = EXCLUDED.tier,
  plan_duration = EXCLUDED.plan_duration,
  plan_started_at = EXCLUDED.plan_started_at,
  plan_ends_at = EXCLUDED.plan_ends_at,
  updated_at = NOW(),
  updated_by = EXCLUDED.updated_by,
  note = EXCLUDED.note;

-- Grant Business tier for 1 year
INSERT INTO public.user_tiers (user_id, tier, plan_duration, plan_started_at, plan_ends_at, updated_by, note)
VALUES (
  'USER_UUID_HERE',
  'business',
  '1_year',
  NOW(),
  NOW() + INTERVAL '1 year',
  'admin@wazy.app',
  'Annual plan paid via bank transfer'
)
ON CONFLICT (user_id) DO UPDATE SET
  tier = EXCLUDED.tier,
  plan_duration = EXCLUDED.plan_duration,
  plan_started_at = EXCLUDED.plan_started_at,
  plan_ends_at = EXCLUDED.plan_ends_at,
  updated_at = NOW(),
  updated_by = EXCLUDED.updated_by,
  note = EXCLUDED.note;

-- Downgrade to Free
UPDATE public.user_tiers
SET tier = 'free', plan_duration = NULL, plan_started_at = NULL, plan_ends_at = NULL,
    updated_at = NOW(), updated_by = 'admin@wazy.app', note = 'Downgraded by admin'
WHERE user_id = 'USER_UUID_HERE';

-- View all paid users with expiry
SELECT ut.user_id, u.email, ut.tier, ut.plan_duration, ut.plan_started_at, ut.plan_ends_at,
       EXTRACT(DAY FROM ut.plan_ends_at - NOW()) AS days_remaining
FROM public.user_tiers ut
JOIN auth.users u ON u.id = ut.user_id
WHERE ut.tier != 'free'
ORDER BY ut.plan_ends_at ASC;

-- Find expired plans (still marked as paid)
SELECT ut.user_id, u.email, ut.tier, ut.plan_ends_at
FROM public.user_tiers ut
JOIN auth.users u ON u.id = ut.user_id
WHERE ut.tier != 'free' AND ut.plan_ends_at < NOW();

-- Tier distribution breakdown
SELECT tier, COUNT(*) AS user_count FROM public.user_tiers GROUP BY tier ORDER BY user_count DESC;
```

---

## 3. AI Quota Management

### Table: `public.ai_quota_usage`
### Schema: `supabase/ai_quota_schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Auto-generated |
| `user_id` | UUID (FK -> auth.users) | User reference |
| `feature_name` | TEXT | `'groq_ai_summary'` or `'groq_ai_budget_plan'` |
| `usage_month` | TEXT | Format `'YYYY-MM'` (e.g. `'2026-09'`) |
| `used_count` | INT | Number of times used this month |
| `updated_at` | TIMESTAMPTZ | Last usage timestamp |

### Admin Features

| Feature | Description |
|---|---|
| **View user quotas** | See how many AI calls each user has made this month |
| **Reset user quota** | Reset a specific user's quota to 0 |
| **Reset all quotas** | Bulk reset at month boundary |
| **View usage analytics** | Top users by AI usage, trending features |
| **Adjust quota limits** | Per-tier limits are in code (TierLimits), but admin can grant exceptions |

### SQL Helpers

```sql
-- View all AI usage for current month
SELECT aqu.user_id, u.email, aqu.feature_name, aqu.used_count, aqu.usage_month
FROM public.ai_quota_usage aqu
JOIN auth.users u ON u.id = aqu.user_id
WHERE aqu.usage_month = TO_CHAR(NOW(), 'YYYY-MM')
ORDER BY aqu.used_count DESC;

-- Reset a specific user's AI quota
UPDATE public.ai_quota_usage
SET used_count = 0, updated_at = NOW()
WHERE user_id = 'USER_UUID_HERE' AND usage_month = TO_CHAR(NOW(), 'YYYY-MM');

-- Reset ALL users' AI quotas (monthly reset)
UPDATE public.ai_quota_usage SET used_count = 0, updated_at = NOW();

-- Top 10 AI power users this month
SELECT aqu.user_id, u.email, SUM(aqu.used_count) AS total_usage
FROM public.ai_quota_usage aqu
JOIN auth.users u ON u.id = aqu.user_id
WHERE aqu.usage_month = TO_CHAR(NOW(), 'YYYY-MM')
GROUP BY aqu.user_id, u.email
ORDER BY total_usage DESC
LIMIT 10;

-- AI feature usage breakdown
SELECT feature_name, SUM(used_count) AS total_calls
FROM public.ai_quota_usage
WHERE usage_month = TO_CHAR(NOW(), 'YYYY-MM')
GROUP BY feature_name;
```

---

## 4. Support Request Management

### Table: `public.support_requests`
### Schema: `supabase/support_requests_schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Auto-generated |
| `user_id` | UUID (FK -> auth.users) | User who submitted |
| `user_email` | TEXT | User's email at time of submission |
| `request_type` | TEXT | `'tracking_option_request'`, `'feature_request'`, `'bug_report'`, `'support_request'` |
| `title` | TEXT | Request title |
| `description` | TEXT | Detailed description |
| `status` | TEXT | `'open'`, `'in_progress'`, `'resolved'` |
| `admin_notes` | TEXT | Admin's response visible to the user |
| `created_at` | TIMESTAMPTZ | Submission time |
| `updated_at` | TIMESTAMPTZ | Last update time |

### Admin Features

| Feature | Description |
|---|---|
| **View all requests** | List all support requests with filtering by type/status |
| **Update status** | Move between open -> in_progress -> resolved |
| **Add admin notes** | Respond to user (visible in their "My Requests" history) |
| **Filter by type** | View only tracking requests, bugs, features, or support |
| **Filter by status** | View open, in-progress, or resolved tickets |
| **Delete request** | Remove spam or duplicate requests |
| **View by user** | See all requests from a specific user |

### SQL Helpers

```sql
-- View all open support requests (newest first)
SELECT sr.id, sr.user_email, sr.request_type, sr.title, sr.status, sr.created_at
FROM public.support_requests sr
WHERE sr.status = 'open'
ORDER BY sr.created_at DESC;

-- View all requests (with user email)
SELECT sr.*, u.email
FROM public.support_requests sr
LEFT JOIN auth.users u ON u.id = sr.user_id
ORDER BY sr.created_at DESC;

-- Update status to "in_progress"
UPDATE public.support_requests
SET status = 'in_progress', admin_notes = 'Looking into this. Will update soon.'
WHERE id = 'REQUEST_UUID_HERE';

-- Resolve a request with admin notes
UPDATE public.support_requests
SET status = 'resolved', admin_notes = 'This has been implemented in version 1.2.0!'
WHERE id = 'REQUEST_UUID_HERE';

-- Count requests by type
SELECT request_type, COUNT(*) AS total
FROM public.support_requests
GROUP BY request_type
ORDER BY total DESC;

-- Count requests by status
SELECT status, COUNT(*) AS total
FROM public.support_requests
GROUP BY status;

-- View tracking option requests specifically
SELECT * FROM public.support_requests
WHERE request_type = 'tracking_option_request'
ORDER BY created_at DESC;

-- View all requests from a specific user
SELECT * FROM public.support_requests
WHERE user_id = 'USER_UUID_HERE'
ORDER BY created_at DESC;
```

---

## 5. Document Management

### Table: `public.documents`
### Schema: `supabase/schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Document ID |
| `owner_id` | UUID (FK -> auth.users) | Owner |
| `collection_id` | UUID (FK -> collections) | Parent workspace |
| `doc_type` | TEXT | Built-in type key or `'custom-<uuid>'` |
| `display_name` | TEXT | User-given name |
| `expires_at` | DATE | Expiry date |
| `reminder_days` | INT | Default: 30 |
| `status` | TEXT | `'active'`, `'renewed'`, `'expired'`, `'archived'` |
| `assigned_to` | TEXT | Team member (Business tier) |
| `renewal_fee` | NUMERIC(10,2) | Cost to renew |
| `notes` | TEXT | User notes |
| `file_name` | TEXT | Uploaded file name |
| `file_path` | TEXT | Storage path |
| `file_size` | BIGINT | File size in bytes |
| `location` | TEXT | Issuing authority & jurisdiction |
| `renewal_history` | JSONB | Array of renewal events |
| `custom_reminder_days` | INT[] | Custom alert day offsets |
| `created_at` | TIMESTAMPTZ | Created |
| `updated_at` | TIMESTAMPTZ | Last modified |

### Built-in Document Types

| Key | Document |
|---|---|
| `emiratesId` | Emirates ID |
| `passport` | Passport |
| `visa` | Visa |
| `labourContract` | Labour Contract |
| `medicalInsurance` | Medical Insurance |
| `vehicleInsurance` | Vehicle Insurance |
| `vehicleRegistration` | Vehicle Registration |
| `drivingLicence` | Driving Licence |
| `tradeLicence` | Trade Licence |
| `tenancyContract` | Tenancy Contract |
| `chamberMembership` | Chamber of Commerce Membership |
| `businessSubscription` | Business Subscription |
| `other` | Other |

### Admin Features

| Feature | Description |
|---|---|
| **View all documents** | Browse all users' documents with owner info |
| **Search documents** | By name, type, status, owner email |
| **View expired documents** | Find all expired documents across users |
| **View expiring soon** | Documents expiring in the next 7/30/60/90 days |
| **Document count per user** | Audit tier compliance (Free = max 10) |
| **View renewal history** | Audit trail for each document |
| **Export document list** | CSV/JSON export for reporting |

### SQL Helpers

```sql
-- Total documents per user
SELECT d.owner_id, u.email, COUNT(*) AS doc_count
FROM public.documents d
JOIN auth.users u ON u.id = d.owner_id
GROUP BY d.owner_id, u.email
ORDER BY doc_count DESC;

-- Documents expiring in the next 30 days
SELECT d.id, d.display_name, d.doc_type, d.expires_at, u.email,
       (d.expires_at - CURRENT_DATE) AS days_until_expiry
FROM public.documents d
JOIN auth.users u ON u.id = d.owner_id
WHERE d.status = 'active' AND d.expires_at BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
ORDER BY d.expires_at ASC;

-- All expired documents
SELECT d.id, d.display_name, d.doc_type, d.expires_at, u.email
FROM public.documents d
JOIN auth.users u ON u.id = d.owner_id
WHERE d.status = 'active' AND d.expires_at < CURRENT_DATE
ORDER BY d.expires_at ASC;

-- Document type distribution
SELECT doc_type, COUNT(*) AS total FROM public.documents GROUP BY doc_type ORDER BY total DESC;

-- Free-tier users exceeding 10 document limit
SELECT d.owner_id, u.email, COUNT(*) AS doc_count
FROM public.documents d
JOIN auth.users u ON u.id = d.owner_id
LEFT JOIN public.user_tiers ut ON ut.user_id = d.owner_id
WHERE COALESCE(ut.tier, 'free') = 'free'
GROUP BY d.owner_id, u.email
HAVING COUNT(*) > 10;
```

---

## 6. Collection (Workspace) Management

### Table: `public.collections`
### Schema: `supabase/schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Collection ID |
| `owner_id` | UUID (FK -> auth.users) | Owner |
| `name` | TEXT | Collection name |
| `country_code` | TEXT | Default `'AE'` |
| `is_personal` | BOOLEAN | True = built-in personal collection |
| `created_at` | TIMESTAMPTZ | Created |

### Admin Features

| Feature | Description |
|---|---|
| **View all collections** | List all user workspaces |
| **Audit company collections** | Ensure Free users have 0, Plus users <= 1 |
| **View collection contents** | Documents inside a specific collection |
| **Delete collection** | Remove a workspace and its documents |

### SQL Helpers

```sql
-- All collections with owner info
SELECT c.id, c.name, c.country_code, c.is_personal, u.email, c.created_at
FROM public.collections c
JOIN auth.users u ON u.id = c.owner_id
ORDER BY c.created_at DESC;

-- Company collections per user (tier compliance)
SELECT c.owner_id, u.email, COUNT(*) AS company_workspaces,
       COALESCE(ut.tier, 'free') AS tier
FROM public.collections c
JOIN auth.users u ON u.id = c.owner_id
LEFT JOIN public.user_tiers ut ON ut.user_id = c.owner_id
WHERE c.is_personal = FALSE
GROUP BY c.owner_id, u.email, ut.tier
ORDER BY company_workspaces DESC;

-- Documents count per collection
SELECT c.id, c.name, u.email, COUNT(d.id) AS doc_count
FROM public.collections c
JOIN auth.users u ON u.id = c.owner_id
LEFT JOIN public.documents d ON d.collection_id = c.id
GROUP BY c.id, c.name, u.email
ORDER BY doc_count DESC;
```

---

## 7. Finance Management

### Tables
- `public.finance_transactions` — Income & expenses
- `public.category_budgets` — Monthly budget limits
- `public.savings_envelopes` — Savings goals
- `public.recurring_transactions` — Auto-recurring templates

### Schema: `supabase/finance_schema.sql`

### finance_transactions

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Transaction ID |
| `owner_id` | UUID (FK) | Owner |
| `collection_id` | UUID (FK) | Workspace scope |
| `kind` | TEXT | `'expense'` or `'income'` |
| `category` | TEXT | renewals, salaries, rent, utilities, suppliers, marketing, transport, software, sales, other |
| `title` | TEXT | Description |
| `amount` | NUMERIC(12,2) | Amount |
| `currency` | TEXT | Default `'AED'` |
| `occurred_at` | DATE | Transaction date |
| `note` | TEXT | Optional note |
| `document_id` | UUID (FK) | Linked document (if renewal) |
| `created_at` | TIMESTAMPTZ | Created |

### category_budgets

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Budget ID |
| `owner_id` | UUID (FK) | Owner |
| `collection_id` | UUID (FK) | Workspace |
| `category` | TEXT | Category name |
| `monthly_limit` | NUMERIC(12,2) | Monthly budget cap |

### savings_envelopes

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Envelope ID |
| `owner_id` | UUID (FK) | Owner |
| `collection_id` | UUID (FK) | Workspace |
| `name` | TEXT | Goal name |
| `target_amount` | NUMERIC(12,2) | Target savings |
| `saved_amount` | NUMERIC(12,2) | Current progress |
| `monthly_contribution` | NUMERIC(12,2) | Monthly amount |
| `document_id` | UUID (FK) | Linked document |

### recurring_transactions

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Template ID |
| `owner_id` | UUID (FK) | Owner |
| `collection_id` | UUID (FK) | Workspace |
| `kind` | TEXT | expense/income |
| `category` | TEXT | Category |
| `title` | TEXT | Description |
| `amount` | NUMERIC(12,2) | Amount |
| `frequency` | TEXT | `'monthly'`, `'quarterly'`, `'yearly'` |
| `day_of_month` | INT | 1-31 |
| `start_date` | DATE | When it starts |
| `end_date` | DATE | When it ends (nullable) |
| `is_active` | BOOLEAN | Active flag |
| `last_logged_at` | DATE | Last auto-logged date |

### Admin Features

| Feature | Description |
|---|---|
| **View platform revenue** | Total income/expense across all users |
| **User spending analysis** | Top spenders, category breakdown |
| **Budget compliance** | Users exceeding their monthly budgets |
| **Savings progress** | Aggregate savings goals and progress |
| **Recurring templates** | Active recurring transactions across users |

### SQL Helpers

```sql
-- Total platform spending this month
SELECT SUM(amount) AS total_spent, currency
FROM public.finance_transactions
WHERE kind = 'expense' AND occurred_at >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY currency;

-- Top 10 spenders this month
SELECT ft.owner_id, u.email, SUM(ft.amount) AS total_spent
FROM public.finance_transactions ft
JOIN auth.users u ON u.id = ft.owner_id
WHERE ft.kind = 'expense' AND ft.occurred_at >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY ft.owner_id, u.email
ORDER BY total_spent DESC
LIMIT 10;

-- Spending by category (platform-wide)
SELECT category, SUM(amount) AS total
FROM public.finance_transactions
WHERE kind = 'expense' AND occurred_at >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY category
ORDER BY total DESC;

-- Active savings goals progress
SELECT se.name, se.target_amount, se.saved_amount, u.email,
       ROUND((se.saved_amount / NULLIF(se.target_amount, 0)) * 100, 1) AS percent_complete
FROM public.savings_envelopes se
JOIN auth.users u ON u.id = se.owner_id
ORDER BY percent_complete DESC;
```

---

## 8. App Version & Force Update Control

### Table: `public.app_versions`
### Schema: `supabase/app_version_schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Row ID |
| `platform` | TEXT | `'all'`, `'ios'`, `'android'`, `'web'` |
| `min_required_version` | TEXT | Minimum version (forces update below this) |
| `latest_version` | TEXT | Latest available version |
| `is_force_update` | BOOLEAN | If true, blocks app until user updates |
| `download_url` | TEXT | Link to download the update |
| `release_notes` | TEXT | What's new in this version |
| `created_at` | TIMESTAMPTZ | Created |
| `updated_at` | TIMESTAMPTZ | Last modified |

### Admin Features

| Feature | Description |
|---|---|
| **Publish new version** | Update latest_version and release notes |
| **Force update** | Set min_required_version and is_force_update = true |
| **Per-platform control** | Different versions for iOS, Android, Web |
| **Release notes** | Write release notes visible to users |
| **Download URL** | Set store links for each platform |

### SQL Helpers

```sql
-- View current version config
SELECT * FROM public.app_versions;

-- Publish new version (soft update)
UPDATE public.app_versions
SET latest_version = '1.2.0',
    release_notes = 'New: Support request tracking, AI budget planner improvements.',
    updated_at = NOW()
WHERE platform = 'all';

-- Force update for all platforms
UPDATE public.app_versions
SET min_required_version = '1.1.0',
    latest_version = '1.2.0',
    is_force_update = true,
    release_notes = 'Critical security update. Please update immediately.',
    updated_at = NOW()
WHERE platform = 'all';

-- Disable force update
UPDATE public.app_versions
SET is_force_update = false, updated_at = NOW()
WHERE platform = 'all';
```

---

## 9. Reminder & Notification Management

### Table: `public.reminders`
### Schema: `supabase/schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Reminder ID |
| `document_id` | UUID (FK -> documents) | Which document |
| `remind_at` | DATE | When to remind |
| `channel` | TEXT | `'push'`, `'email'`, `'whatsapp'` |
| `sent_at` | TIMESTAMPTZ | When notification was sent (null = pending) |
| `created_at` | TIMESTAMPTZ | Created |

### Admin Features

| Feature | Description |
|---|---|
| **View pending reminders** | All reminders not yet sent |
| **View sent reminders** | Audit notification history |
| **Trigger reminder scan** | Manually run `create_due_reminders()` |
| **Clear stale reminders** | Remove old sent reminders |

### SQL Helpers

```sql
-- Pending reminders (not yet sent)
SELECT r.id, r.remind_at, r.channel, d.display_name, u.email
FROM public.reminders r
JOIN public.documents d ON d.id = r.document_id
JOIN auth.users u ON u.id = d.owner_id
WHERE r.sent_at IS NULL
ORDER BY r.remind_at ASC;

-- Manually trigger reminder scan
SELECT public.create_due_reminders();

-- Mark reminders as sent (batch)
UPDATE public.reminders SET sent_at = NOW()
WHERE sent_at IS NULL AND remind_at <= CURRENT_DATE;
```

---

## 10. Custom Document Types

### Table: `public.custom_document_types`
### Schema: `supabase/schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Type ID |
| `owner_id` | UUID (FK -> auth.users) | Creator |
| `name` | TEXT | Type name |
| `renewal_authority` | TEXT | Authority responsible |
| `renewal_days` | INT | Default renewal cycle (days) |
| `created_at` | TIMESTAMPTZ | Created |

### Admin Features

| Feature | Description |
|---|---|
| **View all custom types** | See what custom document types users have created |
| **Popular types** | Identify commonly created types (candidates for built-in) |
| **Delete invalid types** | Remove spam or duplicates |

### SQL Helpers

```sql
-- All custom types with owner
SELECT cdt.name, cdt.renewal_authority, cdt.renewal_days, u.email
FROM public.custom_document_types cdt
JOIN auth.users u ON u.id = cdt.owner_id
ORDER BY cdt.name;

-- Most popular custom types (candidates to become built-in)
SELECT LOWER(name) AS type_name, COUNT(*) AS user_count
FROM public.custom_document_types
GROUP BY LOWER(name)
ORDER BY user_count DESC
LIMIT 20;
```

---

## 11. Tier Audit History

### Table: `public.user_tier_audit`
### Schema: `supabase/user_tiers_schema.sql`

| Column | Type | Description |
|---|---|---|
| `id` | UUID (PK) | Audit entry ID |
| `user_id` | UUID (FK -> auth.users) | User affected |
| `old_tier` | TEXT | Previous tier |
| `new_tier` | TEXT | New tier |
| `changed_by` | TEXT | Who made the change |
| `note` | TEXT | Reason / context |
| `created_at` | TIMESTAMPTZ | When the change happened |

### Admin Features

| Feature | Description |
|---|---|
| **View audit trail** | Complete history of all tier changes |
| **Filter by user** | See a specific user's tier change history |
| **Auto-expiry log** | System entries when plans auto-expire |

### SQL Helpers

```sql
-- Full tier audit trail
SELECT uta.created_at, u.email, uta.old_tier, uta.new_tier, uta.changed_by, uta.note
FROM public.user_tier_audit uta
JOIN auth.users u ON u.id = uta.user_id
ORDER BY uta.created_at DESC;

-- Tier changes for a specific user
SELECT * FROM public.user_tier_audit
WHERE user_id = 'USER_UUID_HERE'
ORDER BY created_at DESC;
```

---

## 12. Dashboard & Analytics

### Recommended Admin Dashboard Widgets

| Widget | Query Source | Description |
|---|---|---|
| **Total Users** | `auth.users` | COUNT of all registered users |
| **New Users (7d)** | `auth.users` | Signups in the last 7 days |
| **Tier Distribution** | `user_tiers` | Pie chart: Free / Plus / Business |
| **Revenue Pipeline** | `user_tiers` | Paid users x plan pricing |
| **Expiring Plans** | `user_tiers` | Plans expiring in the next 7/30 days |
| **Open Support Tickets** | `support_requests` | Count where status = 'open' |
| **Tracking Requests** | `support_requests` | Tracking option requests (feature demand) |
| **Documents Tracked** | `documents` | Total active documents platform-wide |
| **Expiring Documents** | `documents` | Documents expiring in the next 30 days |
| **AI Usage This Month** | `ai_quota_usage` | Total AI calls across all users |
| **Top AI Users** | `ai_quota_usage` | Leaderboard of heaviest AI users |
| **Platform Spending** | `finance_transactions` | Total expenses this month |
| **Popular Categories** | `finance_transactions` | Top spending categories |
| **Active Savings Goals** | `savings_envelopes` | Total savings in progress |

### Master Analytics Queries

```sql
-- Platform overview stats
SELECT
  (SELECT COUNT(*) FROM auth.users) AS total_users,
  (SELECT COUNT(*) FROM auth.users WHERE created_at >= NOW() - INTERVAL '7 days') AS new_users_7d,
  (SELECT COUNT(*) FROM public.user_tiers WHERE tier != 'free') AS paid_users,
  (SELECT COUNT(*) FROM public.documents WHERE status = 'active') AS active_documents,
  (SELECT COUNT(*) FROM public.support_requests WHERE status = 'open') AS open_tickets,
  (SELECT COALESCE(SUM(used_count), 0) FROM public.ai_quota_usage
   WHERE usage_month = TO_CHAR(NOW(), 'YYYY-MM')) AS ai_calls_this_month;

-- User activity summary (per user)
SELECT u.id, u.email, u.created_at AS signed_up,
       COALESCE(ut.tier, 'free') AS tier,
       (SELECT COUNT(*) FROM public.documents d WHERE d.owner_id = u.id) AS documents,
       (SELECT COUNT(*) FROM public.collections c WHERE c.owner_id = u.id AND NOT c.is_personal) AS workspaces,
       (SELECT COALESCE(SUM(aqu.used_count), 0) FROM public.ai_quota_usage aqu
        WHERE aqu.user_id = u.id AND aqu.usage_month = TO_CHAR(NOW(), 'YYYY-MM')) AS ai_usage,
       (SELECT COUNT(*) FROM public.support_requests sr WHERE sr.user_id = u.id) AS support_requests
FROM auth.users u
LEFT JOIN public.user_tiers ut ON ut.user_id = u.id
ORDER BY u.created_at DESC;
```

---

## 13. Full Database Schema Map

```
                        auth.users
   (id, email, created_at, last_sign_in_at)
                           |
            user_id / owner_id
     __________|___________________________________________
    |          |              |                |            |
    v          v              v                v            v
user_tiers  collections  ai_quota_usage  support_requests  custom_doc_types
    |          |
    |     collection_id
    |    ______|______________________________
    |   |              |           |          |
    |   v              v           v          v
    | documents   category_    finance_   savings_
    |             budgets    transactions envelopes
    |   |
    |   v                    recurring_transactions
    | reminders              (standalone per collection)
    |
    v
user_tier_audit              app_versions
(immutable log)              (public read, admin write)
```

### All 13 Tables

| # | Table | Schema File | Purpose |
|---|---|---|---|
| 1 | `auth.users` | Supabase built-in | User accounts & auth |
| 2 | `collections` | `schema.sql` | Document workspaces (personal + company) |
| 3 | `documents` | `schema.sql` | Expiry-tracked documents |
| 4 | `reminders` | `schema.sql` | Notification schedule |
| 5 | `custom_document_types` | `schema.sql` | User-defined doc types |
| 6 | `user_tiers` | `user_tiers_schema.sql` | Subscription tiers |
| 7 | `user_tier_audit` | `user_tiers_schema.sql` | Tier change history |
| 8 | `ai_quota_usage` | `ai_quota_schema.sql` | AI feature usage tracking |
| 9 | `finance_transactions` | `finance_schema.sql` | Income & expenses |
| 10 | `category_budgets` | `finance_schema.sql` | Monthly budget limits |
| 11 | `savings_envelopes` | `finance_schema.sql` | Savings goals |
| 12 | `recurring_transactions` | `finance_schema.sql` | Auto-recurring templates |
| 13 | `support_requests` | `support_requests_schema.sql` | User support tickets |
| 14 | `app_versions` | `app_version_schema.sql` | Version & force update control |

---

## Admin Console Access Notes

- **Authentication**: Use Supabase **service-role key** (not anon key) - bypasses all RLS policies
- **Admin URL**: https://wazy-admin-sgjt.vercel.app
- **Support Email**: aethylglobal@gmail.com
- **Upgrade Requests**: Users send mailto: emails to the support inbox; admin processes them manually in the console
- **Auto-expiry**: The `expire_finished_plans` trigger automatically downgrades expired paid tiers to Free on the next write

---

*Last updated: September 2026*
