# Wazy App — Full Flow Test Report

**Date:** 2026-09-20 (latest) · previous run: 2026-09-19 (§6 below)
**Branch:** `main` · **Head:** `9c4a3f7` + 2 uncommitted files (see §0.1)
**Environment:** macOS (darwin) · Flutter SDK 3.38.x (Dart 3.11)

---

## 0. Run of 2026-09-20 — Track 1 monetization + Settings redesign

### 0.1 Features implemented today

| # | Feature | Files | Commit/State |
|---|---------|-------|--------------|
| 1 | **Track 1 freemium paywall** — `EntitlementService` resolves the tier from `public.user_tiers` (Free/Plus/Business) with per-tier limits; gates document cap, company collections, exports, AI summary | `lib/models/subscription_tier.dart` (new), `lib/services/entitlement_service.dart` (new), `lib/widgets/dialogs/upgrade_dialog.dart` (new) | `9c4a3f7` pushed |
| 2 | **Upgrade request flow** — plan sheet (Plus/Business × 1/3/12-month billing) drafts a pre-filled email to the support inbox; clipboard fallback when no mail app | `lib/services/upgrade_request_service.dart` (new), `upgrade_dialog.dart` | `9c4a3f7` pushed |
| 3 | **Profile subscription section** — tier badge, plan-expiry countdown, expired banner, Upgrade/Extend/Renew actions | `lib/screens/profile_screen.dart` | `9c4a3f7` pushed |
| 4 | **Feature gating wired into screens** — 11th-document gate, company-collection gate, export gate (tests run on Plus override), AI summary gate | `home_screen.dart`, `documents_screen.dart`, `expiry_list_screen.dart`, `money_screen.dart`, `monthly_summary_card.dart`, `test/filters_search_test.dart` | `9c4a3f7` pushed |
| 5 | **DB schema for tiers** — `user_tiers` + `user_tier_audit` tables, RLS self-read policy, service-role write guard, auto-expire trigger | `supabase/user_tiers_schema.sql` (new) | `9c4a3f7` pushed |
| 6 | **Admin console pairing docs** — `MONETIZATION.md`, `TIER_MANAGEMENT_PROMPT.md` | docs | `9c4a3f7` pushed |
| 7 | **iOS Podfile.lock refresh** — speech_to_text 7.2.0 darwin pod + CwlCatchException | `ios/Podfile.lock` | `fac8206` pushed |
| 8 | **Settings page reorganization** — 10 sections → 6; removed duplicate Account section, fake Danger Zone (demo-only snackbar), two dead "Coming soon" toggles, disabled WhatsApp timing row, Save button (all controls now auto-save + re-schedule OS reminders instantly) | `lib/screens/profile_screen.dart` | uncommitted |
| 9 | **Plan-expiry fix (`expires_at`)** — app now reads the Admin Console's `expires_at` column (fallback to `plan_ends_at`) so admin-granted plan durations actually expire; previously the expiry check never fired and paid features would have lasted forever | `lib/services/entitlement_service.dart` | uncommitted |
| 10 | **Admin console DB auto-expire trigger** — section 4 added to the console's schema: expired grants snap to Free (+ audit row) on next write | `../wazy-admin/supabase/user_tiers_schema.sql` (separate repo) | uncommitted in wazy-admin |

### 0.2 Verification of this run

| # | Check | Command | Result |
|---|-------|---------|--------|
| 1 | Static analysis | `flutter analyze --no-pub` | ✅ 0 errors · 24 warnings (same pre-existing set as 09-19) · 183 infos |
| 2 | Full test suite | `flutter test` | ✅ 192/192 passed |
| 3 | Targeted analyze after each edit | `flutter analyze <file>` | ✅ clean on `entitlement_service.dart`; `profile_screen.dart` at the 12-issue pre-existing baseline (no new lints) |
| 4 | Gated-test verification | `flutter test test/filters_search_test.dart` | ✅ 26/26 (export test runs on Plus override) |

> Android build not re-run today — no Android config changed since the 09-19 green build. Not applicable.

### 0.3 Bugs found & fixed today

