# Wazy Admin Console — AI Generation Prompt

> **Instructions**: Copy and paste the prompt below into ChatGPT, Claude 3.5 Sonnet, Cursor, v0, or Bolt.new to automatically generate a full-stack Web Admin Console for the **Wazy** platform.

---

```markdown
You are an expert full-stack Web Developer specializing in React, Next.js, Tailwind CSS, TypeScript, and Supabase.

Build a modern, production-grade **Admin Console Dashboard** for the **Wazy** application (a personal and small-business document expiry tracker & financial intelligence manager).

---

### 🔑 1. Supabase Credentials & Configuration

Use the following real Supabase connection parameters to connect the application:

* **Supabase Project URL**: `https://jxyzmnaqukxvrcwolkil.supabase.co`
* **Supabase Anon Public Key**: `sb_publishable_GgyDJs0On_xdoFr4QLxlWA_wyRlktjf`

*(Note: For full admin capabilities that bypass Row Level Security across all users, add an environment variable for `SUPABASE_SERVICE_ROLE_KEY` while defaulting gracefully to the Anon Key for client interactions).*

---

### 🗄️ 2. Database Schema Reference

The Admin Console manages data stored in the following Supabase PostgreSQL tables:

#### Core Document Schema
1. **`public.collections`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid, references auth.users)
   - `name` (text)
   - `is_personal` (boolean)
   - `created_at` (timestamptz)

2. **`public.documents`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid)
   - `collection_id` (uuid, references collections)
   - `doc_type` (text: e.g. 'emiratesId', 'tradeLicence', 'passport', 'vehicleRegistration', 'custom-<uuid>')
   - `display_name` (text)
   - `expires_at` (date)
   - `reminder_days` (int, default 30)
   - `status` (text: 'active' | 'renewed' | 'expired' | 'archived')
   - `assigned_to` (text, optional)
   - `renewal_fee` (numeric(10,2), optional)
   - `notes` (text, optional)
   - `file_name` (text, optional)
   - `file_path` (text, optional)
   - `file_size` (bigint, optional)
   - `created_at` (timestamptz)
   - `updated_at` (timestamptz)

3. **`public.reminders`**
   - `id` (uuid, primary key)
   - `document_id` (uuid, references documents)
   - `remind_at` (date)
   - `channel` (text: 'push' | 'email' | 'whatsapp')
   - `sent_at` (timestamptz, optional)
   - `created_at` (timestamptz)

4. **`public.custom_document_types`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid)
   - `name` (text)
   - `renewal_authority` (text, optional)
   - `renewal_days` (int, default 365)
   - `created_at` (timestamptz)

#### Financial Intelligence Schema
5. **`public.finance_transactions`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid)
   - `collection_id` (uuid, references collections)
   - `kind` (text: 'expense' | 'income')
   - `category` (text: 'renewals' | 'salaries' | 'rent' | 'utilities' | 'suppliers' | 'marketing' | 'transport' | 'software' | 'sales' | 'other')
   - `title` (text)
   - `amount` (numeric(12,2))
   - `currency` (text, default 'AED')
   - `occurred_at` (date)
   - `note` (text, optional)
   - `document_id` (uuid, references documents, optional)
   - `created_at` (timestamptz)

6. **`public.category_budgets`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid)
   - `collection_id` (uuid)
   - `category` (text)
   - `monthly_limit` (numeric(12,2))
   - `created_at` (timestamptz)

7. **`public.savings_envelopes`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid)
   - `collection_id` (uuid)
   - `name` (text)
   - `target_amount` (numeric(12,2))
   - `saved_amount` (numeric(12,2))
   - `monthly_contribution` (numeric(12,2))
   - `document_id` (uuid, optional)
   - `created_at` (timestamptz)

8. **`public.recurring_transactions`**
   - `id` (uuid, primary key)
   - `owner_id` (uuid)
   - `collection_id` (uuid)
   - `kind` (text)
   - `category` (text)
   - `title` (text)
   - `amount` (numeric(12,2))
   - `currency` (text)
   - `frequency` (text: 'monthly' | 'quarterly' | 'yearly')
   - `day_of_month` (int)
   - `start_date` (date)
   - `end_date` (date, optional)
   - `is_active` (boolean)
   - `last_logged_at` (date, optional)

---

### 🖥️ 3. Layout & Main Dashboard Views

Design a modern dark-mode sidebar layout with the following tabs:

1. **📊 Overview Dashboard**
   - **KPI Cards**:
     - Total Collections (Personal vs Company)
     - Total Documents & Urgent Expiries (<30 days & Expired)
     - Monthly Financial Summary (Income, Expenses, Net Cash Flow in AED)
     - Budget Utilization Rate (%)
   - **Charts**:
     - *Monthly Cash Flow Trend*: Area Chart comparing Income vs Expenses over time.
     - *Expense Breakdown*: Donut Chart displaying spending across categories (`renewals`, `rent`, `salaries`, `utilities`, etc.).
     - *Upcoming Renewal Horizon*: Stacked Bar Chart showing expiries in 30, 60, 90+ days.

2. **📁 Collections & Documents Manager**
   - Interactive Data Table of all documents with search, sorting, and multi-field filtering (by collection, status, document type, and expiry range).
   - Document detail modal showing attached file details, renewal history, linked transactions, and reminders.
   - Quick action to update document status (`active`, `renewed`, `archived`) or edit renewal fee.

3. **💸 Finance & Expense Ledger**
   - Full ledger table of `finance_transactions`.
   - Category budget tracking progress bars displaying spent vs monthly limit with visual warning indicators when >80% or >100%.
   - Savings Envelopes cards with progress rings toward financial targets.
   - Recurring transactions list with trigger simulation and status toggle.

4. **⚠️ Anomaly & Bill Spike Detection**
   - Intelligent view alerting administrators to unusual utility or recurring cost spikes (e.g. expenses > 35% higher than 3-month moving average).
   - Severity badges (`Minor Spike`, `Moderate Spike`, `Severe Spike`) and resolution actions.

5. **⚙️ System & Data Administration**
   - Raw SQL runner / query exporter tool.
   - One-click CSV/JSON Data Exporter for Documents and Transactions.
   - Custom document type configuration manager.

---

### 🎨 4. Technology Stack & Design Aesthetics

- **Framework**: Next.js 14 App Router (or Vite + React + TypeScript).
- **Styling**: Tailwind CSS with custom dark mode theme (Slate-950 base, Slate-900 panels, Emerald `#10B981` / Teal `#06B6D4` / Cyan `#00E5FF` vibrant accents).
- **Icons**: `lucide-react`.
- **Charts**: `recharts`.
- **UI Components**: Radix UI / Shadcn UI components (Dialog, Tabs, Badge, Progress, Table, Select, Input).
- **Client**: Official `@supabase/supabase-js`.

---

### 🚀 5. Getting Started Implementation Code

Provide:
1. `src/lib/supabase.ts` initialization using the provided URL and Anon Key.
2. Complete TypeScript interfaces corresponding to the database schema.
3. Fully functional main layout with responsive sidebar.
4. Complete Overview Dashboard page with real-time Supabase data fetching (`supabase.from('documents').select('*')` and `supabase.from('finance_transactions').select('*')`).
```
