# XP & Undo Test Checklist (Quest Screen)

Scope: Flutter web/iOS/Android. Verify +XP chip pop animation, Undo behavior, and deterministic quest selection.

## Pre-checks
- [ ] Ensure backend not required (quests local). Internet optional.
- [ ] Build succeeds: `flutter pub get` then launch web/emulator.
- [ ] Date/time: note today’s date for deterministic selection (shown in logs).

## Launch
- [ ] Start app (debug). Navigate to `Quest` tab (`#/wellness-dashboard`).
- [ ] Confirm 4 cards render: Task A, Resource, Tip, Task B (order may vary but deterministic per day).

## Deterministic selection
- [ ] Open console logs. Expect: `selectToday <YYYY-MM-DD> => <ids...>`.
- [ ] Refresh page. Expect identical quest IDs in logs.

## Task complete → XP chip pop
- [ ] Tap a Task card (e.g., Study sprint).
- [ ] Expect: subtle card ripple; SnackBar with Undo.
- [ ] Expect logs:
  - `markComplete questId=...`
  - `progress stepsLeft=<n> xp=<m>`
  - `[XPChip] start=... end=...` (overlay coordinates)
- [ ] Header progress updates (steps left decreases; XP increases by task XP).

## Undo within window
- [ ] Tap Undo on SnackBar within 5s.
- [ ] Card resets (done off, XP chip available again).
- [ ] Expect logs:
  - `undoComplete questId=...`
  - `progress stepsLeft` increases; `xp` decreases appropriately.

## Resource gating
- [ ] Tap Resource once: shows XP chip pop and increments XP.
- [ ] Tap Resource again (same day): toast/notif indicates XP already counted. No additional XP.

## Tip behavior
- [ ] Tap Tip: verify expected microinteraction (if enabled). Ensure no crash; optional XP if configured.

## Persistence across reload
- [ ] Refresh page. Completed states persist for the day. Recompute progress matches logs.

## Visual polish
- [ ] XP chip uses star icon, 420ms duration, scale ~0.90→1.05, reads "+XP".
- [ ] No visual jank on bottom nav; Quest tab icon tinted active.

## Cleanup (debug-only)
- [ ] Remove temporary debug buttons/triggers.
- [ ] Keep or prune kDebugMode logs per release plan.

## Known considerations
- Determinism keys off date; at midnight, a new set is selected.
- Some microinteractions (timer ring) are subtle by design; validate via logs if unsure.