| Bug | Root cause | Fix |
|-----|-----------|-----|
| App showed Free while Admin Console showed Business for user `e20ba0ca…` | Two schema generations in production: console writes `expires_at`, app read `plan_ends_at` (null) → expiry invisible, no countdown | App reads `expires_at` with graceful retry for deployments lacking the column (feature #9) |
| Paid plan would never expire in-app | Same root cause — downgrade condition tested `_planEndsAt` which stayed null forever | Same fix; verified `refresh()` now resolves 2026-10-20 from the live DB |
| "Clear all documents" (Danger Zone) did nothing — demo snackbar only | Placeholder never implemented | Section removed rather than shipping a destructive control that lies (feature #8) |

### 0.4 Known open items (non-blocking)

1. **Trigger not yet applied to production DB** — the wazy-admin schema section 4 must be pasted once into Supabase Dashboard → SQL Editor (no DDL via API). Until then, the DB row keeps the expired tier until the next admin write; app + console already treat it as Free at read time.
2. **Edit Profile no longer edits the name** — the name is always derived from the sign-in email (pre-existing behavior: the sheet edit was overwritten on every load); role + phone remain editable.
3. **WhatsApp / Email alert channels** remain unimplemented server-side; their dead UI toggles were removed from Settings.
4. **Uncommitted work** — features #8 and #9 are still local; commit before the next pull.

### 0.5 Verdict

| Gate | Status |
|------|--------|
| Analyze errors = 0 | ✅ |
| All tests pass (192) | ✅ |
| New lints introduced | ✅ none (baseline unchanged) |
| Monetization contract (app ↔ console ↔ DB) | ✅ aligned after feature #9 + #10 |

---

## 6. Previous run — 2026-09-19

> Report preserved as written; its internal section numbers (§1–§5) refer to that run only.

**Date:** 2026-09-19
**Branch:** `main` · **Head:** `ddbadbd` (docs + fixes) → see commit list below
**Environment:** macOS (darwin) · Flutter SDK 3.38.x (Dart 3.11) · Gradle debug toolchain

---

## 1. Scope of this run

| # | Check | Command | Result |
|---|-------|---------|--------|
| 1 | Static analysis | `flutter analyze --no-pub` | ✅ 0 errors |
| 2 | Full unit/widget test suite | `flutter test` | ✅ 192/192 passed |
| 3 | Android debug build | `flutter build apk --debug` | ✅ fixed & passing (was failing) |
| 4 | Pending docs commit | `LANDING_PAGE_PROMPT.md` | ✅ committed as `docs:` |

---

## 2. Git housekeeping completed before testing

| Commit | Type | Contents |
|--------|------|----------|
| `105a427` | docs | Added `LANDING_PAGE_PROMPT.md` (landing page spec, 189 lines) |
| `ddbadbd` | fix | Cupertino import in `app_theme.dart`; removed 🇦🇪 flag emoji from About sheet (doesn't render on all platforms) |
| `9139786` | fix | `android/app/build.gradle.kts` — desugaring; `pubspec.yaml/lock` — speech_to_text 7.5.0; removed unused `dart:math` import (committed & pushed) |

> All commits above are pushed to `origin/main`.

---

## 3. Results per flow

### 3.1 Static analysis — `flutter analyze`
- **Errors: 0** ✅
- **Warnings: 24** (pre-existing hygiene, no functional impact)
- **Infos: ~175** (pre-existing `withOpacity` deprecations)

#### ⚠️ Warnings (all pre-existing except #4, which I fixed during this run)
1. Unused imports: `document_detail_screen.dart`, `document_scan_screen.dart`, `expiry_list_screen.dart`, `global_search_screen.dart`, `home_screen.dart`, `splash_screen.dart`, `anomaly_detection_service.dart`, `natural_language_parser_service.dart`, `document_list_tile.dart`, `expiry_card.dart`, `natural_language_add_dialog.dart`, `urgency_dialog.dart`, `money_screen.dart`
2. Unused local variables (`now`, `theme`) in `document_detail_screen.dart`, `expiry_list_screen.dart`
3. Unused elements: `_buildMonthSummary` (money_screen), `_RadarPainter` (splash_screen), `_animation` (progress_ring)
4. ~~Unused `dart:math` in `empty_state_illustration.dart`~~ → **fixed in this run**
5. Unnecessary casts in `test/report_sync_test.dart`; `unnecessary_non_null_assertion` in `document_detail_screen.dart`

### 3.2 Test suite — `flutter test`
- **Result: 192 passed / 0 failed / 0 skipped** ✅ (both runs: pre- and post-dependency-upgrade)
- Covered flows verified passing:
  - Finance math (summary, budgets, recurrence, cash-flow, CSV export)
  - Renewal payment loop & mark-as-renewed (both legacy + new-expiry variants)
  - Monthly summary insights & budget alerts
  - ExpiryListScreen offline cache, filters, status filter, export entry
  - GlobalSearchScreen record-number search
  - MoneyScreen recurring UI incl. linked-document picker
  - Smart category engine (exact keywords, fuzzy typos, habit learning, retro-application)
  - UAE authority catalog, filters/search, report sync

### 3.3 Android debug build — `flutter build apk --debug`

**Status: ✅ PASSING** (re-verified 2026-09-19 after the fixes were committed as `9139786` and pushed).

**First run: ❌ FAILED** — two real, pre-existing config issues:

#### 🔴 Issue 1: `flutter_local_notifications` requires core library desugaring
```
Execution failed for task ':app:checkDebugAarMetadata'.
> Dependency ':flutter_local_notifications' requires core library desugaring
  to be enabled for :app.
```
**Fix applied** in `android/app/build.gradle.kts`:
- `compileOptions.isCoreLibraryDesugaringEnabled = true`
- Added `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` dependency
- Enabled `multiDexEnabled = true` in `defaultConfig`

#### 🔴 Issue 2: `speech_to_text` 6.6.2 uses removed v1 Android embedding
```
e: SpeechToTextPlugin.kt:37:48 Unresolved reference 'Registrar'.
e: SpeechToTextPlugin.kt:139:37 Unresolved reference 'Registrar'.
```
The v1 `Registrar` API no longer exists in the Android embedding v2 toolchain. No app code change needed.
**Fix applied:** `flutter pub upgrade --major-versions speech_to_text` → **7.5.0** (embedding-v2 compatible; API used by `voice_input_service.dart` is unchanged and analyze stays at 0 errors).

**Second run: ✅ SUCCESS** — `build/app/outputs/flutter_apk/app-debug.apk` built in 63.7s.

**Re-verification after commit `9139786` + icon regeneration from `assets/images/logo.png`: ✅ SUCCESS** — `app-debug.apk` built in 9.5s. Only remaining output is the non-blocking Gradle 8.14.0 / AGP 8.11.1 / Kotlin 2.2.20 deprecation warnings (see §4).

### 3.4 Runtime smoke checks (no device attached)
No simulator/emulator was running in this session, so install-and-launch on a device was **not** performed. Static + widget + build coverage above substitutes for CI-level verification; a manual device pass is recommended before release.

---

## 4. Notes & known non-blockers

1. **Kotlin version deprecation warning** (non-blocking):
   > Flutter support for your project's Kotlin version (2.2.20) will soon be dropped. Please upgrade to ≥ 2.3.20.
   Lives in `android/settings.gradle` (`org.jetbrains.kotlin.android` plugin). Upgrade at convenience.
2. **159 `withOpacity` deprecation infos** — mechanical migration to `.withValues(alpha: …)` possible; zero runtime impact today.
3. **Stray file:** `assets/images/.logo_transparent.png-VRHj` is still untracked and unreferenced — safe to delete.
4. **Icon SDK guard:** during the icon work, `piggy_bank_rounded` and `event_upcoming_rounded` didn't exist in this Flutter SDK; valid equivalents (`savings`, `hourglass_top`) are in place. If you upgrade Flutter, the piggy-bank icon can be revisited.
5. **Desugaring note:** if `minSdk` ever moves to ≥ 26, the desugaring config can be simplified, but keep it while `flutter_local_notifications` demands it.
6. **`speech_to_text` 7.x:** public Dart API used by the app is unchanged; if voice input misbehaves on a device, check the new `SpeechToTextProvider`-style init logs first.

---

## 5. Verdict

| Gate | Status |
|------|--------|
| Analyze errors = 0 | ✅ |
| All tests pass (192) | ✅ |
| Debug APK builds | ✅ (after 2 fixes) |
| Docs committed | ✅ |

**App is green across all testable flows.** The two build failures were environmental/config, both fixed in this session; the fixes are staged and ready to commit.
