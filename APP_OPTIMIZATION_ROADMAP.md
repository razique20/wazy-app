# Wazy App — UI/UX & Performance Optimization Roadmap

This document outlines key architectural, visual, and interaction enhancements designed to make **Wazy** feel **frictionless, lightning-fast, and premium** across all devices.

---

## 1. ⚡ Initial Loading & Shimmer Skeletons (Zero-Lag Experience)
* **Current Experience:** When opening the app or navigating to a tab (*Documents* or *Money*) for the first time, data hydrates asynchronously.
* **Optimization:** Introduce modern **Shimmer Skeleton Loaders** on `HomeScreen`, `DocumentsScreen`, and `MoneyScreen`. Instead of any frame delay, users instantly see an elegant pulsating card outline that seamlessly transitions into their real data.
* **Impact:** Eliminates perceived loading delay and ensures continuous visual feedback.

---

## 2. ✅ Speed Dial / Universal Quick Action Button *(implemented)*
* **Was:** To scan a document, log an expense, or create an envelope, users had to navigate to specific tab screens first.
* **Implemented:** A violet **Universal Action Button (`+`)** sits at the center of the floating nav pill (`_QuickActionButton` in `lib/router.dart`). It opens `showQuickActionSheet` (`lib/widgets/dialogs/quick_action_sheet.dart`), a 1-tap quick menu:
  * 📄 **Scan / Add Document** — Free-tier quota enforced, then the full-screen scanner.
  * 💸 **Log Expense or Income** — `TransactionFormSheet` with smart category matching.
  * 🎙️ **Voice AI Log (Talk to Wazy)** — Natural language + voice input, auto-categorized.
  * ✉️ **Create Savings Envelope** — Instant target allocation via `EnvelopeFormSheet`.
* **Impact:** 1-tap access to every core feature from anywhere in the app; entitlement gates stay enforced by reusing the same flows as the tabs.

---

## 3. 📄 Document Details: Full-Screen Pinch-to-Zoom & Quick Share
* **Current Experience:** Uploaded document scans and PDF receipts render inside a fixed rectangular preview box in `DocumentDetailScreen`.
* **Optimization:**
  * **Interactive Full-Screen Viewer:** Tapping the preview opens a full-screen pinch-to-zoom modal with double-tap zoom.
  * **One-Tap Export & Share:** Add a direct "Share Document File" button so users can instantly send their scanned Emirates ID / Ejari / Mulkiya via WhatsApp or Mail.
* **Impact:** Turns Wazy into a true professional document scanner & manager.

---

## 4. 💡 Money Tab Modularization & Smooth Frame-Rates
* **Current Experience:** `money_screen.dart` is a heavy file (117 KB) rendering charts, envelope cards, recurring payment ladders, and transaction lists in a single widget tree.
* **Optimization:** Refactor into modular, memoized component cards. This drastically reduces widget rebuilds, keeping scroll performance locked at 60–120 FPS even with hundreds of transactions.
* **Impact:** Ultra-smooth 60–120 FPS scrolling and instant tab switching.

---

## 5. 🎙️ Unified "Ask Wazy AI" Universal Voice Assistant
* **Current Experience:** Separate dialogs exist for Document Natural Language add and Money Natural Language add.
* **Optimization:** Merge into one **Universal AI Voice Sheet**. Users can speak naturally:
  * *"Log DEWA bill of 450 AED"* $\rightarrow$ auto-categorized into Utilities.
  * *"Add Emirates ID expiring 14 Oct 2027"* $\rightarrow$ auto-fills document scanner fields with expiry alerts.
* **Impact:** Hands-free management powered by Groq AI.

---

## Next Action Plan

Select an optimization to implement:
1. **Shimmer Skeleton Loaders** for Home, Documents, and Money tabs.
2. ~~**Universal Quick Action Speed Dial (`+`)** button.~~ ✅ Done — see feature #2 above.
3. **Full-Screen Pinch-to-Zoom Viewer & Quick Share** in Document Details.
4. **Money Tab Performance Modularization**.
