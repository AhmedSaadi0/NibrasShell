# matugen 3.1.0 Migration Plan — NibrasShell

Status: **implemented; live Quickshell verification pending**. This document records the discovery-backed implementation plan.

## Locked decisions

1. Target **matugen 3.1.0** only. Use verified flags: `image`, `-t/--type`, `-m/--mode`, `--contrast`, `-j hex`, `-q`, `--fallback-color`. Do not use v4-only flags such as `--lightness-dark` or `--source-color-index`.
2. Make `scripts/python/m3/` **stdlib-only**. Remove `kde_material_you_colors`, `materialyoucolor`, `numpy`, `pillow`, and `pywal` usage from that layer.
3. Keep `Kirigami.Theme` integration. Generated KDE `.colors` files remain the source of shell colors. Fix Hyprland border sync with a QML `Process` + completion callback.
4. Keep existing `0..8` scheme IDs in cache, mapped 1:1 to matugen scheme types. Replace Chroma/Tone with a single official `Contrast` slider.
5. Drop dormant AGS/pywal output. Drop KSyntax generation unless later proven minimal.

## Approval items before implementation

1. Use `--dry-run` in the runtime wrapper. It is verified on 3.1.0 and prevents user matugen configs from running templates/hooks or setting wallpaper. It was not in the original parenthetical allow-list.
2. Drop KSyntax generation. The current `.theme` files contain ~25 editor colors plus ~50 text styles; faithful stdlib generation is >30 lines.
3. Guard AI-generated Plasma schemes while dynamic coloring is enabled, so AI and matugen do not silently overwrite each other.
4. Accept stale `translations/ar.qm` for now: `lrelease`/`lrelease-qt6` are not installed. Update `ar.ts`; changed strings fall back to English until recompiled.

---

## 1. Verified matugen 3.1.0 output

### Version/help

```text
$ matugen --version
matugen 3.1.0
```

Relevant verified flags from `matugen --help` / `matugen image --help`:

```text
-t, --type <TYPE>            [scheme-content, scheme-expressive, scheme-fidelity,
                              scheme-fruit-salad, scheme-monochrome, scheme-neutral,
                              scheme-rainbow, scheme-tonal-spot, scheme-vibrant]
-m, --mode <MODE>            [light, dark]  default: dark
    --contrast <CONTRAST>    -1 .. 1
-q, --quiet
-j, --json <JSON>            [hex, rgb, rgba, hsl, hsla, strip]
    --dry-run                no templates / reload / wallpaper / commands
    --fallback-color <STRING>
```

`python3` is `/usr/bin/python3`, Python 3.15.0.

### JSON schema sample

Command:

```bash
matugen image assets/wallpapers/m3_dark.png -t scheme-fidelity -m dark -j hex --dry-run
```

Result: exit `0`, stdout is pure JSON, stderr empty. `-q` also keeps stdout as valid JSON.

```json
{
  "colors": {
    "primary": {
      "dark": "#9bd76b",
      "default": "#9bd76b",
      "light": "#346802"
    }
  },
  "image": "assets/wallpapers/m3_dark.png",
  "is_dark_mode": true,
  "mode": "dark",
  "palettes": {
    "primary": {
      "0": "#000000",
      "10": "#0c2000",
      "50": "#4e8522",
      "90": "#b6f484",
      "100": "#ffffff"
    }
  }
}
```

Verified shape:

- `colors`: 50 tokens; each has `dark`, `default`, `light`.
- `default` equals the active `mode`.
- `palettes`: `error`, `neutral`, `neutral_variant`, `primary`, `secondary`, `tertiary`.
- Each palette has tones `0,5,10,15,20,25,30,35,40,50,60,70,80,90,95,98,99,100`.

### Existing generated formats

KDE `.colors`:

- Sections: `[ColorEffects:Disabled]`, `[ColorEffects:Inactive]`, `[Colors:Button]`, `[Colors:Complementary]`, `[Colors:Header]`, `[Colors:Header][Inactive]`, `[Colors:Selection]`, `[Colors:Tooltip]`, `[Colors:View]`, `[Colors:Window]`, `[General]`, `[KDE]`, `[WM]`.
- Values: mostly `#RRGGBB`; `[WM]` alpha colors are `#AARRGGBB`; blend values are comma-separated RGB.
- Dark/light differences: inactive effect `Enable=true|false`, View `BackgroundNormal=surfaceDim|surfaceBright`, View `DecorationHover=inversePrimary|secondaryFixed`, names, blend constants, and inactive foreground token.

