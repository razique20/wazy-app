# Wazy 🚀

> **AI-powered budgeting & cash-flow intelligence — with every document expiry tracked and every renewal fee forecast.**  
> **Wazy** is a financial budgeting & intelligence platform for personal & small-business use, with built-in document expiry tracking and renewal alerts. Built for mobile and web.

📚 **Project documentation** lives in [`docs/`](docs/): [technical documentation](docs/technical-documentation.md), [market study](docs/market-study.md), [feasibility study](docs/feasibility-study.md), and a [screenshot gallery](docs/README.md#-screenshot-gallery) of every feature.

---

## 🌟 Key Features

### 💸 1. Financial Intelligence & Budgeting
- **Unified Ledger**: Track income and expense transactions (`finance_transactions`) tagged by collection and category.
- **Category Budgets**: Set monthly spending limits per category (`renewals`, `salaries`, `rent`, `utilities`, `suppliers`, `marketing`, `transport`, `software`, `sales`, `other`) with visual budget utilization and 80/100% alerts.
- **90-Day Cash-Flow Forecast**: Daily balance simulation that folds in recurring bills and upcoming renewal fees, with dip/lowest-balance detection.
- **Savings Envelopes**: Virtual piggy banks (`savings_envelopes`) for goal tracking and monthly contribution allocation.
- **Recurring Schedules**: Template engine (`recurring_transactions`) that automatically logs monthly, quarterly, or annual fixed costs.

### 📁 2. Document Expiry Tracking
- **Multi-Entity Scoping**: Group documents into built-in **Personal** collections or custom **Company / Business** collections.
- **Expiry Horizon Tracking**: Monitor renewals for Emirates ID, Trade Licences, Visas, Passports, Vehicle Registrations, Tenancy Contracts, Insurance, and Subscriptions.
- **Custom Document Types**: Create custom document classifications with user-defined renewal cycles and authority details.
- **Smart Reminders**: Automated push & local notifications triggered 30, 60, and 90 days prior to expiration.
- **OCR Scan & Attachment**: Instant document detail extraction powered by **Google ML Kit Text Recognition** and PDF preview/printing.

### 🧠 3. Smart AI Engine & Automation
- **Natural Language Quick Add**: Parse complex text or voice prompts (e.g. *"Paid AED 450 for DEWA utilities yesterday"*) into structured transactions or document reminders automatically.
- **Smart Auto-Categorization**: Pure Dart string matching engine combining Levenshtein distance, UAE vendor dictionaries (e.g. *Talabat, Salik, DEWA, Etisalat*), and persistent user habit learning.
- **Bill Spike & Anomaly Detection**: Statistical moving average and standard deviation analysis to highlight price hikes (e.g. utility bills 35% higher than 3-month baseline).

---

## 🛠️ System Architecture & Tech Stack

| Component | Technology / Library |
| :--- | :--- |
| **Frontend Framework** | Flutter 3.x (Dart 3.11+) |
| **Routing & State** | `go_router`, State-driven ChangeNotifier services |
| **Backend & Database** | **Supabase** (PostgreSQL with Row Level Security) |
| **Storage** | Supabase Storage Buckets for document scans |
| **OCR & Vision** | `google_mlkit_text_recognition` |
| **Voice & Speech** | `speech_to_text` |
| **Notifications** | `flutter_local_notifications` & `timezone` |
| **Reporting & Export** | `pdf`, `printing`, CSV Exporter |

---

## 🗄️ Database Schema Summary

The backend uses a multi-tenant, collection-based model in Supabase:

- **`collections`**: User document containers (`is_personal` boolean for owner's personal docs).
- **`documents`**: Document metadata, expiry dates, renewal fees, assigned owners, and attachment paths.
- **`reminders`**: Scheduled notification logs (Push, Email, WhatsApp).
- **`custom_document_types`**: User-defined document rules and default validity periods.
- **`finance_transactions`**: Income/expense line items linked to collections and optional documents.
- **`category_budgets`**: Monthly spending limits per collection/category.
- **`savings_envelopes`**: Savings targets and current progress.
- **`recurring_transactions`**: Recurrence templates for automated expense logging.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.11.0`)
- [Dart SDK](https://dart.dev/get-dart)
- A Supabase Project ([supabase.com](https://supabase.com))

### 1. Installation
Clone the repository and install dependencies:
```bash
git clone https://github.com/razique20/wazy-app.git
cd wazy
flutter pub get
```

### 2. Backend Setup
1. Execute `supabase/schema.sql` in your Supabase SQL Editor.
2. Execute `supabase/finance_schema.sql` to initialize financial ledger tables.
3. Configure your Supabase credentials in `lib/config/app_credentials.dart`:
   ```dart
   class AppCredentials {
     static const String supabaseUrl = 'YOUR_SUPABASE_URL';
     static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   }
   ```

### 3. Run the App
Launch on iOS, Android, or Web:
```bash
flutter run
```

---

## 🧪 Testing & Quality Assurance

Run the comprehensive unit and integration test suite:
```bash
flutter test
```
*Current test suite: **131 passing unit & integration tests** covering document expiry math, financial category rules, anomaly detection thresholds, and budget tracking.*

---

## 💻 Web Admin Console

To build or deploy the companion web admin dashboard, refer to the self-contained prompt generator in [`ADMIN_CONSOLE_PROMPT.md`](file:///Users/raziquemk/Desktop/wazy/ADMIN_CONSOLE_PROMPT.md).


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
