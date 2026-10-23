import QtQuick
import Quickshell
import "root:/config"

QtObject {
    id: root

    function _evalLua(luaCode) {
        if (!luaCode || luaCode.trim() === "")
            return;
        console.info("[HyprlandBridge] [Lua Eval Batch] ->\n" + luaCode);
        Quickshell.execDetached(["hyprctl", "eval", luaCode]);
    }

    function _execCmd(cmdArray) {
        if (!Array.isArray(cmdArray) || cmdArray.length === 0)
            return;
        console.info("[HyprlandBridge] [Exec] -> " + cmdArray.join(" "));
        Quickshell.execDetached(["sh", "-c", cmdArray.join(" ")]);
    }

    function _cleanStr(val) {
        if (!val)
            return "";
        let s = String(val).trim();
        if ((s.startsWith("'") && s.endsWith("'")) || (s.startsWith('"') && s.endsWith('"'))) {
            s = s.substring(1, s.length - 1);
        }
        return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    }

    function _gapsToLua(val) {
        if (val === undefined || val === null)
            return "0";
        if (typeof val === "number")
            return val.toString();

        let str = String(val).replace(/['"]/g, "").trim();
        let parts = str.split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n));

        if (parts.length === 4) {
            return `{ top = ${parts[0]}, right = ${parts[1]}, bottom = ${parts[2]}, left = ${parts[3]} }`;
        } else if (parts.length === 1) {
            return parts[0].toString();
        } else if (parts.length > 0) {
            return `{ top = ${parts[0]}, right = ${parts[1] || parts[0]}, bottom = ${parts[2] || parts[0]}, left = ${parts[3] || parts[1] || parts[0]} }`;
        }
        return "0";
    }

    function _formatVec2ToLua(value) {
        if (value === undefined || value === null)
            return "{0, 0}";

        if (typeof value === "string") {
            let parts = value.replace(/['"]/g, "").split(',').map(s => parseFloat(s.trim())).filter(n => !isNaN(n));
            if (parts.length >= 2)
                return `{${parts[0]}, ${parts[1]}}`;
            return "{0, 0}";
        }

        if (value.x !== undefined && value.y !== undefined) {
            return `{${Number(value.x)}, ${Number(value.y)}}`;
        }
        return "{0, 0}";
    }

    function _parseBezierToLua(bezierStr) {
        if (!bezierStr)
            return [];
        let lines = String(bezierStr).split('\n').map(l => l.replace(/['"]/g, "").trim()).filter(l => l.length > 0);
        let results = [];
        for (let line of lines) {
            let parts = line.split(',').map(s => s.trim());
            if (parts.length >= 5) {
                let name = parts[0];
                let x0 = parseFloat(parts[1]);
                let y0 = parseFloat(parts[2]);
                let x1 = parseFloat(parts[3]);
                let y1 = parseFloat(parts[4]);
                if (!isNaN(x0) && !isNaN(y0) && !isNaN(x1) && !isNaN(y1)) {
                    results.push(`hl.curve("${name}", { type = "bezier", points = {{${x0}, ${y0}}, {${x1}, ${y1}}} })`);
                }
            }
        }
        return results;
    }

    // QML color object / {r,g,b,a} (0..1) -> "rgba(RRGGBBAA)". Strings pass through.
    function _colorToRgba(val) {
        if (val === undefined || val === null)
            return null;
        if (typeof val === "string") {
            let s = val.trim();
            return s === "" ? null : s;
        }
        if (typeof val === "object" && val.r !== undefined) {
            const toHex = n => Math.round(Math.max(0, Math.min(1, Number(n))) * 255).toString(16).padStart(2, "0");
            const a = (val.a === undefined) ? 1 : Number(val.a);
            return `rgba(${toHex(val.r)}${toHex(val.g)}${toHex(val.b)}${toHex(isNaN(a) ? 1 : a)})`;
        }
        return null;
    }

    // "rgba(a) rgba(b) 45deg" -> '{ colors = {"rgba(a)", "rgba(b)"}, angle = 45 }'
    // single color (string or color object) -> '"..."'
    function _borderToLua(val) {
        let s = _colorToRgba(val);
        if (!s)
            return '"rgba(50505088)"';
        // strip wrapping quotes if a quoted string slipped through
        if ((s.startsWith("'") && s.endsWith("'")) || (s.startsWith('"') && s.endsWith('"')))
            s = s.substring(1, s.length - 1);
        const tokens = s.split(/\s+/).filter(t => t.length > 0);
        if (tokens.length <= 1)
            return `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
        let angle = 45;
        let colors = tokens.slice();
        const m = tokens[tokens.length - 1].match(/^(\d+(?:\.\d+)?)deg$/);
        if (m) {
            angle = Number(m[1]);
            colors = tokens.slice(0, -1);
        }
        if (colors.length <= 1)
            return `"${colors[0].replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
        return `{ colors = {${colors.map(c => `"${c.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`).join(", ")}}, angle = ${angle} }`;
    }

    function _parseAnimationToLua(name, animValue) {
        if (!animValue)
            return null;
        let cleanVal = String(animValue).replace(/['"]/g, "").trim();
        let parts = cleanVal.split(',').map(s => s.trim());
        if (parts.length >= 3) {
            let enabled = (parts[0] === "1" || parts[0] === "true" || parts[0] === "yes");
            let speed = parseFloat(parts[1]) || 1;
            let curve = parts[2] || "default";
            let style = parts.slice(3).join(', ').trim();
            let styleAttr = style ? `, style = "${style}"` : "";
            // NOTE: the key MUST be `bezier` — Hyprland rejects `curve`
            // ("bezier or spring is required").
            return `hl.animation({ leaf = "${name}", enabled = ${enabled}, speed = ${speed}, bezier = "${curve}"${styleAttr} })`;
        }
        return null;
    }

    function applyConfig(hyprConfig) {
        if (!hyprConfig)
            return;

        console.info("[HyprlandBridge] Applying configuration and animations to Hyprland...");

        // 1. General Settings (quickshell theme values are canonical —
        // always include gaps_out; runtime hl.config MERGES sections)
        let generalFields = [];
        if (hyprConfig.gapsIn !== undefined)
            generalFields.push(`gaps_in = ${Number(hyprConfig.gapsIn)}`);
        if (hyprConfig.gapsOut !== undefined)
            generalFields.push(`gaps_out = ${_gapsToLua(hyprConfig.gapsOut)}`);
        if (hyprConfig.borderWidth !== undefined)
            generalFields.push(`border_size = ${Number(hyprConfig.borderWidth)}`);
        // NOTE: nested `col` table is required — flat ["col.x"] keys reject
        // gradients ("invalid color"), and gradients need colors/angle tables.
        let colFields = [];
        if (hyprConfig.activeBorder)
            colFields.push(`active_border = ${_borderToLua(hyprConfig.activeBorder)}`);
        if (hyprConfig.inactiveBorder)
            colFields.push(`inactive_border = ${_borderToLua(hyprConfig.inactiveBorder)}`);
        if (colFields.length > 0)
            generalFields.push(`col = { ${colFields.join(", ")} }`);
        if (hyprConfig.layout)
            generalFields.push(`layout = "${_cleanStr(hyprConfig.layout)}"`);

        // 2. Decoration Settings
        let decorFields = [];
        if (hyprConfig.rounding !== undefined)
            decorFields.push(`rounding = ${Number(hyprConfig.rounding)}`);
        if (hyprConfig.dimInactive !== undefined)
            decorFields.push(`dim_inactive = ${hyprConfig.dimInactive ? "true" : "false"}`);
        if (hyprConfig.dimStrength !== undefined)
            decorFields.push(`dim_strength = ${Number(hyprConfig.dimStrength)}`);

        // Shadows
        let shadowFields = [];
        if (hyprConfig.dropShadow !== undefined) {
            let shadowEnabled = (hyprConfig.dropShadow === true || hyprConfig.dropShadow === "yes" || hyprConfig.dropShadow === 1);
            shadowFields.push(`enabled = ${shadowEnabled ? "true" : "false"}`);
        }
        if (hyprConfig.shadowRange !== undefined)
            shadowFields.push(`range = ${Number(hyprConfig.shadowRange)}`);
        if (hyprConfig.shadowColor) {
            let sc = _colorToRgba(hyprConfig.shadowColor);
            if (sc)
                shadowFields.push(`color = "${_cleanStr(sc)}"`);
        }
        if (hyprConfig.shadowOffset !== undefined)
            shadowFields.push(`offset = ${_formatVec2ToLua(hyprConfig.shadowOffset)}`);
        if (shadowFields.length > 0)
            decorFields.push(`shadow = { ${shadowFields.join(", ")} }`);

        // Blur
        let blurFields = [];
        if (hyprConfig.blurEnabled !== undefined)
            blurFields.push(`enabled = ${hyprConfig.blurEnabled ? "true" : "false"}`);
        if (hyprConfig.blurSize !== undefined)
            blurFields.push(`size = ${Number(hyprConfig.blurSize)}`);
        if (hyprConfig.blurPasses !== undefined)
            blurFields.push(`passes = ${Number(hyprConfig.blurPasses)}`);
        if (blurFields.length > 0)
            decorFields.push(`blur = { ${blurFields.join(", ")} }`);

        // Animations Toggle
        let animFields = [];
        if (hyprConfig.animationsEnabled !== undefined)
            animFields.push(`enabled = ${hyprConfig.animationsEnabled ? "true" : "false"}`);

        let configSections = [];
        if (generalFields.length > 0)
            configSections.push(`general = { ${generalFields.join(", ")} }`);
        if (decorFields.length > 0)
            configSections.push(`decoration = { ${decorFields.join(", ")} }`);
        if (animFields.length > 0)
            configSections.push(`animations = { ${animFields.join(", ")} }`);

        // Config first, as its own eval (merge semantics: partial sections safe).
        if (configSections.length > 0) {
            _evalLua(`hl.config({ ${configSections.join(", ")} })`);
        }

        // 3. Curves first — each as its own eval so one bad line can't abort
        // later statements (a Lua runtime error stops the rest of the string).
        let definedCurves = {};
        if (hyprConfig.bezier) {
            let curves = _parseBezierToLua(hyprConfig.bezier);
            for (let curveLua of curves) {
                const m = curveLua.match(/^hl\.curve\("([^"]+)"/);
                if (m)
                    definedCurves[m[1]] = true;
                _evalLua(curveLua);
            }
        }

        // 4. تطبيق الحركات بعد تعريف المنحنيات مباشرة (Animations)
        const animationEntries = [
            {
                name: "windowsMove",
                value: hyprConfig.animWindowsMove
            },
            {
                name: "windows",
                value: hyprConfig.animWindows
            },
            {
                name: "windowsIn",
                value: hyprConfig.animWindowsIn
            },
            {
                name: "windowsOut",
                value: hyprConfig.animWindowsOut
            },
            {
                name: "border",
                value: hyprConfig.animBorder
            },
            {
                name: "borderangle",
                value: hyprConfig.animBorderAngle
            },
            {
                name: "fadeIn",
                value: hyprConfig.animFadeIn
            },
            {
                name: "fadeOut",
                value: hyprConfig.animFadeOut
            },
            {
                name: "workspaces",
                value: hyprConfig.animWorkspaces
            }
        ];

        for (const entry of animationEntries) {
            if (entry.value) {
                let animLua = _parseAnimationToLua(entry.name, entry.value);
                if (animLua) {
                    // A leaf referencing an undefined curve errors ("no such
                    // bezier") — define it as linear fallback so the leaf still
                    // applies instead of failing. "default" is built-in.
                    const cm = animLua.match(/bezier = "([^"]+)"/);
                    if (cm && cm[1] !== "default" && !definedCurves[cm[1]]) {
                        console.warn(`[HyprlandBridge] curve "${cm[1]}" referenced by "${entry.name}" is not defined by the theme — using linear fallback.`);
                        _evalLua(`hl.curve("${cm[1]}", { type = "bezier", points = {{0, 0}, {1, 1}} })`);
                        definedCurves[cm[1]] = true;
                    }
                    _evalLua(animLua);
                }
            }
        }

        // 5. تطبيق مؤشر الماوس
        if (hyprConfig.cursorTheme) {
            const cursorSize = hyprConfig.cursorSize || 24;
            _execCmd(["hyprctl", "setcursor", _cleanStr(hyprConfig.cursorTheme), String(cursorSize)]);
        }
    }

    function addLeftMenuSpacing(hyprConfig, dimensions) {
        if (!hyprConfig || !dimensions)
            return;

        let gapsStr = hyprConfig.gapsOut;
        let menuWidth = dimensions.menuWidth + (hyprConfig.gapsIn * 2);
        let gapsArray = String(gapsStr).replace(/['"]/g, "").split(',').map(val => parseInt(val.trim()));

        if (gapsArray.length === 4) {
            let top = gapsArray[0];
            let right = gapsArray[1];
            let bottom = gapsArray[2];
            let left = gapsArray[3];

            let newLeftGap = left + menuWidth - 5;
            let lua = `hl.config({ general = { gaps_out = { top = ${top}, right = ${right}, bottom = ${bottom}, left = ${newLeftGap} } } })`;
            _evalLua(lua);
        }
    }

    function resetLeftMenuSpacing(hyprConfig) {
        if (!hyprConfig || hyprConfig.gapsOut === undefined)
            return;
        let lua = `hl.config({ general = { gaps_out = ${_gapsToLua(hyprConfig.gapsOut)} } })`;
        _evalLua(lua);
    }
}
