# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Orthodoxy 365" — a Greek Orthodox daily-saint / daily-quote glassmorphic widget. One Flutter codebase serves three targets:

1. **Web widget** (primary, live today): built to `build/web`, deployed to Cloudflare Pages (project `bible-quotes-widget`) and embedded on 365orthodoxy.com. The page background is deliberately **transparent** (`web/index.html` body, `scaffoldBackgroundColor`, `canvasColor`) so it can sit over the host site — never add an opaque background.
2. **iOS app** (App Store prep): bundle id `com.orthodoxy365.orthodoxyWidget365`, plus a native WidgetKit extension.
3. **Android app** (Play Store prep): application id `com.orthodoxy365.orthodoxy_widget_365`.

All UI text is Greek; the `el_GR` locale is initialized in `main()` before `runApp` and in test `setUpAll` — anything using `DateFormat(..., 'el_GR')` depends on it.

## Flutter version — pinned via FVM

The project is pinned to **Flutter 3.24.5** (`.fvmrc`). The CI workflow uses the same version. Use `fvm flutter ...` for all commands; a plain `flutter` may be a different SDK. The pin matters because the web build uses `--web-renderer html`, a flag removed in newer Flutter versions.

## Commands

```bash
fvm flutter pub get                 # dependencies
fvm flutter analyze                 # lint (flutter_lints defaults)
fvm flutter test                    # all tests
fvm flutter test test/widget_test.dart   # single test file
fvm flutter run -d chrome           # run web locally
./build_app                         # web release build (HTML renderer) + copies assets/data into build/web/assets
```

Note: `./build_app` calls `~/development/flutter/bin/flutter` directly (not FVM).

Store builds:

