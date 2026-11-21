# NibrasShell — Lock Screen & Idle Dimming Implementation Plan

Status: **plan only**. This file is the only artifact created in this turn. No source, QML, PAM, config, translation, `~/.config/hypr/`, or keyboard-bind files were changed.

## 0. Decisions locked in

- Quickshell owns the whole pipeline: **dim → lock → DPMS off**. `~/.config/hypr/` is untouched (`hypridle.conf`, `autostart.lua`, `binds.lua` stay as-is).
- No keyboard shortcuts are added. Entry points are IPC, EventBus, and a Lock tile in the power menu.
- `hypridle` is currently not installed, so no timer conflict exists today; if it is installed later, its 300/600/3600s listeners would duplicate this pipeline (see Risks).
- `autoLockEnabled: false` is the shipped safety default. Manual lock, dim, settings, PAM test, and DPMS work; idle does **not** engage the `WlSessionLock` until explicitly flipped after live verification.
- Dual dim: click-through QML overlay on every screen + `brightnessctl` snapshot/restore on `eDP-1` only. `HDMI-A-1` DDC is left untouched (`ddcutil getvcp 10` fails on bus 11).
- One shared `PamContext`, password only, repo-local PAM file via `PamContext.configDirectory`.
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
- `IdleInhibitor` and `ShortcutInhibitor` also parsed under the public import with no error.
- The local `.qmltypes` private-only export is a tooling artifact; use the public import in the implementation.
- The probe did leave ephemeral Quickshell runtime state at `/run/user/1000/quickshell/by-id/pcw3zf1sot/` (normal Quickshell behavior, outside the repo). The probe process was killed by the timeout.

## 2. Verified environment facts used by this plan

| Item | Verified value |
|---|---|
| Quickshell | 0.3.2, rev `9b0f339`, Fedora COPR |
| Hyprland | 0.57.1, exposes `ext_session_lock_v1` + `ext_idle_notifier_v1` |
| Lock types | `WlSessionLock { locked, secure, surface, unlock() }`, `WlSessionLockSurface { screen, width, height, color }` |
| Idle types | `IdleMonitor { enabled, timeout (seconds, real), respectInhibitors, isIdle }` |
| PAM | `PamContext { active, config, configDirectory, user, message, messageIsError, responseRequired, responseVisible }`, `start/abort/respond`, `completed/error`; only `auth` rules are used |
| PAM system | `authselect local + with-fingerprint`; `system-auth` has `pam_fprintd.so sufficient`, `password-auth` does not; `fprintd-list` → no devices; no `hyprlock` PAM service |
| logind | Session `Lock`/`Unlock` signals + manager `PrepareForSleep` present; `gdbus monitor --system --dest org.freedesktop.login1` works as the user |
| Brightness | `brightnessctl` → only `intel_backlight` (`card1-eDP-1`, max 26666); DDC on HDMI bus 11 fails |
| Click-through | `QsWindow.mask: Region { ... }` is the documented clickthrough mask (empty region ⇒ clicks pass through) |
| i18n tooling | `lrelease` exists at `/usr/lib64/qt6/bin/lrelease` (not on `PATH`); `lupdate` not found |
| hypridle | config file exists but binary/package absent and no process running |

## 3. Persistent configuration

### `config/ConfigStore.qml` — add properties + `updateProperties()` parsing

| Key | Type | Default | Meaning |
|---|---|---|---|
| `lockEnabled` | bool | `true` | Master feature switch; manual lock and lock surfaces allowed |
| `autoLockEnabled` | bool | `false` | Safety gate for **idle-driven** lock only |
| `dimTimeoutSec` | int | `300` | Idle seconds before dim |
| `lockTimeoutSec` | int | `900` | Idle seconds before auto-lock |
| `dpmsOffAfterLockSec` | int | `60` | Seconds after `lock.secure` before DPMS off; `0` disables |
| `dimOverlayOpacity` | real | `0.65` | Black overlay alpha, 0..1, with fade |
| `dimBacklightPercent` | int | `20` | `eDP-1` backlight target while dimmed |
| `respectIdleInhibitors` | bool | `true` | Forwarded to both `IdleMonitor.respectInhibitors` |
| `lockOnSuspend` | bool | `true` | Lock on `PrepareForSleep(true)` / logind session Lock |

Parsing follows the existing `if (data.key !== undefined) store.key = data.key;` style. `set`/`setMultiple`/`FileView` already persist to `~/.nibrasshell.json`, so no new storage mechanism is needed. Do **not** add a PAM service name as a user setting; the service file path is a fixed implementation constant.

### `config/App.qml` — add one `property alias` per key

