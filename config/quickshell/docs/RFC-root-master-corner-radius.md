# RFC: Root-Master Corner Radius

**Status:** Implemented (2026-10-28)  
**Scope:** `windows/settings/components/appearance/BaseThemeSettings.qml`, `windows/settings/components/appearance/LayoutFontSettings.qml`  
**Schema changes:** None  
**Risk:** Low; rollback is limited to reverting the two settings files

**Implementation files:**

- `windows/settings/components/appearance/BaseThemeSettings.qml` — batch `applyProperties()`, no-op filtering, dependency ordering, safe `applySingleProperty()` wrapper, Reset guard.
- `windows/settings/components/appearance/LayoutFontSettings.qml` — master radius state, sanitizers, live preview, hydrated/serialized radius keys, master slider, M3 `None`/`Medium` controls, `PreviewBox` binding.

## 1. Problem

`LayoutFontSettings.qml` exposes `_elementRadius` but not `_baseRadius`, `_shapeMedium`, or
`_shapeNone`. `BaseTheme.qml` declares:

```qml
property int _baseRadius: 12
property int _elementRadius: root._baseRadius
property int _shapeMedium: root._baseRadius
```

A JavaScript theme write such as `themeInstance[key] = value` removes the target binding
permanently for that theme instance. Theme variants also replace the inherited bindings with
static values. The result is a mixed graph:

- `M3Dark`: base, element, and medium remain bound.
- `DraculaLight`: base, element, and medium are independent constants.
- `CatppuccinLight`: element is static, medium is bound.
- `PreviewBox` reads `dimensions.baseRadius`, so it does not track the element slider.

## 2. Decision

Implement a value-level **Root-Master** model:

- The master "Corner Radius" control writes `_baseRadius`, `_elementRadius`, and `_shapeMedium`
  together in one `ThemeManager.updateAndApplyTheme()` transaction.
- The write order is `_baseRadius` first, then `_elementRadius`, `_shapeMedium`, then `_shapeNone`.
- Live bindings cascade from the base write; dependent entries are then skipped because their
  values are already equal. Static dependents are written explicitly.
- This does not restore the QML binding DAG. It provides deterministic synchronization on top
  of a DAG that is already broken by variant overrides and legacy cache entries.

### Signal budget

| Graph shape | Theme writes | Notify signals | `_applyToSystem` | `selectedThemeUpdated` |
|---|---:|---:|---:|---:|
| All three bound | 1 (`_baseRadius`) | 3 | 1 | 1 |
| Element/medium static | 3 | 3 | 1 | 1 |
| All values already equal | 0 | 0 | 0 | 0 |

`applyData()` writes keys in insertion order and skips equal values. QML has no multi-property
transaction; per-property notify signals remain. The batch guarantees one manager transaction,
one system apply, one `selectedThemeUpdated`, and one page refresh.

## 3. `BaseThemeSettings.qml`

Add:

```qml
readonly property var _radiusMutationOrder: [
    "_baseRadius",
    "_elementRadius",
    "_shapeMedium",
    "_shapeNone"
]
```

Replace `collectAndApply()`, `applySingleProperty()`, and `resetToDefault()` with the batch-aware
versions. `applyProperties(propertiesMap, saveToDisk = false)`:

1. Rejects null/invalid maps, unknown theme keys, nullish values, and non-finite numbers.
2. Removes unchanged values to avoid no-op transactions.
3. Pins `_elementRadius`/`_shapeMedium` when `_baseRadius` changes, so a base cascade cannot
   overwrite an intentional dependent value.
4. Reorders radius keys to `_baseRadius` → `_elementRadius` → `_shapeMedium` → `_shapeNone`.
5. Calls `ThemeManager.updateAndApplyTheme()` once.
6. Emits `saveChanges()` only when `saveToDisk === true`.
7. Allows an explicit no-op Save to call `updateAndApplyTheme({}, true)` so the full cache
   snapshot is still written.

`applySingleProperty()` becomes a thin wrapper over `applyProperties()`.
`collectAndApply()` routes the page's `serializeData()` through `applyProperties()`.
`resetToDefault()` guards against null themes and hydration in progress.

## 4. `LayoutFontSettings.qml`

### State

```qml
property int localBaseRadius: 12
property int localElementRadius: 12
property int localShapeMedium: 12
property int localShapeNone: 0

readonly property int radiusSafeMax: 40
readonly property int shapeNoneSafeMax: 8
readonly property bool radiusMasterIsUniform: localBaseRadius === localElementRadius
        && localBaseRadius === localShapeMedium
```

### Helpers

- `sanitizeRadius(value, fallback, maxValue)`: rejects null/undefined/boolean/object, converts
  numeric strings, clamps to `0..maxValue`, and rounds to an integer.