```bash
fvm flutter build appbundle --release        # Android (Play Store)
fvm flutter build ipa --release              # iOS (App Store; CocoaPods under ios/)
```

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`: Flutter 3.24.5 → `flutter build web --release` → Cloudflare Pages. So **deployment to production happens on every push to main**.

Quirk: ~105 files under `build/web/` are committed to git (the deploy predates CI). CI rebuilds from source, so local `build/web` diffs (e.g. `flutter_bootstrap.js`) are noise — don't treat them as meaningful changes, but don't casually delete the tracked files either.

## Architecture

### Dart app: one file

All Flutter code lives in `lib/main.dart` (~570 lines). There is no `lib/` module structure. Contents:

- **`OrthodoxyHomePage`** — the entire app state: today/tomorrow data, search, date picker, reminders, and a three-layer stacked UI (main card → "micro drawer" toolbar → full-screen "macro drawer" with search/calendar). All sizes are proportional to a clamped width `w` (300–380px) so the widget scales — keep new UI dimensions as multiples of `w`, not absolute pixels.
- **`GlassWidget`** — the reusable glassmorphism container (BackdropFilter blur + gradient borders/shadows, all proportional to width). Every card uses it.
- **`AstroEngine`** — pure-math sunrise/sunset and moon phase. Coordinates are hardcoded to Athens (37.98, 23.72).
- **`MobileBackground`** — dark gradient + radial orbs rendered behind the widget stack **only when `!kIsWeb`**, so the glass blur has something to act on in the standalone apps. On web nothing is rendered and the page stays transparent.

### Data: static JSON assets

`assets/data/{january..december}.json` — one entry per day: `id`, `date` ("2026-MM-DD"), `display_date` (Greek), `saint`, `priority` (higher = major feast; `1`/`100` used for major), `quote` (ancient Greek, polytonic), `translation` (modern Greek), `reference`, `wiki_url`. `extra_quotes.json` feeds the random-quote button.

Dates are stored with year 2026 but **matched by `MM-dd` substring only** (`loadDailyData`, `_selectDate`), so the data is effectively year-agnostic. Fixed feast days work every year; movable feasts (Easter cycle) are only correct for 2026.

`assets/official_data_2026.rtf` is the source document the JSON was derived from.

### Search (Greek-specific)

`_normalizeGreek` lowercases, strips **polytonic and monotonic diacritics** via an explicit character map, then uppercases — search/matching works on this normalized form. `_advancedSearch` scores matches using a nickname map (ΓΙΩΡΓΟΣ→ΓΕΩΡΓΙΟΣ etc.), keyword expansion (ΜΑΡΙΑ→ΘΕΟΤΟΚ), prefix bonuses, and the entry's `priority`. If you touch search, preserve the normalization path — raw queries contain accents that will never match otherwise.

### Reminders

`flutter_local_notifications` + `timezone` schedule a notification at 09:00 the day before a feast. Scheduled state is persisted in `SharedPreferences` where **the key set itself is the data model**: every prefs key is assumed to be a scheduled date string (`_initPrefs` does `_prefs!.getKeys()`). Adding any unrelated SharedPreferences key will corrupt the scheduled-reminders set — extend this carefully (e.g. migrate to a prefixed key scheme) if you ever store anything else.

### iOS WidgetKit extension (`ios/OrthodoxyWidget/`)

Native SwiftUI home-screen widget (`com.orthodoxy365.orthodoxyWidget365.OrthodoxyWidget`) that reads `saint`/`quote` from `UserDefaults(suiteName: "group.orthodoxy365")`. **The Flutter side does not currently write to that app group** (no plugin for it in `pubspec.yaml`), so the widget shows fallback text — wiring this up (e.g. via `home_widget` or a platform channel) is pending App Store work. The `OrthodoxyWidgetLiveActivity` file is unmodified Xcode template code.

## Pending work (store preparation backlog)

Agreed with the owner (July 2026) — do these when asked, roughly in this order:

### 1. Reminder/notification bugs (`lib/main.dart`, `_scheduleReminder`)
- Cancelling a reminder only removes the SharedPreferences key; `notificationsPlugin.cancel()` is never called, so the notification still fires.
- Notification IDs use `item.hashCode`, which changes between app launches — use a stable ID (the JSON `id` or `date`) so cancel can work.
- `tz.local` is never set from the device timezone (`tz.setLocalLocation` missing, e.g. via `flutter_timezone`) — scheduled times are effectively UTC, so "09:00" fires at 11:00–12:00 in Greece.
- No notification permission is ever requested (Android 13+ `POST_NOTIFICATIONS` runtime request; iOS request on first use). `AndroidScheduleMode.exactAllowWhileIdle` needs an exact-alarm permission, and the AndroidManifest currently declares **no permissions at all**. Reminders are also lost on device reboot (`RECEIVE_BOOT_COMPLETED` rescheduling not set up).

### 2. Play Store blockers (`android/`)
- Release builds are signed with **debug keys** (see TODO in `android/app/build.gradle`) — needs a keystore + `key.properties`.
- Flutter 3.24.5 defaults to targetSdk 34; Play requires 35 — set `targetSdkVersion 35` explicitly or upgrade Flutter (note the `--web-renderer html` conflict with newer Flutter).
- `android:label` is `orthodoxy_widget_365` (raw package name) and the launcher icon is the Flutter default — set a proper Greek app name and icons.

### 3. App Store blockers (`ios/`)
- No `PrivacyInfo.xcprivacy` privacy manifest — required, especially since shared_preferences/UserDefaults is a required-reason API.
- Wire the WidgetKit extension (see below) or remove it; `OrthodoxyWidgetLiveActivity.swift` is untouched Xcode template code ("Hello"/"Leading"/"Trailing") and must not ship as-is.

### ~~4. Mobile background design~~ — DONE (July 2026)
- Implemented as `MobileBackground` in `lib/main.dart`: a dark gradient with soft gold/blue radial orbs, rendered behind the widget stack only when `!kIsWeb`. The web build stays fully transparent — keep any future mobile-only chrome behind the same `kIsWeb` guard. Visual check on an iOS simulator / Android emulator is still pending.

### Smaller items
- Movable feasts (Easter cycle) in the JSON data are only correct for 2026 — data refresh needed for later years.
- The "every SharedPreferences key is a scheduled date" model breaks as soon as any other setting is persisted — migrate to prefixed keys.
- `ScaffoldMessenger.of(context)` is used after `await` in `_scheduleReminder` (BuildContext across async gaps).
