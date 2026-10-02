# PanelGuard 1.8.0

PanelGuard is a native Intel macOS utility designed for unattended remote access to an iMac through RustDesk while keeping the physical built-in panel dark.

## Architecture

PanelGuard 1.8 does not create virtual displays, mirror displays, disconnect the built-in display, or put the logical display to sleep. Those approaches were intentionally removed because they can alter macOS display topology or stop remote framebuffer updates.

Instead, PanelGuard:
- Keeps the original built-in display logically awake and drawable.
- Keeps the Mac/display pipeline awake with `caffeinate -d -i -s`.
- Uses the Intel Apple backlight driver's `linear-brightness` IOKit parameter.
- Requires that the hardware linear-brightness range reports a true minimum of 0.
- Forces only linear backlight output to 0; normal/user brightness is not used as the blackout mechanism.
- Refuses activation if the required hardware parameter is unavailable.

## Permanent Mode

Permanent mode is a hard latch with no timer.

Two independent enforcement loops keep the physical backlight at hardware linear zero:
1. An external watchdog process reasserts linear-brightness 0 every heartbeat.
2. The main app independently reasserts zero and restarts the watchdog or keep-awake helper if either exits.

macOS/WindowServer brightness changes are treated as drift and are overridden while permanent mode is active.

## Safety and Restore

- The 10-second test automatically restores the original hardware values.
- Explicit restore uses a RESTORING barrier state so neither enforcement loop can write zero during restoration.
- The main app waits for the watchdog to terminate before restoring hardware values.
- Watchdog-driven restore publishes the RESTORING barrier before restoration and only marks the guard inactive after restoration completes.
- If the watchdog dies during automatic restoration, the main app completes the restore.
- If the main app crashes or is killed, the independent watchdog restores the saved values.
- A later launch can recover a stale active/restoring state when its previous parent process is gone.
- Global restore shortcut: Control-Option-Command-B.
- Menu-bar restore and normal app quit also restore the original values.

## Display Integrity

PanelGuard 1.8 contains no:
- CGVirtualDisplay creation
- display mirroring configuration
- CoreDisplay/SkyLight display disconnect
- IODisplayWrangler display-sleep request

Therefore PanelGuard does not intentionally change display IDs, resolution, arrangement, wallpaper ownership, Spaces topology, or mirroring relationships.

## Build

- Native AppKit application
- Intel x86_64
- macOS 13 Ventura deployment target
- No embedded browser runtime
- No network code
- No external runtime dependencies
- Ad-hoc application signing in CI; the installer is not Apple Developer ID notarized

The CI host cannot physically validate the AppleBacklightDisplay hardware parameter used on the target 2017 iMac. Runtime activation remains fail-closed and requires the target Mac to expose linear-brightness with a minimum of 0.