- `previewRadiusMaster(value)`: updates local base/element/medium while dragging; no theme write.
- `applyRadiusMaster(value)`: sanitizes, updates locals, and writes all three keys in one batch.
- `previewShapeMedium()` / `applyShapeMedium()`: only `_shapeMedium`.
- `previewShapeNone()` / `applyShapeNone()`: only `_shapeNone`.

### Hydration

`syncFromTheme()` reads:

```qml
localBaseRadius = sanitizeRadius(theme._baseRadius, 12, radiusSafeMax);
localElementRadius = sanitizeRadius(theme._elementRadius, localBaseRadius, radiusSafeMax);
localShapeMedium = sanitizeRadius(theme._shapeMedium, localBaseRadius, radiusSafeMax);
localShapeNone = sanitizeRadius(theme._shapeNone, 0, shapeNoneSafeMax);
```

All existing font, spacing, shape, and component assignments remain.

### Persistence and Reset

`serializeData()` adds the four keys, with the root first:

```qml
"_baseRadius": localBaseRadius,
"_elementRadius": localElementRadius,
"_shapeMedium": localShapeMedium,
"_shapeNone": localShapeNone,
```

`saveToCache()` already persists all `_dimKeys`, so no serializer change is needed. Adding the
keys to `serializeData()` is what allows Reset to remove them from the cache via
`ThemeManager.loadDefaultValues()`.

## 5. UI

### Master control

Replace the old "Element Radius" slider with a full-width "Corner Radius (Master)" slider:

- Range `0..40`, step `1`, decimals `0`.
- `onCurrentValueChanged` updates local values for live preview.
- `onEditingFinished` commits one batch.
- Two captions show `Base | Element | Medium` and a warning when the theme has mixed tokens.

### Secondary M3 tokens

Add `None` and `Medium` to the existing M3 Shape Scale card:

- `None`: `0..8`, independent override; M3 expects `0`.
- `Medium`: `0..40`; writes only `_shapeMedium`.
- A "Use master" button sets medium back to the current base and is disabled when already equal.
- Master change always re-unifies medium. A medium override intentionally deviates until the
  next master move or "Use master".

### Preview

`PreviewBox` now uses:

```qml
property int effectiveRadius: root.localElementRadius
radius: Math.max(0, Math.round(effectiveRadius / 1.5))

Behavior on radius {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
}
```

The preview updates during dragging via the local properties, not from the stale
`dimensions.baseRadius`.

## 6. Edge Cases

| Situation | Result |
|---|---|
| Theme variant hardcodes element/medium | Master writes all three; values unify. |
| Theme variant inherits bindings | Base write cascades; dependent writes are skipped; bindings remain. |
| Legacy cache has mixed values | UI shows mixed warning; first master move unifies. |
| Reset | Four keys removed from cache; reload restores variant defaults and bindings. |
| Cache lacks the keys | `removedCount === 0`; no reload; theme already at defaults. |
| `NaN` / `Infinity` / `undefined` | Radius fallback or key skipped; no corrupt write. |
| Float slider output | Rounded to integer; sliders also use step `1`. |
| No-op Apply | No `ThemeManager` call; no system re-apply. |
| No-op Save | Full cache snapshot is still written. |
| Theme switch during drag | New theme hydrates; release commits the final value to the new theme. |

## 7. Verification

1. `M3Dark`: master `14 → 20`; all three become `20`; preview animates; save/reload keeps
   element/medium bindings live.
2. `DraculaLight`: master `12 → 20`; all three become `20`; save/reload keeps all three at `20`.
3. Medium override: only `_shapeMedium` changes; "Use master" restores it.
4. `None` override: only `_shapeNone` changes.
5. Reset: cache no longer contains the four keys; variant defaults return.
6. Switch `RosePineDark → M3Dark → DraculaLight`: locals re-sync without theme writes.
7. Invalid values: fallback/clamp with warning; theme unchanged.
8. No-op master click on a uniform theme: no transaction.
9. No-op Save: cache file still contains the full snapshot.

**Runtime verification (2026-10-28):** a temporary Quickshell harness instantiated this page and
exercised the real `ThemeManager` path:

- First master apply `12 → 20`: `ThemeSerializer` processed 3 keys but updated only
  `_baseRadius`; element and medium cascaded through their live bindings. Final values
  `20 / 20 / 20`.
- Medium override `20 → 7`: only `_shapeMedium` updated. Final `20 / 20 / 7`.
- None override `0 → 3`: only `_shapeNone` updated. Final `20 / 20 / 7 / 3`.
- Second master apply `20 → 21`: two properties updated (`_baseRadius` plus the now-static
  `_shapeMedium`); element cascaded. Final `21 / 21 / 21 / 3`.

This confirms root-first ordering, dependent pinning, and the expected signal budget.

## 8. Rollout

1. Patch `BaseThemeSettings.qml`.
2. Patch `LayoutFontSettings.qml`.
3. Run QML syntax checks / reload the shell.
4. Verify the matrix above.
5. Keep the cache format unchanged; rollback is a two-file revert.
