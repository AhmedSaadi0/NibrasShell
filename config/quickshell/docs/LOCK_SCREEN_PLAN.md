# NibrasShell — Lock Screen & Idle Dimming Implementation Plan

Status: **plan only**. This file is the only artifact created in this turn. No source, QML, PAM, config, translation, `~/.config/hypr/`, or keyboard-bind files were changed.

## 0. Decisions locked in

- Quickshell owns the whole pipeline: **dim → lock → DPMS off → optional auto-suspend (NibrasShell only)**. `~/.config/hypr/` is **not** edited automatically; the user must disable/stop `hypridle` before Phase 2/5 verification (prerequisite gate in §7).
- No keyboard shortcuts are added. Entry points are IPC, EventBus, and a Lock tile in the power menu.
- `hypridle` **is installed and running today** (`/usr/bin/hypridle`, PID 1669, autostarted by `~/.config/hypr/lua/autostart.lua`) with active 300s dim, 600s DPMS-off and 10800s suspend listeners in `~/.config/hypr/hypridle.conf`; its lock listener is commented out. Running it with NibrasShell causes real conflicts (600s DPMS before 900s lock, `brightnessctl -s/-r` fights) — see §7.
- Hardware-agnostic: never hardcode a backlight device or connector. Use `brightnessctl -c backlight`, runtime screen discovery, and overlay fallback so Intel, AMD, NVIDIA, laptops, and desktops without an external monitor behave identically.
- Fully unified in NibrasShell with its own Settings page: `Lock & Idle` in `SidePanel.qml`/`Main.qml` at `pageIndex: 12`, leaving existing indices 0..11 untouched.
- `autoLockEnabled: false` is the shipped safety default. Manual lock, dim, settings, PAM test, and DPMS work; idle does **not** engage the `WlSessionLock` until explicitly flipped after live verification.
- Dual dim: click-through QML overlay on every valid screen + class-`backlight` snapshot/restore through the upgraded `services/Brightness.qml` on whatever panel exists. DDC is used only when proven working; today `HDMI-A-1` DDC fails (`EIO`, VCP 10 ERR), so unsupported displays are covered by the overlay alone.
- One shared `PamContext`, password only, repo-local PAM file via `PamContext.configDirectory`. Its `user` is **only** the real OS username (`Quickshell.env("USER")`, `id -un` fallback); `App.username` is display-only.
- `quickshell ipc call NibrasLock unlock` is test-only: it refuses/no-ops unless `NIBRAS_LOCK_TEST=1` or `NIBRAS_LOCK_DISABLE=1`; normal runtime can only unlock through PAM.
- Arabic UI (`Qt.uiLanguage = "ar"` is hardcoded in `shell.qml`); all new strings use `qsTr()`.

## 1. Probe result (read-only, no source files written)

Public import works on the installed build — the qmltypes discrepancy from the discovery report is resolved in favor of the public API.

Method: QML source was held in an anonymous `memfd` and loaded with `quickshell -n -p /proc/self/fd/3` (`QML_DISABLE_DISK_CACHE=1`), with a 15s timeout. Nothing was written under the repo; `WlSessionLock` was **not** instantiated. The pre-existing shell (PID 23139) was unaffected.

QML imported `QtQuick`, `Quickshell`, `Quickshell.Wayland` and declared `IdleMonitor`, `IdleInhibitor`, `ShortcutInhibitor` inside a `ShellRoot`.

Evidence from Quickshell's own runtime log:

```
quickshell.qmlscanner: Scanning qml file "/proc/self/fd/3"
quickshell.wayland.idle_notify: Created qs::wayland::idle_notify::impl::IdleNotification(...) with timeout: 300000 respects inhibitors: true
Configuration Loaded
```

Conclusion:

- `import Quickshell.Wayland` + `IdleMonitor { timeout: 300; respectInhibitors: true }` compiles and creates a real `ext-idle-notify-v1` notification with the expected values.
- `IdleMonitor.timeout` is in **seconds**: passing `300` produced `timeout: 300000` (ms) in the compositor. Pass `App.dimTimeoutSec` / `App.lockTimeoutSec` directly; never multiply by `1000`.
- `IdleInhibitor` and `ShortcutInhibitor` also parsed under the public import with no error.
- The local `.qmltypes` private-only export is a tooling artifact; use the public import in the implementation.
- The probe did leave ephemeral Quickshell runtime state at `/run/user/1000/quickshell/by-id/pcw3zf1sot/` (normal Quickshell behavior, outside the repo). The probe process was killed by the timeout.

## 2. Verified environment facts used by this plan

