# PanelGuard 1.0.0

PanelGuard is a focused Intel macOS utility for keeping an iMac remote-desktop framebuffer alive while putting the built-in panel hardware brightness at zero.

Design goals:
- Native AppKit interface; no embedded browser runtime.
- Dynamically loads DisplayServices for the built-in Apple display.
- Global recovery shortcut: Control-Option-Command-B.
- 10-second automatic safety test.
- Independent watchdog restores saved brightness if the UI process disappears.
- Optional enforcement re-applies hardware zero if brightness keys are pressed.
- Optional caffeinate assertion keeps the Mac/display pipeline awake while guarded.
- No network code and no external runtime dependencies.

The build targets macOS 13+ on Intel x86_64. DisplayServices is a private Apple framework, so PanelGuard checks symbol availability at runtime and fails safely if unavailable. The CI build cannot physically validate the backlight behavior on the user's iMac.