Konsole `.colorscheme`:

- Sections: `[Background]`, `[BackgroundFaint]`, `[BackgroundIntense]`, `[Color0..7]` plus matching `Faint`/`Intense`, `[Foreground*]`, `[General]`.
- Values: `R,G,B`; `Opacity=0.8`; `Description=MaterialYou|MaterialYouAlt`.
- Both current files end with a stray `ity=1` line; the new writer will not reproduce it.

---

## 2. Phased implementation plan

### Phase 1 — stdlib-only Python wrapper

**Modify** `scripts/python/m3/dynamic-m3.py`

- Keep `image_path` positional.
- Keep `-m/--mode dark|light`, default `dark`.
- Keep `-s/--scheme 0..8`, default `2`.
- Replace `-c/--chroma` and `-t/--tone` with `--contrast` (`float`, default `0.0`, validated `-1.0..1.0`).
- Add optional `--fallback-color <hex>`.
- Remove all external imports.

**Rewrite** `scripts/python/m3/plasma_color.py`

- Keep class name `ColorExporter`.
- Map scheme IDs:

| ID | matugen type |
|---:|---|
| 0 | `scheme-content` |
| 1 | `scheme-expressive` |
| 2 | `scheme-fidelity` |
| 3 | `scheme-monochrome` |
| 4 | `scheme-neutral` |
| 5 | `scheme-tonal-spot` |
| 6 | `scheme-vibrant` |
| 7 | `scheme-rainbow` |
| 8 | `scheme-fruit-salad` |

- Run:

```text
matugen -q image <path> -t <scheme-type> -m <mode>
  --contrast <value> -j hex --dry-run [--fallback-color <hex>]
```

- Parse JSON with `json.loads(stdout)` and validate `colors`, `mode`, `palettes`.
- Use `colors[token][mode]` as the active palette value.
- Write KDE `.colors` files with plain strings / `pathlib`.
- Apply Plasma with `subprocess.run([...])`, no `shell=True`.
- Write Konsole `.colorscheme` files.
- Stop writing `/tmp/kde-material-you-colors-*.json`, CSS, Kitty, pywal, and KSyntax files.

**KDE files written**

- `~/.local/share/color-schemes/MaterialYouDark.colors`
- `~/.local/share/color-schemes/MaterialYouDark2.colors`
- `~/.local/share/color-schemes/MaterialYouLight.colors`
- `~/.local/share/color-schemes/MaterialYouLight2.colors`

Stop writing `*_darker_titlebar*.colors`; they are legacy and not used by current variants.

**`.colors` token mapping**

| `.colors` area | Matugen token |
|---|---|
| Disabled `Color` | `surface_container` |
| Inactive `Color` | `surface_container_lowest`; `Enable=true` dark, `false` light |
| Button backgrounds | `surface_variant`, `surface_container_high` |
| Focus/hover/decoration | `primary` |
| Foreground active/normal | `on_surface` |
| Foreground inactive | `outline` |
| Link / Negative / Neutral / Positive / Visited | Legacy constants `#2980b9`, `#da4453`, `#f67400`, `#27ae60`, `#9b59b6` |
| Complementary / Header backgrounds | `surface`, `surface_container` |
| Header foreground active | `inverse_surface` |
| Header foreground normal | `on_surface_variant` |
| Selection background | `primary`; hover `secondary`; text `on_primary` |
| View background normal | `surface_dim` dark, `surface_bright` light |
| View decoration hover | `inverse_primary` dark, `secondary_fixed` light |
| Window background | `surface_variant` / `surface_container` |
| WM active background | `#ff` + stripped `surface_container_highest` |
| WM inactive background | `#ff` + stripped `secondary_container` |
| WM foregrounds | `on_surface`; dark inactive `on_secondary_container`, light inactive `on_surface_variant` |
| `General` | `ColorScheme=MaterialYouDark|Light`, `Name=Material You dark|Light`, `shadeSortColumn=true` |
| `KDE` | `contrast=4` |

**Plasma apply + hash**