| Item | Verified value |
|---|---|
| Quickshell | 0.3.2, rev `9b0f339`, Fedora COPR |
| Hyprland | 0.57.2, exposes `ext_session_lock_v1` + `ext_idle_notifier_v1` |
| Lock types | `WlSessionLock { locked, secure, surface, unlock() }`, `WlSessionLockSurface { screen, width, height, color }` |
| Idle types | `IdleMonitor { enabled, timeout (seconds, real), respectInhibitors, isIdle }` |
| PAM | `PamContext { active, config, configDirectory, user, message, messageIsError, responseRequired, responseVisible }`, `start/abort/respond`, `completed/error`; only `auth` rules are used |
| PAM system | `authselect local + with-fingerprint`; `system-auth` has `pam_fprintd.so sufficient`, `password-auth` does not; `fprintd-list` → no devices; no `hyprlock` PAM service |
| Display identity | `ConfigStore.qml` defaults `App.username` to `"Username"` and it can be an Arabic display name; never use it as a PAM user |
| logind | Session `Lock`/`Unlock` signals + manager `PrepareForSleep` present; `gdbus monitor --system --dest org.freedesktop.login1` works as the user; `systemd-inhibit --what=sleep --mode=delay` is available for a delay lock |
| Brightness | active class-`backlight` device today is **`nvidia_0` (max 100)**; `brightnessctl -c backlight -l` lists it. No `intel_backlight` on this machine today |
| DDC | `ddcutil detect --brief` sees `HDMI-A-1` (`SAM:C27F390`, serial `HCPT200555`) on **`/dev/i2c-6`**; `ddcutil -b 6 getvcp 10 --brief` fails (`DDC communication failed`, `-EIO`, VCP 10 ERR). `card1-eDP-1` is an invalid display |
| Click-through | `QsWindow.mask: Region { ... }` is the documented clickthrough mask; test empty `Region {}` first, fall back to `Region { item: ...; intersection: Intersection.Xor }` if needed |
| i18n tooling | `lrelease` exists at `/usr/lib64/qt6/bin/lrelease` (not on `PATH`); `lupdate` not found |
| hypridle | installed/running (`/usr/bin/hypridle`, PID 1669 via `lua/autostart.lua`); active `hypridle.conf` listeners: 300s `brightnessctl -s set 50%`, 600s DPMS off, 10800s suspend; lock listener commented |
| DPMS | `windows/settings/monitors/MonitorItem.qml` uses `hyprctl dispatch hl.dsp.dpms({ action = "on"|"off", monitor = "<name>" })`; reuse that form with a plain `hyprctl dispatch dpms on|off` fallback |
| Video wallpaper | `components/MediaItem.qml` has no `muted` property and its `MediaPlayer` has no `AudioOutput`; must be added before lock surfaces can mute video |

## 3. Persistent configuration

### `config/ConfigStore.qml` — add properties + `updateProperties()` parsing

| Key | Type | Default | Meaning |
|---|---|---|---|
| `lockEnabled` | bool | `true` | Master feature switch; manual lock and lock surfaces allowed |
| `autoLockEnabled` | bool | `false` | Safety gate for **idle-driven** lock only |
| `dimTimeoutSec` | int | `300` | Idle seconds before dim |
| `lockTimeoutSec` | int | `900` | Idle seconds before auto-lock |
| `dpmsOffAfterLockSec` | int | `60` | Seconds after `lock.secure` before DPMS off; `0` disables |
| `autoSuspendSec` | int | `0` | Optional idle-to-suspend timeout; `0` disables (safety default) |
| `dimOverlayOpacity` | real | `0.65` | Black overlay alpha, 0..1, with fade |
| `dimBacklightPercent` | int | `20` | Target for the detected class-`backlight` panel(s) via `services/Brightness.qml`; no device name stored |
| `respectIdleInhibitors` | bool | `true` | Forwarded to all three `IdleMonitor.respectInhibitors` |
| `lockOnSuspend` | bool | `true` | Lock on `PrepareForSleep(true)` / logind session Lock |

Parsing follows the existing `if (data.key !== undefined) store.key = data.key;` style. `set`/`setMultiple`/`FileView` already persist to `~/.nibrasshell.json`, so no new storage mechanism is needed. Do **not** add a PAM service name as a user setting; the service file path is a fixed implementation constant.

### `config/App.qml` — add one `property alias` per key (10 total)

`App.username`, `App.subtitle`, and `App.profilePicture` (already present) are **display only** on the lock card. `PamContext.user` must come strictly from `Quickshell.env("USER")` (fallback `id -un` via a read-only Process if the env var is missing). Do not pass `App.username`: its default is `"Username"` and users set display names like `"Ahmed"` or Arabic text, which would make `pam_unix.so` always fail.

### Dedicated Settings page — `windows/settings/components/general/LockIdlePage.qml`

