# Direct Matugen Palette Integration for Quickshell

## Goal

Stop relying on live `Kirigami.Theme` refreshes for dynamic Material 3 theming. After each successful `dynamic-m3.py` run, consume the exact Matugen palette over stdout and apply it directly to the active Quickshell theme in memory.

## Constraints

- Do not change `shell.qml` or switch Qt Quick style.
- Keep Kirigami bindings in `BaseTheme.qml`, `M3Dark.qml`, and `M3Light.qml` as initial fallbacks only.
- Do not write generated Matugen colors into `~/.cache/nibrasshell/themes/*.json`.
- Do not create external palette JSON files.
- Do not call `reloadTheme()` from palette completion.
- Keep Plasma `.colors` and Konsole `.colorscheme` generation unchanged.
- Never emit normal logs or palette payloads to stderr.

## Files to change

- `scripts/python/m3/plasma_color.py`
- `scripts/python/m3/dynamic-m3.py`
- `scripts/python/tests/test_m3_matugen_wrapper.py`
- `themes/modules/SystemBridge.qml`
- `themes/modules/ThemeSerializer.qml`
- `themes/ThemeManager.qml`
- `themes/modules/WallpaperController.qml`

## 1. Python palette contract

### Mapping

Add `QML_COLOR_TOKENS` to `plasma_color.py`. Every color key in `ThemeSerializer._colorKeys`, except metadata `themeName`, must be mapped from `colors[token][self.theme_mode]["color"]`.

| QML key | Matugen token |
| --- | --- |
| `_primary` | `primary` |
| `_onPrimary` | `on_primary` |
| `_secondary` | `secondary` |
| `_onSecondary` | `on_secondary` |
| `_tertiary` | `tertiary` |
| `_onTertiary` | `on_tertiary` |
| `_error` | `error` |
| `_onError` | `on_error` |
| `_surface` | `surface` |
| `_onSurface` | `on_surface` |
| `_surfaceDim` | `surface_dim` |
| `_surfaceBright` | `surface_bright` |
| `_surfaceContainerLowest` | `surface_container_lowest` |
| `_surfaceContainerLow` | `surface_container_low` |
| `_surfaceContainer` | `surface_container` |
| `_surfaceContainerHigh` | `surface_container_high` |
| `_surfaceContainerHighest` | `surface_container_highest` |
| `_surfaceVariant` | `surface_variant` |
| `_onSurfaceVariant` | `on_surface_variant` |
| `_primaryContainer` | `primary_container` |
| `_onPrimaryContainer` | `on_primary_container` |
| `_secondaryContainer` | `secondary_container` |
| `_onSecondaryContainer` | `on_secondary_container` |
| `_tertiaryContainer` | `tertiary_container` |
| `_onTertiaryContainer` | `on_tertiary_container` |
| `_errorContainer` | `error_container` |
| `_onErrorContainer` | `on_error_container` |
| `_outline` | `outline` |
| `_outlineVariant` | `outline_variant` |
| `_inverseSurface` | `inverse_surface` |
| `_onInverseSurface` | `inverse_on_surface` |
| `_inversePrimary` | `inverse_primary` |
| `_shadow` | `shadow` |
| `_scrim` | `scrim` |

Values are normalized to canonical `#RRGGBB`. Raw Matugen tokens are applied directly; fallback-only alpha calculations are not preserved.

### API and output

`ColorExporter.apply()` returns:

```python
(digest, {"mode": self.theme_mode, "colors": mapped_palette})
```

`dynamic-m3.py` keeps its existing stdout logs and then emits exactly one compact line:

```text
__M3_PALETTE__:{"mode":"light","colors":{"_primary":"#...",...}}
```

Handled failures emit a compact `__M3_ERROR__:{...}` line to stdout and exit non-zero. SystemBridge must use the exit code as the primary failure signal.

## 2. SystemBridge request state machine

Replace the positional M3 call with a request object containing wallpaper, mode, scheme, contrast, Konsole profile, and theme name.

Add:

```qml
signal m3Applied(var palette, var meta)
signal m3Failed(string reason, var meta)

function applyM3(request)
function invalidateM3Requests()
function _startM3Request(command, meta)
function _tryFinishM3()
function _parseM3Output(output, request)
```

Track:

- Monotonic request ID.
- Active request metadata.
- Newest pending request metadata and command.
- Per-run stdout/stderr buffers.
- Per-run stream-finished flags.
- Exit code/status.

A newer queued request replaces an older queued request. Konsole profile is stored per request, never globally.

