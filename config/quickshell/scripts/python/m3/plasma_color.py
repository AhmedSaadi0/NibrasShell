"""Stdlib-only KDE/Konsole theme writer driven by matugen JSON output."""

from __future__ import annotations

import hashlib
import json
import subprocess
from collections.abc import Callable
from pathlib import Path
from typing import Any

SCHEME_TYPES: tuple[str, ...] = (
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-tonal-spot",
    "scheme-vibrant",
    "scheme-rainbow",
    "scheme-fruit-salad",
)

# Breeze-derived text-state colors used by the old package. They are stable
# and avoid inventing semantic colors matugen does not emit.
EXTRA_COLORS: dict[str, str] = {
    "link": "#2980b9",
    "negative": "#da4453",
    "neutral": "#f67400",
    "positive": "#27ae60",
    "visited": "#9b59b6",
}

COLOR_TOKENS: tuple[str, ...] = (
    "background",
    "error",
    "error_container",
    "inverse_on_surface",
    "inverse_primary",
    "inverse_surface",
    "on_background",
    "on_error",
    "on_error_container",
    "on_primary",
    "on_primary_container",
    "on_primary_fixed",
    "on_primary_fixed_variant",
    "on_secondary",
    "on_secondary_container",
    "on_secondary_fixed",
    "on_secondary_fixed_variant",
    "on_surface",
    "on_surface_variant",
    "on_tertiary",
    "on_tertiary_container",
    "on_tertiary_fixed",
    "on_tertiary_fixed_variant",
    "outline",
    "outline_variant",
    "primary",
    "primary_container",
    "primary_fixed",
    "primary_fixed_dim",
    "scrim",
    "secondary",
    "secondary_container",
    "secondary_fixed",
    "secondary_fixed_dim",
    "shadow",
    "source_color",
    "surface",
    "surface_bright",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "surface_container_low",
    "surface_container_lowest",
    "surface_dim",
    "surface_tint",
    "surface_variant",
    "tertiary",
    "tertiary_container",
    "tertiary_fixed",
    "tertiary_fixed_dim",
)

KONSOLE_SCHEMES: tuple[str, ...] = ("MaterialYou",)