New page inheriting `BaseGeneralSettings` (like `SystemPage.qml`, `AIPage.qml`, etc.), using `syncFromConfig()`, `serializeData()`, `SettingSwitch`, and `SliderWithLabel`. It exposes **all 10 keys**: `lockEnabled`, `autoLockEnabled`, `dimTimeoutSec`, `lockTimeoutSec`, `dpmsOffAfterLockSec`, `autoSuspendSec`, `dimOverlayOpacity`, `dimBacklightPercent`, `respectIdleInhibitors`, `lockOnSuspend`. `autoLockEnabled` is visually marked as requiring a verified manual lock first; `autoSuspendSec` is marked disabled-by-default and only meaningful once `hypridle` is stopped.

`windows/settings/SidePanel.qml` and `windows/settings/Main.qml` must be read in full at implementation time. Add one item to the `SidePanel` model — `{ name: qsTr("Lock & Idle"), icon: "\uf023", type: "item", pageIndex: 12 }` — and one `Component`/`createObject` entry in `Main.qml`'s `pages` array at **index 12**. Keep existing indices 0..11 exactly as they are (General 0..3, Appearance 4..9, Devices 10..11); update the “order must match SidePanel” comment, do not renumber existing pages.

Validation in `syncFromConfig()`/`serializeData()` (and again defensively in `LockService`): `dimTimeoutSec === 0` disables the dim stage (no overlay/backlight change, lock timer still active); when dim > 0, `lockTimeoutSec <= dimTimeoutSec` is rejected/clamped to `dimTimeoutSec + 60` so the lock monitor can never fire before the dim monitor; `dpmsOffAfterLockSec === 0` disables DPMS-off; `autoSuspendSec === 0` disables NibrasShell auto-suspend. DPMS-on on wake/unlock still runs regardless.

## 4. Architecture

### New: `config/nibras-lock`

```
auth required pam_unix.so
```

Password only; no fingerprint, no login-session PAM stack. `PamContext.config: "nibras-lock"`, `configDirectory` set relative to the QML file (Quickshell resolves it relative to the source file, so it can point at `config/` inside the repo).

### New: `services/LockService.qml` (`pragma Singleton`)

Single owner of state and shared objects:

