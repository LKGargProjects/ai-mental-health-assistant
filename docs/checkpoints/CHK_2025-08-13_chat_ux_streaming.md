# Checkpoint: Chat UX — Progressive Streaming & Keyboard Behavior

- Step Id: 7324
- When: 2025-08-13T08:10:26+05:30
- Scope: Interactive Chat UX polish + docs

## Implementation Note (as requested)
Progressive line-by-line AI message reveal — `lib/providers/chat_provider.dart`:
After sending, I create an empty AI message and progressively append lines with natural timing (prefers newline splits; otherwise sentence-like splits via regex; commas as fallback).

## What changed (summary)
- Chat input remains visible above keyboard by padding ListView bottom to measured input height.
- Keyboard does NOT dismiss on scroll; tap on free space or back dismisses it (`KeyboardDismissibleScaffold`).
- AI responses reveal progressively (line-by-line) with smooth bubble growth and auto-scroll.
- Send button slightly larger to reduce white margin in the input bar.

Touched files:
- `lib/screens/interactive_chat_screen.dart` — dynamic bottom padding, manual keyboardDismissBehavior, larger Send button (padding 14.h, icon 22.h).
- `lib/providers/chat_provider.dart` — progressive reveal logic with natural delays and typing indicator handling.
- `lib/models/message.dart` — made `content` mutable to support streaming updates.

## How to test (quick guide)
- iOS/Android/Web:
  1) Open chat, focus input, type to open keyboard.
  2) Scroll messages while keyboard is open — keyboard should stay open.
  3) Tap outside input — keyboard should dismiss. Press back — keyboard dismisses first, route pops on second.
  4) Send a message (e.g., "Tell me a short story with 3 lines\nLine 2\nLine 3"). Observe:
     - AI bubble grows smoothly as lines appear one by one.
     - View auto-scrolls to keep the latest content visible.
     - Last message stays visible above the input (not cut off by keyboard).
  5) Optional: Turn on reduce motion/accessibility and verify animations are subtle and content remains readable.

- Edge cases:
  - Very long single paragraph: reveals by sentence-like chunks; auto-scroll should keep up.
  - Empty/short AI response: typing indicator turns off; no stuck states.

## Rollback
- Revert commit or set ListView bottom padding to a fixed value and restore immediate message rendering.