class ColorExporter:
    """Generate and apply Plasma/Konsole colors from matugen -j hex output."""

    def __init__(
        self,
        wallpaper_path: str | Path,
        theme_mode: str,
        scheme_variant: int,
        contrast: float,
        fallback_color: str | None = None,
        home: str | Path | None = None,
        runner: Callable[..., Any] = subprocess.run,
    ) -> None:
        if not wallpaper_path:
            raise ValueError("wallpaper_path must not be empty")
        if theme_mode not in ("dark", "light"):
            raise ValueError(f"invalid theme mode: {theme_mode}")
        if not 0 <= scheme_variant < len(SCHEME_TYPES):
            raise ValueError(f"invalid scheme variant: {scheme_variant}")
        if not -1.0 <= contrast <= 1.0:
            raise ValueError(f"contrast must be between -1 and 1: {contrast}")

        self.wallpaper_path = Path(wallpaper_path)
        self.theme_mode = theme_mode
        self.scheme_variant = scheme_variant
        self.contrast = contrast
        self.fallback_color = fallback_color
        self.home = Path(home).expanduser() if home else Path.home()
        self.runner = runner
        self._plasma_contents: dict[str, str] = {}

    def apply(self) -> str:
        payload = self._matugen_json()
        self._write_plasma(payload)
        self._write_konsole(payload)
        return self._apply_plasma()

    def _run(self, command: list[str], *, check: bool = True) -> Any:
        return self.runner(
            command, capture_output=True, text=True, check=check
        )

    def _matugen_json(self) -> dict[str, Any]:
        command = [
            "matugen",
            "-q",
            "image",
            str(self.wallpaper_path),
            "-t",
            SCHEME_TYPES[self.scheme_variant],
            "-m",
            self.theme_mode,
            "--contrast",
            f"{self.contrast:.2f}",
            "-j",
            "hex",
        ]
        if self.fallback_color:
            command += ["--fallback-color", self.fallback_color]

        result = self._run(command, check=True)
        data = json.loads(result.stdout)
        if not isinstance(data, dict):
            raise ValueError("matugen JSON root must be an object")

        colors = data.get("colors")
        if not isinstance(colors, dict):
            raise ValueError("matugen JSON missing 'colors' object")

        for token in COLOR_TOKENS:
            token_data = colors.get(token)
            if not isinstance(token_data, dict):
                raise ValueError(f"matugen JSON missing colors.{token}")
            mode_data = token_data.get(self.theme_mode)
            if not isinstance(mode_data, dict) or "color" not in mode_data:
                raise ValueError(
                    f"matugen JSON missing colors.{token}.{self.theme_mode}.color"
                )

        return data

    @staticmethod
    def _has_mode(data: dict[str, Any], mode: str) -> bool:
        colors = data["colors"]
        return all(
            isinstance(colors[token].get(mode), dict)
            and "color" in colors[token][mode]
            for token in COLOR_TOKENS
        )

    @staticmethod
    def _c(data: dict[str, Any], token: str, mode: str) -> str:
        return str(data["colors"][token][mode]["color"])

    @staticmethod
    def _normalize_hex(hex_color: str) -> str:
        raw = hex_color.strip().lstrip("#")
        if len(raw) == 3:
            raw = "".join(ch * 2 for ch in raw)
        if len(raw) != 6:
            raise ValueError(f"invalid hex color: {hex_color}")
        int(raw, 16)
        return raw

    @classmethod
    def _alpha(cls, hex_color: str) -> str:
        return f"#ff{cls._normalize_hex(hex_color)}"

    @classmethod
    def _rgb(cls, hex_color: str) -> str:
        raw = cls._normalize_hex(hex_color)
        return ",".join(str(int(raw[i : i + 2], 16)) for i in (0, 2, 4))

    def _render_kde_scheme(self, data: dict[str, Any], mode: str) -> str:
        def c(token: str) -> str:
            return self._c(data, token, mode)

        dark = mode == "dark"
        scheme_name = "MaterialYouDark" if dark else "MaterialYouLight"
        display_name = "Material You dark" if dark else "Material You Light"
        inactive_enable = "true" if dark else "false"
        view_bg = c("surface_dim") if dark else c("surface_bright")
        view_hover = c("inverse_primary") if dark else c("secondary_fixed")
        active_blend = "252,252,252" if dark else "227,229,231"
        inactive_blend = "161,169,177" if dark else "239,240,241"
        inactive_fg = (
            c("on_secondary_container") if dark else c("on_surface_variant")
        )

        link = EXTRA_COLORS["link"]
        negative = EXTRA_COLORS["negative"]
        neutral = EXTRA_COLORS["neutral"]
        positive = EXTRA_COLORS["positive"]
        visited = EXTRA_COLORS["visited"]

        return f"""[ColorEffects:Disabled]
Color={c('surface_container')}
ColorAmount=0.5
ColorEffect=3
ContrastAmount=0
ContrastEffect=0
IntensityAmount=0
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color={c('surface_container_lowest')}
ColorAmount=0.025
ColorEffect=0
ContrastAmount=0.1
ContrastEffect=0
Enable={inactive_enable}
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate={c('surface_variant')}
BackgroundNormal={c('surface_container_high')}
DecorationFocus={c('primary')}
DecorationHover={c('primary')}
ForegroundActive={c('on_surface')}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_surface')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:Complementary]
BackgroundAlternate={c('surface')}
BackgroundNormal={c('surface_container')}
DecorationFocus={c('primary')}
DecorationHover={c('primary')}
ForegroundActive={c('inverse_surface')}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_surface_variant')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:Header]
BackgroundAlternate={c('surface_container')}
BackgroundNormal={c('surface_container')}
DecorationFocus={c('primary')}
DecorationHover={c('primary')}
ForegroundActive={c('inverse_surface')}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_surface_variant')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:Header][Inactive]
BackgroundAlternate={c('surface_container')}
BackgroundNormal={c('surface_container')}
DecorationFocus={c('primary')}
DecorationHover={c('primary')}
ForegroundActive={c('inverse_surface')}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_surface_variant')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:Selection]
BackgroundAlternate={c('primary')}
BackgroundNormal={c('primary')}
DecorationFocus={c('primary')}
DecorationHover={c('secondary')}
ForegroundActive={c('on_primary')}
ForegroundInactive={c('on_primary')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_primary')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:Tooltip]
BackgroundAlternate={c('surface_variant')}
BackgroundNormal={c('surface_container')}
DecorationFocus={c('primary')}
DecorationHover={c('primary')}
ForegroundActive={c('on_surface')}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_surface')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:View]
BackgroundAlternate={c('surface_container')}
BackgroundNormal={view_bg}
DecorationFocus={c('primary')}
#-----------------------------------------------
DecorationHover={view_hover}
ForegroundActive={c('inverse_surface')}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
ForegroundNormal={c('on_surface')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[Colors:Window]
BackgroundAlternate={c('surface_variant')}
BackgroundNormal={c('surface_container')}
DecorationFocus={c('primary')}
DecorationHover={c('primary')}
ForegroundActive={link}
ForegroundInactive={c('outline')}
ForegroundLink={link}
ForegroundNegative={negative}
ForegroundNeutral={neutral}
#--- Window titles, context icons
ForegroundNormal={c('on_surface_variant')}
ForegroundPositive={positive}
ForegroundVisited={visited}

[General]
ColorScheme={scheme_name}
Name={display_name}
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={self._alpha(c('surface_container_highest'))}
activeBlend={active_blend}
activeForeground={c('on_surface')}
inactiveBackground={self._alpha(c('secondary_container'))}
inactiveBlend={inactive_blend}
inactiveForeground={inactive_fg}
"""

    def _scheme_path(self, mode: str) -> Path:
        name = "MaterialYouDark" if mode == "dark" else "MaterialYouLight"
        return self.home / ".local/share/color-schemes" / f"{name}.colors"

    def _write_plasma(self, data: dict[str, Any]) -> None:
        self._plasma_contents.clear()
        schemes_dir = self.home / ".local/share/color-schemes"
        schemes_dir.mkdir(parents=True, exist_ok=True)

        for mode in ("dark", "light"):
            if not self._has_mode(data, mode):
                continue
            content = self._render_kde_scheme(data, mode)
            self._plasma_contents[mode] = content
            self._scheme_path(mode).write_text(content, encoding="utf-8")

    def _apply_plasma(self) -> str:
        target_scheme = self._scheme_path(self.theme_mode)
        temp_scheme = target_scheme.with_name(
            f"{target_scheme.stem}2{target_scheme.suffix}"
        )
        kdeglobals = self.home / ".config/kdeglobals"
        kdeglobals.parent.mkdir(parents=True, exist_ok=True)

        # Force Plasma's accent source back to "From current color scheme".
        for args in (
            [
                "kwriteconfig6",
                "--file",
                str(kdeglobals),
                "--group",
                "General",
                "--key",
                "AccentColor",
                "transparent",
            ],
            [
                "kwriteconfig6",
                "--file",
                str(kdeglobals),
                "--group",
                "General",
                "--key",
                "accentColorFromWallpaper",
                "--type",
                "bool",
                "false",
            ],
        ):
            self._run(args, check=False)

        content = self._plasma_contents[self.theme_mode]
        temp_scheme.write_text(content, encoding="utf-8")
        try:
            self._run(
                ["plasma-apply-colorscheme", str(temp_scheme)], check=False
            )
            self._run(
                ["plasma-apply-colorscheme", str(target_scheme)], check=True
            )
        finally:
            temp_scheme.unlink(missing_ok=True)

        digest = hashlib.sha1(content.encode("utf-8")).hexdigest()
        self._run(
            [
                "kwriteconfig6",
                "--file",
                str(kdeglobals),
                "--group",
                "General",
                "--key",
                "ColorSchemeHash",
                digest,
            ],
            check=True,
        )
        return digest

    def _write_konsole(self, data: dict[str, Any]) -> None:
        def c(token: str) -> str:
            return self._c(data, token, self.theme_mode)

        konsole_dir = self.home / ".local/share/konsole"
        konsole_dir.mkdir(parents=True, exist_ok=True)

        base = (
            c("surface"),
            c("primary"),
            c("secondary"),
            c("error"),
            c("tertiary"),
            c("inverse_primary"),
            c("on_surface_variant"),
            c("outline"),
        )
        intense = (
            c("surface_bright"),
            c("primary_fixed"),
            c("secondary_fixed"),
            c("error"),
            c("tertiary_fixed"),
            c("primary_container"),
            c("secondary_container"),
            c("inverse_surface"),
        )
        faint = (
            c("surface_dim"),
            c("primary_fixed_dim"),
            c("secondary_fixed_dim"),
            c("error_container"),
            c("tertiary_fixed_dim"),
            c("on_primary_fixed_variant"),
            c("on_secondary_fixed_variant"),
            c("on_surface_variant"),
        )

        def color_section(name: str, value: str) -> str:
            return f"[{name}]\nColor={self._rgb(value)}"

        parts = [
            color_section("Background", c("surface")),
            color_section("BackgroundFaint", c("surface_dim")),
            color_section("BackgroundIntense", c("surface_bright")),
        ]
        for i in range(8):
            parts.append(color_section(f"Color{i}", base[i]))
            parts.append(color_section(f"Color{i}Faint", faint[i]))
            parts.append(color_section(f"Color{i}Intense", intense[i]))
        parts += [
            color_section("Foreground", c("on_surface")),
            color_section("ForegroundFaint", c("on_surface_variant")),
            color_section("ForegroundIntense", c("inverse_surface")),
        ]

        for description in KONSOLE_SCHEMES:
            general = (
                "[General]\n"
                "Anchor=0.5,0.5\n"
                "Blur=false\n"
                "ColorRandomization=false\n"
                f"Description={description}\n"
                "FillStyle=Tile\n"
                "Opacity=0.8\n"
                "Wallpaper=\n"
                "WallpaperFlipType=NoFlip\n"
                "WallpaperOpacity=1"
            )
            text = "\n\n".join(parts + [general]) + "\n"
            (konsole_dir / f"{description}.colorscheme").write_text(
                text, encoding="utf-8"
            )