1. `plasma-apply-colorscheme <target>2.colors` (`check=False`).
2. `plasma-apply-colorscheme <target>.colors` (`check=True`).
3. SHA-1 the applied `.colors`.
4. Update `[General] ColorSchemeHash` in `~/.config/kdeglobals` with `configparser` (`optionxform = str`, `space_around_delimiters=False`).

**Konsole files written**

- `~/.local/share/konsole/MaterialYou.colorscheme`
- `~/.local/share/konsole/MaterialYouAlt.colorscheme`

Mapping:

- `Background=surface`, `BackgroundIntense=surface_bright`, `BackgroundFaint=surface_dim`.
- `Foreground=on_surface`, `ForegroundIntense=inverse_surface`, `ForegroundFaint=on_surface_variant`.
- Base 8: `surface, primary, secondary, error, tertiary, inverse_primary, on_surface_variant, outline`.
- Intense 8: `surface_bright, primary_fixed, secondary_fixed, error, tertiary_fixed, primary_container, secondary_container, inverse_surface`.
- Faint 8: `surface_dim, primary_fixed_dim, secondary_fixed_dim, error_container, tertiary_fixed_dim, on_primary_fixed_variant, on_secondary_fixed_variant, on_surface_variant`.
- Convert `#RRGGBB` → `R,G,B`; `Opacity=0.8`, `Blur=false`, `Description=MaterialYou|MaterialYouAlt`.

**Delete**

- `scripts/python/m3/css_theme.py`
- `scripts/python/m3/kitty_theme.py`

**Modify** `scripts/python/requirements-3.13.txt`

- Remove `kde-material-you-colors==2.0.0`.
- Keep `pillow` and `rembg`; other scripts still use them.

**Create** `scripts/python/tests/test_m3_matugen_wrapper.py`

- `unittest` + `tempfile`; mock `subprocess.run` with fixture JSON.
- Assert scheme mapping, allowed argv, contrast validation, `.colors` sections/keys, Konsole 24 colors, hash update, and no stray `ity=`.

---

### Phase 2 — QML command/config surface

**Modify** `config/App.qml`

- Add `readonly property var stdlibPython: ["python3"]`.
- Change only `dynamicM3Command` to `["python3", dynamicM3]`.
- Keep global `pythonPath` for AI/monitoring scripts.

**Modify** `utils/Helper.qml` (`applyM3PlasmaColor`, ~223–236)

- New destructuring: `{ selectedWallpaperPath, themeMode, scheme, contrast }`.
- New argv:

```text
[...dynamicM3Command, path, "-m", mode, "--scheme", String(scheme), "--contrast", String(contrast)]
```

- Remove all `chroma`/`tone` handling.

**Modify** `themes/BaseTheme.qml`

- Replace `_dynamicColoringChromaMult` and `_dynamicColoringToneMult` with `_dynamicColoringContrast: 0.0`.
- Update `systemSettings` aliases.

**Modify** `themes/modules/ThemeSerializer.qml`

- `_wallKeys`: remove the two legacy multipliers, add `_dynamicColoringContrast`.
- Legacy keys are already ignored safely because `applyData()` only sets `themeInstance.hasOwnProperty(key)`. No extra compatibility branch needed.

**Modify** `windows/settings/components/appearance/WallpaperSettings.qml`

- Replace `localChromaMult`/`localToneMult` with `localContrast: 0.0`.
- `syncFromTheme()` reads `_dynamicColoringContrast ?? 0.0`.
- `serializeData()` writes `_dynamicColoringContrast`.
- Replace the two sliders with one `SliderWithLabel`: `from: -1.0`, `to: 1.0`, `stepSize: 0.05`, `decimals: 2`, label `Contrast`.
- Change dependency text to require `matugen`.

**Modify** `translations/ar.ts`

- Update `<source>` strings for the new dependency text and `Contrast` label/description.
- Leave `ar.qm` unchanged this round.

---

### Phase 3 — Process, completion callback, Hyprland/Konsole sync

**Modify** `themes/modules/SystemBridge.qml`

- Add:
  - `signal m3Applied()`
  - `signal m3Failed(string reason)`
  - `property var _pendingM3Command: null`
  - `property string _m3KonsoleProfile: ""`
  - `property string _m3Stderr: ""`
