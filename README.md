# Block.then() Re-Entrancy Bug Reproduction

- **Issue:** https://github.com/flutter/flutter/issues/183012
- **Live demo:** https://davidmigloz.github.io/flutter_block_then_bug/

## Bug Summary

`Block.then(() => router.go(...))` callbacks in go_router's `onEnter` handler silently lose their navigation when triggered by `refreshListenable`. The `router.go()` inside the callback runs synchronously during `handleTopOnEnter` processing, triggering a re-entrant `_processRouteInformation` whose result is dropped due to transaction token churn in Flutter's Router.

## Reproduction Steps

1. Run the app:
   ```bash
   flutter run -d chrome
   ```
2. App starts authenticated on `/home` (green indicator should show if already fixed).
3. Tap **"Sign Out"** to set `isAuthenticated = false`.
4. `refreshListenable` fires, the `onEnter` guard returns `Block.then(() => router.go('/login'))`.

### Expected Behavior
The app navigates to `/login` (green "FIXED" indicator).

### Actual Behavior (without fix)
The app stays on `/home` (red "BUG" indicator). The debug console shows `[Block.then] Calling router.go(/login)` confirming the callback fires, but the navigation is lost.

## Root Cause

The callback at `parser.dart:533` fires **during** the outer parse's Future chain via `await Future<void>.sync(callback)`. When the callback calls `router.go('/login')`, it synchronously triggers a new `_processRouteInformation` via `notifyListeners()`. Flutter's Router mints a new transaction token, and the re-entrant parse's result is dropped due to token churn.

## Fix

In `parser.dart`, change `await Future<void>.sync(callback)` to `scheduleMicrotask(() async { await callback(); })`. This defers the callback to the microtask queue, ensuring `router.go()` runs after the current parse has completed and Flutter's Router has committed the result.

## Environment

- **go_router:** 17.1.0 (fork with `onEnter` API)
- **Flutter:** 3.41.2 (stable)
- **Dart SDK:** 3.11.0 (stable)