Completion waits for stdout, stderr, and process exit. Quickshell 0.3.2 calls `StdioCollector.streamEnded()` even for empty streams, but add a deferred fallback that reads collector text after exit so a missing empty-stream callback cannot deadlock completion.

On success:

1. Verify exactly one `__M3_PALETTE__:` line.
2. Parse the envelope.
3. Verify `envelope.mode === request.themeMode`.
4. Verify `envelope.colors` is an object.
5. Emit `m3Applied(envelope.colors, request)`.

On failure:

1. Parse `__M3_ERROR__:` from stdout when present.
2. Otherwise use stderr or the exit status.
3. Emit `m3Failed(reason, request)`.

Stale request IDs are suppressed before any palette, Konsole refresh, or success/failure signal is emitted.

## 3. ThemeSerializer changes

Keep skipping `_colorKeys` during dynamic cache hydration and additionally skip `_hyprActiveBorder`. It is the only color-derived `_hypr*` property.

When saving a dynamic theme cache, omit generated color keys and `_hyprActiveBorder` so settings-page Save cannot persist Matugen colors.

Add:

```qml
function applyM3Palette(themeInstance, palette)
```

It validates all 34 required keys and canonical hex values before applying any mutation, then assigns them directly in memory. It never calls `saveToCache()`.

## 4. ThemeManager changes

Track the newest submitted M3 request ID. Invalidate outstanding M3 work when loading or applying a theme.

Pass full metadata to `SystemBridge.applyM3()` and store the returned request ID.

Add `_isCurrentM3Result(meta)` to verify:

- Theme still exists.
- Dynamic coloring remains enabled.
- Request ID is newest in both ThemeManager and SystemBridge.
- Theme name and mode match.
- Current wallpaper matches.
- Scheme and Konsole profile match.
- Contrast matches using `Math.abs(...) < 1e-6`.

On a current result:

1. Apply the flat palette through `ThemeSerializer.applyM3Palette()`.
2. Re-apply Hyprland configuration.
3. Emit `selectedThemeUpdated()` and `m3Applied()`.

Never call `_applyToSystem()`, `saveToCache()`, or `reloadTheme()` from this path.

## 5. Plasma race fix

In `SystemBridge.applySystemTheme()`, skip `changePlasmaColor()` when dynamic coloring is enabled. The Matugen process is then the only writer of the active Plasma color scheme, preventing races when `_themeMode` changes.

Keep Konsole default-profile behavior and the existing running-session guard.

## 6. Wallpaper duplicate-run fix

In `WallpaperController._updateIndexAndApply()`, replace:

```qml
Theme.ThemeManager.updateAndApplyTheme({
    "_selectedWallpaperIndex": root._currentIndex
}, true)
```

with:

```qml
Theme.ThemeManager.updateThemePropertyOnly({
    "_selectedWallpaperIndex": root._currentIndex
}, true)
```

`wallpaperReady(path)` has already started the M3 request. Reapplying the whole theme would invalidate that request and start a duplicate Matugen run.

## 7. Settings-page behavior

`ColorsSettings` already refreshes through `BaseThemeSettings.onSelectedThemeUpdated`, which calls `syncFromTheme()`. Emitting `selectedThemeUpdated()` after palette application updates open editors.

Dynamic cache hydration prevents stale local color values from being written back. The dynamic `saveToCache()` omission prevents Save from persisting generated colors.

No functional changes are required in `ColorsSettings.qml` or `BaseThemeSettings.qml`.

## 8. Tests

Update existing tests for the new `apply()` return value and the current Konsole opacity (`0.9`).

Add tests for:

- Complete 34-key token mapping.
- `_onInverseSurface -> inverse_on_surface`.
- Requested dark/light mode selection.
- Canonical hex normalization.
- Missing token failure.
- Exactly one stdout palette line.
- Empty stderr on success.
- `__M3_ERROR__:` failure output without a palette line.

Run:

```bash
python3 -m unittest discover -s scripts/python/tests -p 'test_m3_matugen_wrapper.py'
```

## 9. Verification checklist

- M3Dark and M3Light both update Quickshell without restart.
- Wallpaper, scheme, contrast, and mode changes update all QML colors.
- Hyprland active border follows the new primary/secondary/tertiary colors.
- Rapid dark → light → wallpaper queue applies only the newest palette.
- Theme switch or disabling dynamic coloring mid-run suppresses stale results.
- No duplicate Matugen process per wallpaper change.
- No reload/apply loop in `qs log`.
- Plasma and Konsole still update.
- Generated colors are not written to theme cache files.
- Open Colors Settings refreshes without stale overwrite.
- QML loads without syntax or runtime errors.