- Change `applyM3(...)` signature to include `contrast` and `konsoleProfile`.
- Replace `_dispatch("Apply M3", ...)` with a QML `Process`:
  - `stdout: StdioCollector` logs trimmed output.
  - `stderr: StdioCollector` stores trimmed error.
  - `onExited: (exitCode, exitStatus)` emits `m3Applied()` on code `0`, else `m3Failed(reason)`.
  - If a newer request arrives while running, store it in `_pendingM3Command` and start it on exit.
- On success, dispatch:

```text
scripts/python/apply_konsole_profile_open_sessions.py --profile <stripped profile>
```

- In `applySystemTheme()`, keep `DefaultProfile` kwriteconfig, but skip the immediate running-session Konsole dispatch when `settings.enableDynamicColoring` is true.

**Modify** `themes/ThemeManager.qml`

- Add public signals `m3Applied()` and `m3Failed(string reason)`.
- Update wallpaper trigger:

```js
bridgeSystem.applyM3(path, settings.themeMode, true,
                     settings.dynamicColoringSchemeVariant,
                     settings.dynamicColoringContrast,
                     settings.konsoleProfile);
```

- Connect:

```qml
SystemBridge {
    id: bridgeSystem
    onM3Applied: Qt.callLater(() => {
        if (selectedTheme)
            bridgeHyprland.applyConfig(selectedTheme.hyprlandConfiguration);
        root.m3Applied();
    })
    onM3Failed: reason => {
        console.error("[ThemeManager] M3 failed:", reason);
        root.m3Failed(reason);
    }
}
```

`Qt.callLater` gives Kirigami a tick to settle before Hyprland borders are recalculated.

**Modify** `themes/modules/AiThemeAssistant.qml`

- In `applyChanges()` (~214–240), if `ThemeManager.selectedTheme.systemSettings.enableDynamicColoring`:
  - do not write `NibrasShellAiGenerated-*`
  - do not set `_plasmaColorScheme`
  - surface a message that AI scheme switching is unavailable while Material You is active.
- Keep existing behavior unchanged for static themes.

---

### Phase 4 — Verification assets

- Create `scripts/python/tests/test_m3_matugen_wrapper.py` as described above.
- Do not clean generated files in code. Stale `MaterialYou*_darker_titlebar*.colors`, `/tmp/kde-material-you-colors-*.json`, and KSyntax `.theme` files are left alone; migration simply stops writing them.

---

## 3. Verification and test plan

### Unit tests

Run with stdlib `unittest`. Mock `subprocess.run` with fixture JSON.

Assert:

- Exact `0..8` → `scheme-*` mapping.
- Argv contains only allowed flags: `image`, `-t`, `-m`, `--contrast`, `-j hex`, `-q`, `--dry-run`, optional `--fallback-color`.
- Invalid contrast outside `-1..1` exits nonzero.
- Both dark and light `.colors` texts contain required sections and `ColorScheme=MaterialYouDark|Light`.
- `MaterialYou` and `MaterialYouAlt` colorschemes have 24 colors, `R,G,B` values, `Opacity=0.8`, and no `ity=1`.
- `kdeglobals` rewrite changes only `ColorSchemeHash`.
- Legacy chroma/tone keys are not written to new caches.

### Live Quickshell checklist

1. Switch to `M3Dark`; confirm missing `kde-material-you-colors` causes no error.
2. Confirm log shows one `matugen ... --dry-run -j hex` invocation and clean exit.
3. Confirm `Kirigami.Theme.highlightColor` changes and shell colors follow.
4. Confirm `kdeglobals ColorSchemeHash` equals SHA-1 of applied `MaterialYouDark.colors`.
5. Switch to `M3Light`; verify `MaterialYouLight.colors` applied and `MaterialYouLight2.colors` exists.
6. Next/previous wallpaper: exactly one process run per change; no overlapping writers.
7. Change Contrast slider: one rerun, reflected in Plasma/Kirigami and Hyprland borders after `m3Applied`.
8. Konsole running sessions update via `apply_konsole_profile_open_sessions.py`; profile stays `MaterialYouAlt.profile`.
9. Settings dropdown still lists `MaterialYouDark`, `MaterialYouLight`, `MaterialYouAlt`.
10. AI palette assistant on a dynamic theme shows the guard message; on a static theme it still creates `NibrasShellAiGenerated-*`.
11. Confirm no `/tmp/kde-material-you-colors-*.json`, AGS SCSS, Kitty conf, or pywal files are written.