- `state`: `awake | dimmed | locked`; derived `dimActive`, `locked`, `dpmsOff`.
- Three `IdleMonitor`s: `dimMonitor.timeout = App.dimTimeoutSec`, `lockMonitor.timeout = App.lockTimeoutSec`, `suspendMonitor.timeout = App.autoSuspendSec` — **seconds, passed directly, no `* 1000`** — all with `respectInhibitors: App.respectIdleInhibitors`, `enabled: App.lockEnabled && !killSwitch`. Apply the same clamping as Settings at runtime: ignore dim when `dimTimeoutSec === 0`, coerce `lockTimeoutSec` to at least `dimTimeoutSec + 60` when dim is enabled, and disable the suspend monitor when `autoSuspendSec === 0`. Protocol monitors are simpler and more reliable than QML escalation timers, and allow NibrasShell to replace `hypridle` entirely.
- `WlSessionLock { id: lock; surface: <component from LockSurface.qml>; locked: <state === locked> }`. Never created while `NIBRAS_LOCK_DISABLE=1`.
- `PamContext` — **one instance only**, shared by all surfaces. `user: Quickshell.env("USER")` (read-only `id -un` fallback if empty); **never `App.username`**, which is display-only. `config`/`configDirectory` as above. Surfaces bind to `message`, `messageIsError`, `responseRequired`, `responseVisible`; input calls `LockService.pamRespond(text)`, `pamAbort()`, `pamStart()`.
- Shared input state: `pamBusy`, `failedAttempts`, `lastError`, `authScreenName` (see multi-monitor), reset on every `lock()`/`unlock()`.
- Backlight control: delegate entirely to the upgraded `services/Brightness.qml` — call `Brightness.applyDim(App.dimBacklightPercent)` on entering dim and `Brightness.restoreDim()` on activity, unlock and wake. `LockService` contains **no** `brightnessctl` command and no device name. Do not use `brightnessctl -s/-r` (hypridle's stack).
- DPMS control via `hyprctl dispatch hl.dsp.dpms({ action = "off"|"on", monitor = "<screen name>" })` to match `MonitorItem.qml`, with a plain `hyprctl dispatch dpms off|on` fallback if that Lua dispatch is unavailable. Never issue DPMS off for invalid/placeholder outputs.
- `Process` running `gdbus monitor --system --dest org.freedesktop.login1` (read-only); parse `PrepareForSleep` boolean and only this session's `Lock`/`Unlock` signals. Session object path is `/org/freedesktop/login1/session/_<XDG_SESSION_ID>` (derive at runtime, do not hardcode `9`).
- Sleep delay lock: while `lockOnSuspend && lockEnabled`, hold a `systemd-inhibit --what=sleep --mode=delay --who=NibrasShell --why="Lock before suspend" ...` process (keep its stdin/FD open; a minimal helper/FIFO is acceptable if Quickshell `Process` cannot hold it). On `PrepareForSleep(true)`: engage `lock` immediately, then release the inhibitor **only once `lock.secure === true`**. Enforce a 2–3s safety timeout that releases the inhibitor regardless, so a failed surface can never hang suspend; log a warning and still request lock if the inhibitor cannot be acquired.
- `DPMS` timer: started when `lock.secure === true`; stopped/cleared on unlock, activity, resume. `dpms on` is issued immediately on wake/unlock/activity, followed by `forceActiveFocus()` on the active password field after `PrepareForSleep(false)`, DPMS-on, and `Quickshell.screensChanged`.
- `autoSuspend` path: `suspendMonitor.isIdle` (with `autoSuspendSec > 0`) → acquire the same sleep-delay inhibitor, engage lock, wait for `lock.secure`, then `systemctl suspend`; gated by `lockEnabled` and the test kill-switch.
- Functions: `lock()`, `unlock()` (**test-gated only**), `pamStart()`, `pamRespond()`, `pamAbort()`, `testPam()` (test-gated), `onActivity()` (implicit through `isIdle` transitions + surface input), `releaseSleepInhibit()` (idempotent, timeout-safe), `restorePasswordFocus()`.
- Guard: `Component.onDestruction` best-effort `lock.unlock()`; operator rule remains “no reload while locked”.

### Upgrade: `services/Brightness.qml` (reuse, do not duplicate)

All backlight knowledge stays in the existing singleton; `LockService` only calls its helpers.

- Restrict every `brightnessctl` query/command to class `backlight` (`brightnessctl -c backlight ...`). Desktops with no panel get an empty device list, not `leds` devices like `enp7s0-0::lan`/capslock, and no `NaN` from parsing a missing max.
- Null-safe `ddcutil` parsing: guard `Monitor:`/`I2C bus:` lookups with `?.`/existence checks, validate `parseInt(...)`, and require `max > 0` before computing a brightness fraction. Track `hasValidHardwareBrightness` / `ddcWorking`; a failed VCP 10 read (today `EIO`, VCP 10 ERR on `/dev/i2c-6`) marks that monitor DDC-unsupported and skips all later DDC calls for it — `DimOverlay` covers it instead.
- Replace the single shared `Process { id: setProc }` with `Quickshell.execDetached(...)` (or a per-monitor `Process`) so two monitors can never overwrite each other's queued command.
- Add `applyDim(percent)` and `restoreDim()`: snapshot the current class-`backlight` value once, apply the dim percentage, and restore the snapshot without corrupting the normal `Brightness.brightness` baseline used by widgets. If `brightnessUp`/`brightnessDown` (NibrasShell shortcuts) are triggered while dimmed, invalidate/update the snapshot so the user's new value wins on restore.
- No hardcoded `intel_backlight`, `nvidia_0`, `eDP-1`, or `HDMI-A-1` anywhere in QML; all names come from `brightnessctl -c backlight` / `Quickshell.screens` / `ddcutil detect` at runtime.

### New: `windows/lock/DimOverlay.qml`

Per-screen `PanelWindow` (`Variants { model: Quickshell.screens }` in `shell.qml`):

- Full anchors, `WlrLayershell.layer: WlrLayer.Overlay`, namespace `NibrasShell:dim`, `exclusionMode: Ignore`, `focusable: false`, `keyboardFocus: None`, `aboveWindows: true`.
- Placeholder-screen crash guard: skip the instance when `!screen || screen.name === ""` (also skip zero-size outputs). Do not create GL surfaces for invalid outputs; NVIDIA/Wayland DPMS off/on can otherwise crash Quickshell with `EGL_BAD_ALLOC`.
- Keep the `PanelWindow.color: "transparent"` (surface format stays non-opaque); put a fullscreen inner `Rectangle { color: "black" }` inside and animate **its** `opacity` to `App.dimOverlayOpacity` (~300ms ease). Window `visible` follows `LockService.dimActive` but is set to false only after the inner fade-out completes.
- `mask`: test `Region {}` (empty region ⇒ click-through) first in Phase 2; if the compositor still grabs input, use `Region { item: <fullscreen item>; intersection: Intersection.Xor }` as the documented fallback (inverts the clickable region). Verify live before trusting the dim stage.
- Hidden entirely while locked; lock surfaces provide their own scrim, preventing double dimming.

### New: `windows/lock/LockSurface.qml`

The component assigned to `WlSessionLock.surface`; each instance creates a `WlSessionLockSurface` for one screen.

- Fills the surface with a dark scrim + reused `Wallpaper`/`MediaItem` (blurred/dimmed) for visual continuity with `Desktop.qml`; uses `ThemeManager.selectedTheme` colors/typography/dimensions.
- Uses the surface's `screen` property to decide its role; skip/rely-on-fallback when `!screen || screen.name === ""` so placeholder outputs never become the auth surface.
- `LockContext`-style shared state lives in `LockService`, not in the surface. `LockService.authScreenName` is updated from `Hyprland.focusedMonitor.name`, pointer entry (`HoverHandler`/`MouseArea`) **and key presses on any surface**; fallback order: focused valid monitor → any valid screen from `Quickshell.screens` (no hardcoded `eDP-1`). Re-run `LockService.restorePasswordFocus()` after `PrepareForSleep(false)`, DPMS-on, and `Quickshell.screensChanged`.
- Primary surface: inline auth card bound to the single shared `PamContext` — prefilled with the real OS user (display name/subtitle/avatar from `App.*` shown separately), editable only if needed, hidden password field when `!responseVisible`, visible prompt on failure, Enter/`respond()`, Abort/Unlock buttons, clear Arabic errors via `qsTr()`.
- Secondary surfaces: passive blurred wallpaper + `SystemClock` time/date + battery (`SystemService`) + short status text; no second `PamContext`, no password field. Pointer entry **or `Keys.onPressed`** on a passive surface immediately switches `authScreenName` to that screen, force-activates the password field there, and forwards/preserves the typed character (accept the key event so it is not lost); the card follows the user.
- Video wallpapers: `components/MediaItem.qml` must first gain `property bool muted: false` wired to an `AudioOutput` (`volume: muted ? 0 : 1`); only then may lock surfaces pass `muted: true`. Avoid decoding the same video independently on every surface — prefer a static blurred wallpaper on secondary screens (or one shared video item) to keep lock lightweight.
- Never owns a lock/unlock timer; all transitions go through `LockService`.

### Modified: existing files

| File | Change |
|---|---|
| `config/ConfigStore.qml` | 10 properties + `updateProperties()` entries (add `autoSuspendSec`) |
| `config/App.qml` | 10 aliases |
| `config/EventNames.js` | `REQUEST_LOCK`, `REQUEST_UNLOCK`, `LOCK_STATE_CHANGED`, maybe `PAM_TEST_RESULT` |
| `services/Brightness.qml` | Upgrade only: `-c backlight`, null-safe DDC + `ddcWorking`, per-monitor commands, `applyDim`/`restoreDim`, no device names |
| `components/MediaItem.qml` | Add `property bool muted: false` + `AudioOutput` binding so lock video can be muted without a QML property error |
| `shell.qml` | Reference `LockService`; add per-screen `DimOverlay` `Variants`; add `IpcHandler { target: "NibrasLock" }` with `lock()`, `unlock()`, `pamTest()` (last two test-gated); hook `Quickshell.screensChanged` → focus restore |
| `windows/poweroption/PowerOptions.qml` | Fifth `PowerTile`: icon `\uf023`, label `qsTr("Lock")`. Widen `viewStack.Layout.preferredWidth` from `800` to `860`–`880` (or reduce tile width/spacing) so 5 × 150px tiles + 4 × 12px gaps do not clip the sliding highlight. On click call `root.close()` **first** to release `WlrKeyboardFocus.Exclusive`, then `LockService.lock()`; no confirmation step, no `prepareGoodbye` |
| `windows/poweroption/PowerMenuWindow.qml` | No structural change expected; rely on the Lock tile's `root.close()` before the lock surface takes focus (verify live) |
| `windows/settings/components/general/LockIdlePage.qml` | **New** dedicated `BaseGeneralSettings` page with all 10 keys + validation |
| `windows/settings/SidePanel.qml` / `windows/settings/Main.qml` | Add `Lock & Idle` item and `pages[12]`; leave 0..11 untouched |
| `translations/ar.ts` | New `<context>` entries for new strings; then regenerate `ar.qm` with `/usr/lib64/qt6/bin/lrelease translations/ar.ts -qm translations/ar.qm` |
| `windows/leftwindow/Menus.qml` / `binds.lua` | **No change** (no shortcuts); `windows/settings/components/general/SystemPage.qml` also unchanged |

### Prerequisite gate: stop `hypridle` before live Phase 2/5 verification

`hypridle` is running today. Its 300s dim writes `brightnessctl -s set 50%` / `-r`, its 600s DPMS-off fires **before** our 900s lock, and its 10800s suspend can race the lock/inhibitor path. Before Phase 2 and again before Phase 5, the user must either comment out the `autostart.lua` line / the three `hypridle.conf` listeners and restart Hyprland, or stop the process (`pkill -x hypridle`) for the test session. This plan does **not** modify `~/.config/hypr/` automatically; do not mark Phase 2/5 verified while `pgrep -x hypridle` succeeds.

### Environment kill-switches (not persisted)

- `NIBRAS_LOCK_DISABLE=1`: no idle monitors, no `WlSessionLock`, no DPMS commands, no sleep inhibitor; `pamTest`, `unlock` and verbose logging are allowed. Use this to recover a broken build without touching config.
- `NIBRAS_LOCK_TEST=1`: exposes `quickshell ipc call NibrasLock pamTest` **and** `unlock` plus verbose state logging; never enabled in the normal autostart environment. Without either variable, `unlock`/`pamTest` are no-ops — a local script cannot bypass PAM.

## 5. State machine / edge cases

1. **Idle inhibitors:** with `respectIdleInhibitors: true`, fullscreen video/MPRIS inhibitors keep both monitors non-idle; dim/lock never start. Verify with a playing fullscreen video.
2. **Activity during dim:** either `IdleMonitor.isIdle` flips false or the dim overlay receives pointer/keyboard on the way through; cancel backlight timer, fade overlay out, then restore backlight. Order matters: restore backlight **before** hiding the overlay to avoid a bright flash.
3. **Manual brightness change while dimmed:** `Brightness.restoreDim()` must not clobber a user-adjusted value. Invalidate/update the snapshot when `brightnessUp`/`brightnessDown` fires during dim and prefer the latest user value on restore; never corrupt the normal `Brightness.brightness` baseline.
4. **Lock while already locked:** `WlSessionLock` silently ignores a second lock; all `lock()` calls must be idempotent and must not reset `PamContext` mid-auth.
5. **PAM failure:** keep the card open, show `message` + `messageIsError`, clear the password field, rate-limit via `pam_faildelay` (already 2s in system auth), never unlock on `PamError`.
6. **PAM success:** `completed(PamResult.Success)` → stop DPMS timer, `Brightness.restoreDim()`, `dpms on`, restore password focus, hide overlays, `lock.locked = false`, emit `LOCK_STATE_CHANGED`, reset shared auth state.
7. **Suspend/lid:** acquire the `systemd-inhibit --what=sleep --mode=delay` hold while `lockOnSuspend && lockEnabled`; on `PrepareForSleep(true)` engage lock immediately (do not wait for idle timers) and release the inhibitor only after `lock.secure === true` or a 2–3s safety timeout, whichever first. `PrepareForSleep(false)` → `dpms on` + backlight restore. Session `Lock` signal engages lock even when `autoLockEnabled` is false (explicit external request); `Unlock` only clears logind's hint, never bypasses PAM.
8. **DPMS off and input:** DPMS off must not leave the lock stuck; any input or wake signal brings DPMS back on. Do not issue `dpms off` before `lock.secure === true`.
9. **Monitor hotplug:** `WlSessionLock` creates surfaces for screens present at lock time; if a screen is plugged in while locked it gets a new surface. Re-evaluate `authScreenName` if the auth screen disappears.
10. **Focus ambiguity while locked:** Hyprland focus may stop updating under a session lock; rely on pointer-entry (`HoverHandler`/`MouseArea`) **and** `Keys.onPressed` on every surface. Typing on a secondary surface switches `authScreenName`, focuses the primary card there, and forwards the typed character so no keystroke is lost.
11. **hypridle conflict (real today):** its 300s `brightnessctl -s/-r`, 600s DPMS-off (before our 900s lock) and 10800s suspend will fight this service. Gate Phase 2/5 on hypridle being stopped/disabled by the user (§7); `~/.config/hypr/` is never edited automatically.
12. **Fingerprint:** excluded by the custom PAM file; no `pam_fprintd` prompt, no suspend-related fingerprint hang.
13. **Shell crash while locked:** compositor keeps the lock (by design). TTY recovery below.
14. **IPC unlock bypass:** `unlock`/`pamTest` are no-ops in normal runtime; only `NIBRAS_LOCK_TEST=1` or `NIBRAS_LOCK_DISABLE=1` permits them. Never log or echo test tokens into autostart.
15. **Timeout units/validation:** pass seconds directly (no `* 1000`); `dimTimeoutSec === 0` disables dim, `lockTimeoutSec <= dimTimeoutSec` is clamped to `dimTimeoutSec + 60` when dim is enabled, `dpmsOffAfterLockSec === 0` disables DPMS-off, `autoSuspendSec === 0` disables auto-suspend. Both Settings page and `LockService` enforce this.
16. **Video wallpaper on lock:** add `muted` + `AudioOutput` to `MediaItem.qml` first; then pass `muted: true` from lock surfaces. Avoid per-surface video decoding (static blurred source on secondary screens).
17. **Power menu focus:** the Lock tile must call `PowerMenuWindow.close()` before `LockService.lock()` so `WlrKeyboardFocus.Exclusive` is released; verify the five-tile row does not clip.
18. **Hardware portability:** no `intel_backlight`, `nvidia_0`, `eDP-1`, or `HDMI-A-1` literals in QML. On desktops with no class-`backlight` device, skip hardware dim entirely and rely on the overlay; on any GPU vendor use the same `brightnessctl -c backlight` path.
19. **DDC unsupported:** when VCP 10 returns `EIO`/ERR (today `/dev/i2c-6`), mark `ddcWorking: false` for that monitor and never call `ddcutil ... setvcp` again; no `NaN` from `parseInt`/zero max.
20. **Placeholder outputs / DPMS:** skip `!screen || screen.name === ""` in every `Quickshell.screens` consumer; after DPMS-on, `PrepareForSleep(false)` and `Quickshell.screensChanged`, re-run `forceActiveFocus()` on the password field. Prefer `hl.dsp.dpms(...)` with plain `dpms` fallback; avoid NVIDIA/Wayland `EGL_BAD_ALLOC`.
21. **Auto-suspend:** `autoSuspendSec > 0` only when `hypridle` is disabled; hold the sleep inhibitor, lock first, wait for `secure`, then `systemctl suspend`; `0` disables the monitor entirely.

## 6. Phased implementation & verification

### Phase 0 — Probe (done)
Result in §1. No further action.

### Phase 1 — Config + dedicated Settings page only (no lock, no overlay)
Files: `ConfigStore.qml`, `App.qml`, `LockIdlePage.qml`, `SidePanel.qml`, `Main.qml`, `EventNames.js`. Read both settings files in full before editing; add `pageIndex: 12` without shifting 0..11.
Verify: all 10 values appear in `~/.nibrasshell.json`; survive shell restart; `App.*` aliases resolve; `Lock & Idle` opens via Settings and Save/Cancel works; timeout validation (dim `0`, `lockTimeoutSec <= dimTimeoutSec` when dim > 0, DPMS `0`, `autoSuspendSec 0`) behaves as specified; no new QML errors in `quickshell log`.

### Phase 2 — Dim only (`autoLockEnabled` stays false)
Prerequisite: `hypridle` stopped/disabled by the user (§7); do not verify while `pgrep -x hypridle` succeeds.
Files: `services/Brightness.qml` upgrade, `DimOverlay.qml`, `LockService.qml` (dim parts), `shell.qml` (Variants), no raw `brightnessctl` in LockService.
Verify with short test timeouts (values are **seconds**): overlay fades via inner `Rectangle` while window stays `color: "transparent"`; click-through works with empty `Region {}` — else `Intersection.Xor`; `brightnessctl -c backlight` targets the detected device (`nvidia_0` today, max 100) and never `leds`/`NaN`; on a desktop with no panel, overlay-only dim works; DDC failure on `/dev/i2c-6` is detected once and skipped; placeholder outputs are skipped; fullscreen video inhibits dim; `dpmsOffAfterLockSec: 0` never runs DPMS-off; no lock surface appears.

### Phase 3 — PAM pre-test (no `WlSessionLock`)
Files: `config/nibras-lock`, `PamContext` in `LockService`, `pamTest()` IPC.
Verify: `NIBRAS_LOCK_TEST=1 quickshell ipc call NibrasLock pamTest` → correct password for the **real OS user** (`Quickshell.env("USER")`) succeeds; `App.username`/Arabic display name is shown but never sent to PAM; wrong password shows Arabic error; no fingerprint prompt, no session/suspend side effects; abort works. Also confirm `unlock` and `pamTest` are no-ops without the test env.

### Phase 4 — Manual lock only
Files: `LockSurface.qml`, `WlSessionLock` wiring, `IpcHandler`, PowerOptions Lock tile.
Verify in this order:
1. `NIBRAS_LOCK_DISABLE=0`, `autoLockEnabled: false`, and `NIBRAS_LOCK_TEST=1` for this phase; call `quickshell ipc call NibrasLock lock` (lock is allowed in normal runtime, unlock is not).
2. Confirm `lock.secure === true`, primary card on focused screen, secondary passive, one `PamContext`, real OS user shown, and that the power menu Lock tile closed the menu before locking.
3. Type password → unlock via PAM; confirm backlight/DPMS/overlay state restored. Test the test-gated IPC `unlock` separately.
4. Test secondary-screen focus: hover and then type on the passive screen; card must move there, keep focus, and not lose the first character. Test one monitor, then both, then unplug while locked. If the theme wallpaper is a video, confirm it is muted and not decoded twice.
5. **Intentionally kill Quickshell while locked and practice TTY recovery** before Phase 5.

### Phase 5 — Auto-lock, logind, DPMS, optional auto-suspend
Prerequisite: `hypridle` stopped/disabled by the user (§7).
Files: `LockService` idle→lock/suspend wiring, third `IdleMonitor`, gdbus monitor, DPMS timer.
Verify: idle at 900s locks only when `autoLockEnabled: true`; DPMS off at +60s via `hl.dsp.dpms(...)` (fallback plain dispatch) and on at wake/activity/unlock; password focus restored after `PrepareForSleep(false)`, DPMS-on and screen changes; `loginctl lock-session` triggers our lock; with `lockOnSuspend && lockEnabled`, `systemd-inhibit` is held on `PrepareForSleep(true)` and released only after `lock.secure === true` (or 2–3s) — **suspend/resume must show no unlocked desktop flash**; with `autoSuspendSec > 0`, idle suspends only after a secure lock; `0` never suspends; inhibitor failure degrades safely; `loginctl unlock-session` does not bypass PAM.

### Phase 6 — i18n polish
Wrap all new user-facing strings in `qsTr()`, add contexts/messages to `translations/ar.ts`, recompile `translations/ar.qm` with `/usr/lib64/qt6/bin/lrelease`, verify Arabic rendering in overlay, auth card, settings section, and power tile.

## 7. Safety / recovery runbook

- Before any live lock test: confirm `NIBRAS_LOCK_DISABLE=1` can be set in the shell environment and that you can reach a TTY.
- **Before Phase 2 and Phase 5:** confirm `pgrep -x hypridle` is empty. Stopping `hypridle` / disabling its listeners in `~/.config/hypr/lua/autostart.lua` or `hypridle.conf` is a user action; this plan never edits those files automatically.
- Never hot-reload (`quickshell ipc ... reload` / config reload) while `WlSessionLock.locked === true`. Best-effort `unlock()` in `Component.onDestruction` is not a guarantee.
- If the display is stuck locked: `Ctrl+Alt+F3` → log in → `pkill -x quickshell` (killing the lock owner makes Hyprland drop the lock) → `Ctrl+Alt+F2` to return. Restart Quickshell from the Hyprland autostart path. Last resort: `loginctl terminate-session $XDG_SESSION_ID`.
- Keep `autoLockEnabled: false` until Phase 4 passes, including the deliberate crash/recovery drill.
- Do not rely on IPC `unlock` for recovery in normal runtime: it is a no-op without `NIBRAS_LOCK_TEST=1`/`NIBRAS_LOCK_DISABLE=1`. Use PAM, or the TTY kill above.
- After DPMS toggles, resume, or monitor hotplug, the password field must be re-focused; placeholder outputs are skipped to avoid NVIDIA/Wayland `EGL_BAD_ALLOC`.
- No keyboard shortcuts are added; the user wires their own after implementation.

## 8. Open risks

- `QsWindow.mask` click-through needs live confirmation; if it fails, the dim overlay blocks input and must be removed rather than worked around.
- External monitor cannot be hardware-dimmed (`ddcutil` DDC failure); overlay is the only uniform mechanism.
- `hypridle` is installed and running today; without the user-side gate its 600s DPMS-off and `brightnessctl -s/-r` conflict with this pipeline. The plan never edits `~/.config/hypr/` automatically.
- `ar.qm` regeneration requires `/usr/lib64/qt6/bin/lrelease` (not on `PATH`); no `lupdate` is installed, so new `.ts` entries are added manually.
- The sleep delay inhibitor can delay suspend if not released; the 2–3s hard timeout is mandatory, and inhibitor acquisition failure must degrade to “lock now, no delay” rather than blocking suspend.
- Five power tiles at 800px are cramped; widening to 860–880px must be visually checked, and `PowerMenuWindow` exclusive focus must be released before the lock surface appears.
- Portability risk: DDC VCP 10 fails on the external Samsung panel (`/dev/i2c-6` today) and desktops may have no class-`backlight` device at all; overlay remains the only universal dim path.
- `MediaItem.qml` has no `muted` property yet; passing `muted: true` before adding `AudioOutput` would throw a QML error.
- `autoSuspendSec` is opt-in (`0`); enabling it while `hypridle` still runs would produce two suspend paths.

Skipped: no source edits, no PAM/system/hypr config changes, no lock activation, no shortcut changes. Residual risk: `ext-session-lock-v1` keeps the display locked if Quickshell dies while locked, `hypridle` conflicts unless the user stops it, DDC dimming on `HDMI-A-1` (`/dev/i2c-6`) does not work, and placeholder-output/DPMS handling must be verified on NVIDIA/Wayland.