`username` (already present) is the PAM user; fallback to the `USER` environment via `Quickshell.env("USER")` if `App.username` is empty/placeholder.

### Settings UI — `windows/settings/components/general/SystemPage.qml`

Add a `SectionCard` titled `qsTr("Lock Screen & Idle")` reusing `SettingSwitch` / `SliderWithLabel`: all nine switches/fields above, with `autoLockEnabled` visually marked as requiring a verified manual lock first. Extend `syncFromConfig()` and `serializeData()` only; `BaseGeneralSettings` handles the save/cancel flow.

## 4. Architecture

### New: `config/nibras-lock.pam`

```
auth required pam_unix.so
```

Password only; no fingerprint, no login-session PAM stack. `PamContext.config: "nibras-lock"`, `configDirectory` set relative to the QML file (Quickshell resolves it relative to the source file, so it can point at `config/` inside the repo).

### New: `services/LockService.qml` (`pragma Singleton`)

Single owner of state and shared objects:

- `state`: `awake | dimmed | locked`; derived `dimActive`, `locked`, `dpmsOff`.
- Two `IdleMonitor`s: `dimMonitor.timeout = App.dimTimeoutSec`, `lockMonitor.timeout = App.lockTimeoutSec`, both `respectInhibitors: App.respectIdleInhibitors`, `enabled: App.lockEnabled && !killSwitch`. Two protocol monitors are simpler and more reliable than one monitor plus a QML escalation timer.
- `WlSessionLock { id: lock; surface: <component from LockSurface.qml>; locked: <state === locked> }`. Never created while `NIBRAS_LOCK_DISABLE=1`.
- `PamContext` — **one instance only**, shared by all surfaces. `user: App.username || Quickshell.env("USER")`, `config`/`configDirectory` as above. Surfaces bind to `message`, `messageIsError`, `responseRequired`, `responseVisible`; input calls `LockService.pamRespond(text)`, `pamAbort()`, `pamStart()`.
- Shared input state: `pamBusy`, `failedAttempts`, `lastError`, `authScreenName` (see multi-monitor), reset on every `lock()`/`unlock()`.
- Backlight control: on entering dim, read `brightnessctl g` + `brightnessctl m` for `intel_backlight`, store percent, run `brightnessctl s <dimBacklightPercent>%`; restore the snapshot on activity, unlock, and wake. Use direct snapshot/restore, **not** `brightnessctl -s/-r` (hypridle's config uses that stack).
- `Process` for `hyprctl dispatch dpms off|on` and `brightnessctl` calls.
- `Process` running `gdbus monitor --system --dest org.freedesktop.login1` (read-only); parse `PrepareForSleep` boolean and only this session's `Lock`/`Unlock` signals. Session object path is `/org/freedesktop/login1/session/_<XDG_SESSION_ID>` (derive at runtime, do not hardcode `9`).
- `DPMS` timer: started when `lock.secure === true`; stopped/cleared on unlock, activity, resume. `dpms on` is issued immediately on wake/unlock/activity.
- Functions: `lock()`, `unlock()`, `pamStart()`, `pamRespond()`, `pamAbort()`, `testPam()` (test-gated), `onActivity()` (implicit through `isIdle` transitions + surface input).
- Guard: `Component.onDestruction` best-effort `lock.unlock()`; operator rule remains “no reload while locked”.

### New: `windows/lock/DimOverlay.qml`

Per-screen `PanelWindow` (`Variants { model: Quickshell.screens }` in `shell.qml`):

- Full anchors, `WlrLayershell.layer: WlrLayer.Overlay`, namespace `NibrasShell:dim`, `exclusionMode: Ignore`, `focusable: false`, `keyboardFocus: None`, `aboveWindows: true`.
- `color: Qt.rgba(0,0,0, App.dimOverlayOpacity)` with `Behavior on opacity` (~300ms ease) for smooth fade; `visible` follows `LockService.dimActive` but is set to false only after fade-out completes.
- `mask: Region { width: 0; height: 0 }` (or an equivalent empty region) so mouse/keyboard pass through to apps. This must be verified live before trusting the dim stage.
- Hidden entirely while locked; lock surfaces provide their own scrim, preventing double dimming.

### New: `windows/lock/LockSurface.qml`

The component assigned to `WlSessionLock.surface`; each instance creates a `WlSessionLockSurface` for one screen.

- Fills the surface with a dark scrim + reused `Wallpaper`/`MediaItem` (blurred/dimmed) for visual continuity with `Desktop.qml`; uses `ThemeManager.selectedTheme` colors/typography/dimensions.
- Uses the surface's `screen` property to decide its role.
- `LockContext`-style shared state lives in `LockService`, not in the surface. `LockService.authScreenName` is updated from `Hyprland.focusedMonitor.name` and from pointer entry on a lock surface; fallback order: focused monitor → `eDP-1` → `Quickshell.screens[0].name`.
- Primary surface: inline auth card bound to the single shared `PamContext` — prefilled username (editable), hidden password field when `!responseVisible`, visible prompt on failure, Enter/`respond()`, Abort/Unlock buttons, clear Arabic errors via `qsTr()`.
- Secondary surfaces: passive blurred wallpaper + `SystemClock` time/date + battery (`SystemService`) + short status text; no second `PamContext`, no password field. Clicking a secondary surface switches `authScreenName` to it, so the card follows the user.
- Never owns a lock/unlock timer; all transitions go through `LockService`.

### Modified: existing files

| File | Change |
|---|---|
| `config/ConfigStore.qml` | 9 properties + `updateProperties()` entries |
| `config/App.qml` | 9 aliases |
| `config/EventNames.js` | `REQUEST_LOCK`, `REQUEST_UNLOCK`, `LOCK_STATE_CHANGED`, maybe `PAM_TEST_RESULT` |
| `shell.qml` | Reference `LockService` (ensures singleton creation); add per-screen `DimOverlay` `Variants`; add `IpcHandler { target: "NibrasLock" }` with `lock()`, `unlock()`, `pamTest()`; `pamTest()` returns early unless test env is set |
| `windows/poweroption/PowerOptions.qml` | Fifth `PowerTile`: icon `\uf023`, label `qsTr("Lock")`, calls `LockService.lock()` directly (no confirmation step, no `prepareGoodbye`) |
| `windows/settings/components/general/SystemPage.qml` | Lock/idle SectionCard + sync/serialize |
| `translations/ar.ts` | New `<context>` entries for new strings; then regenerate `ar.qm` with `/usr/lib64/qt6/bin/lrelease translations/ar.ts -qm translations/ar.qm` |
| `windows/leftwindow/Menus.qml` / `binds.lua` | **No change** (no shortcuts) |

### Environment kill-switches (not persisted)

- `NIBRAS_LOCK_DISABLE=1`: no idle monitors, no `WlSessionLock`, no DPMS commands; manual PAM test still allowed. Use this to recover a broken build without touching config.
- `NIBRAS_LOCK_TEST=1`: exposes `quickshell ipc call NibrasLock pamTest` and verbose state logging; never enabled in the normal autostart environment.

## 5. State machine / edge cases

1. **Idle inhibitors:** with `respectIdleInhibitors: true`, fullscreen video/MPRIS inhibitors keep both monitors non-idle; dim/lock never start. Verify with a playing fullscreen video.
2. **Activity during dim:** either `IdleMonitor.isIdle` flips false or the dim overlay receives pointer/keyboard on the way through; cancel backlight timer, fade overlay out, then restore backlight. Order matters: restore backlight **before** hiding the overlay to avoid a bright flash.
3. **Manual brightness change while dimmed:** restoring the old snapshot can overwrite the user's new value. Track `Brightness.brightness` changes during dim and prefer the latest user value on restore if it changed.
4. **Lock while already locked:** `WlSessionLock` silently ignores a second lock; all `lock()` calls must be idempotent and must not reset `PamContext` mid-auth.
5. **PAM failure:** keep the card open, show `message` + `messageIsError`, clear the password field, rate-limit via `pam_faildelay` (already 2s in system auth), never unlock on `PamError`.
6. **PAM success:** `completed(PamResult.Success)` → stop DPMS timer, `brightnessctl` restore, `dpms on`, hide overlays, `lock.locked = false`, emit `LOCK_STATE_CHANGED`, reset shared auth state.
7. **Suspend/lid:** `PrepareForSleep(true)` → if `lockOnSuspend && lockEnabled`, engage lock immediately (do not wait for idle timers); `PrepareForSleep(false)` → `dpms on` + backlight restore. Session `Lock` signal engages lock even when `autoLockEnabled` is false (it is an explicit external request); `Unlock` only clears logind's hint, never bypasses PAM.
8. **DPMS off and input:** DPMS off must not leave the lock stuck; any input or wake signal brings DPMS back on. Do not issue `dpms off` before `lock.secure === true`.
9. **Monitor hotplug:** `WlSessionLock` creates surfaces for screens present at lock time; if a screen is plugged in while locked it gets a new surface. Re-evaluate `authScreenName` if the auth screen disappears.
10. **Focus ambiguity while locked:** Hyprland focus may stop updating under a session lock; rely on pointer-entry fallback rather than `Hyprland.focusedMonitor` alone.
11. **Double dim with hypridle:** today harmless (binary absent). If hypridle is ever installed, its 300s `brightnessctl -s` and 600s DPMS listeners will fight this service — document as a known operational conflict; config is not edited per decision.
12. **Fingerprint:** excluded by the custom PAM file; no `pam_fprintd` prompt, no suspend-related fingerprint hang.
13. **Shell crash while locked:** compositor keeps the lock (by design). TTY recovery below.

## 6. Phased implementation & verification

### Phase 0 — Probe (done)
Result in §1. No further action.

### Phase 1 — Config + settings only (no lock, no overlay)
Files: `ConfigStore.qml`, `App.qml`, `SystemPage.qml`, `EventNames.js`.
Verify: values appear in `~/.nibrasshell.json`; survive shell restart; `App.*` aliases resolve; settings Save/Cancel works; no new QML errors in `quickshell log`.

### Phase 2 — Dim only (`autoLockEnabled` stays false)
Files: `DimOverlay.qml`, `LockService.qml` (dim/backlight parts), `shell.qml` (Variants), `brightnessctl` calls.
Verify with short test timeouts in config: overlay fades in/out, is click-through (click an app underneath), backlight `eDP-1` drops to 20% and restores, `HDMI-A-1` untouched, fullscreen video inhibits dim, no lock surface ever appears.

### Phase 3 — PAM pre-test (no `WlSessionLock`)
Files: `config/nibras-lock.pam`, `PamContext` in `LockService`, `pamTest()` IPC.
Verify: `NIBRAS_LOCK_TEST=1 quickshell ipc call NibrasLock pamTest` → correct password succeeds, wrong password shows Arabic error, no fingerprint prompt, no session/suspend side effects, abort works.

### Phase 4 — Manual lock only
Files: `LockSurface.qml`, `WlSessionLock` wiring, `IpcHandler`, PowerOptions Lock tile.
Verify in this order:
1. `NIBRAS_LOCK_DISABLE=0` and `autoLockEnabled: false`; call `quickshell ipc call NibrasLock lock`.
2. Confirm `lock.secure === true`, primary card on focused screen, secondary passive, one `PamContext`.
3. Type password → unlock; confirm backlight/DPMS/overlay state restored.
4. Test with one monitor disabled, then both; test monitor unplug while locked.
5. **Intentionally kill Quickshell while locked and practice TTY recovery** before Phase 5.

### Phase 5 — Auto-lock, logind, DPMS
Files: `LockService` idle→lock wiring, gdbus monitor, DPMS timer.
Verify: idle at 900s locks only when `autoLockEnabled: true`; DPMS off at +60s and on at wake/activity/unlock; `loginctl lock-session` triggers our lock; `systemctl suspend` then resume locks/restores without racing; `loginctl unlock-session` does not bypass PAM.

### Phase 6 — i18n polish
Wrap all new user-facing strings in `qsTr()`, add contexts/messages to `translations/ar.ts`, recompile `translations/ar.qm` with `/usr/lib64/qt6/bin/lrelease`, verify Arabic rendering in overlay, auth card, settings section, and power tile.

## 7. Safety / recovery runbook

- Before any live lock test: confirm `NIBRAS_LOCK_DISABLE=1` can be set in the shell environment and that you can reach a TTY.
- Never hot-reload (`quickshell ipc ... reload` / config reload) while `WlSessionLock.locked === true`. Best-effort `unlock()` in `Component.onDestruction` is not a guarantee.
- If the display is stuck locked: `Ctrl+Alt+F3` → log in → `pkill -x quickshell` (killing the lock owner makes Hyprland drop the lock) → `Ctrl+Alt+F2` to return. Restart Quickshell from the Hyprland autostart path. Last resort: `loginctl terminate-session $XDG_SESSION_ID`.
- Keep `autoLockEnabled: false` until Phase 4 passes, including the deliberate crash/recovery drill.
- No keyboard shortcuts are added; the user wires their own after implementation.

## 8. Open risks

- `QsWindow.mask` click-through needs live confirmation; if it fails, the dim overlay blocks input and must be removed rather than worked around.
- External monitor cannot be hardware-dimmed (`ddcutil` DDC failure); overlay is the only uniform mechanism.
- If `hypridle` is installed later, its timers conflict with this pipeline; this plan deliberately does not edit its config.
- `ar.qm` regeneration requires `/usr/lib64/qt6/bin/lrelease` (not on `PATH`); no `lupdate` is installed, so new `.ts` entries are added manually.

Skipped: no source edits, no PAM/system/hypr config changes, no lock activation, no shortcut changes. Residual risk: `ext-session-lock-v1` will keep the display locked if Quickshell dies while locked, and DDC dimming on `HDMI-A-1` does not work on this machine.
