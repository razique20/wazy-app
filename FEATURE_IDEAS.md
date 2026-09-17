# Wazy AI Features Roadmap & Backlog

A curated roadmap of **Basic to Hard AI Features** tailored for **Wazy** (UAE SME Document Operations & Money Tracking App).

---

## 🟢 Level 1: Basic AI Features (Quick Wins & Smart Heuristics)

- [x] **Smart Auto-Categorization & Tagging Engine** `[Basic]`
  - *Description*: Uses TF-IDF / fuzzy string matching and user historical habits to automatically classify unstructured transactions into categories (e.g., "Talabat" → Food & Dining, "Salik" → Transport).
  - *Tech/Implementation*: Pure Dart string matching / Levenshtein distance & category memory index.

- [ ] **Dynamic Expiry Risk & Penalty Predictor** `[Basic]`
  - *Description*: Calculates an "Expiry Urgency & Risk Score" based on document authority (e.g., RTA vs GDRFA vs Ejari) and alerts users earlier for high-penalty documents (e.g., Late Ejari renewal vs Visa overstay fine calculation).
  - *Tech/Implementation*: Rule-based heuristic engine with authority fine lookup tables.

- [x] **Bill Spike & Anomaly Detection** `[Basic]`
  - *Description*: Automatically detects unusual price hikes in recurring expenses (e.g., "DEWA utility bill is 35% higher than your 3-month average").
  - *Tech/Implementation*: Statistical moving average & standard deviation anomaly detection.

---

## 🟡 Level 2: Intermediate AI Features (On-Device ML & Vision)

- [ ] **Bilingual Arabic + English OCR & Document Extraction** `[Intermediate]`
  - *Description*: On-device multi-script OCR extracting bilingual fields (Arabic & English names, Trade License numbers, authority stamps, Ejari tenancy terms) from UAE official documents.
  - *Tech/Implementation*: `google_mlkit_text_recognition` with Arabic script recognition package.

- [ ] **Smart Camera Receipt & Invoice Scanner** `[Intermediate]`
  - *Description*: Users point camera at paper receipts or upload PDF invoices to automatically extract vendor name, total amount, 5% UAE VAT portion, and date.
  - *Tech/Implementation*: Crop & edge detection (`image_picker` / `edge_detection`) + ML Kit text bounding box parsing.

- [ ] **Voice-to-Record Assistant (Speech-to-Text NL)** `[Intermediate]`
  - *Description*: Hands-free natural language quick add via voice. User speaks: *"Paid 450 AED for DEWA yesterday"*, and the app transcribes & auto-populates the transaction/document form.
  - *Tech/Implementation*: `speech_to_text` Flutter package combined with `NaturalLanguageParserService`.

---

## 🟠 Level 3: Advanced AI Features (Generative AI & LLMs)

- [ ] **Wazy AI Copilot (UAE SME Compliance & Renewal Advisor)** `[Advanced]`
  - *Description*: In-app AI chat assistant that answers UAE business compliance questions (e.g., *"What documents do I need to renew a Dubai DED Trade License?"*, *"What is the penalty for late Ejari renewal?"*).
  - *Tech/Implementation*: Gemini 1.5 Flash API integration + RAG (Retrieval-Augmented Generation) on UAE business guidelines.

- [ ] **AI Smart Contract & Policy Summarizer** `[Advanced]`
  - *Description*: Scans uploaded Ejari contracts, insurance policies, or commercial leases to extract key clauses (notice period before renewal, security deposit conditions, cancellation terms).
  - *Tech/Implementation*: Gemini API document vision / PDF text prompt summarization.

- [ ] **AI Monthly Financial Executive Summary** `[Advanced]`
  - *Description*: Generates a monthly natural language financial report (e.g., *"In August, spending rose by 12% due to office rent and trade license renewal. You are on track to save AED 4,500 in your envelope."*).
  - *Tech/Implementation*: LLM prompt generation based on monthly summary data & budget trends.

---

## 🔴 Level 4: Hard / Complex AI Features (Predictive Analytics & Agents)

- [ ] **Predictive 12-Month Cash Flow & Runway Engine** `[Hard]`
  - *Description*: Machine learning time-series model predicting future cash balances, cash dips, and SME runway up to 12 months ahead by modeling seasonal revenue, recurring bills, and scheduled document renewal peaks.
  - *Tech/Implementation*: Regression / ARIMA / Exponential Smoothing model implemented in Dart / ONNX Runtime Flutter plugin.

- [ ] **Autonomous Document Renewal Agent** `[Hard]`
  - *Description*: An autonomous AI agent workflow that monitors expiring documents, auto-drafts pre-filled renewal applications, generates step-by-step checklist tasks, calculates exact government fees, and sets intelligent reminder cascades.
  - *Tech/Implementation*: Multi-step agent workflow engine with tool calling and state persistence.

- [ ] **AI Receipt Audit & Fraud/Duplicate Detection Engine** `[Hard]`
  - *Description*: Advanced image forensics & text comparison that detects altered receipts (edited amounts, tampered dates), duplicate expense claims across team members, and non-deductible personal expenses for UAE corporate tax & VAT compliance.
  - *Tech/Implementation*: Image hashing + LLM vision verification pipeline.

---

## 🎯 Recommended Implementation Order

1. **Quick Win**: Smart Auto-Categorization & Tagging Engine `[Basic]`
2. **High Value**: Smart Camera Receipt & Invoice Scanner `[Intermediate]`
3. **Huge WOW Factor**: Wazy AI Copilot (UAE SME Compliance Advisor) `[Advanced]`
4. **Cutting Edge**: Autonomous Document Renewal Agent `[Hard]`
