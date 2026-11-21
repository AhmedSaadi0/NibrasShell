#!/usr/bin/env python3
"""CLI wrapper: matugen JSON -> KDE Plasma / Konsole colors."""

import argparse
import sys

from plasma_color import ColorExporter


def main():
    parser = argparse.ArgumentParser(
        description="Generate KDE Plasma theme colors from a wallpaper using matugen."
    )
    parser.add_argument(
        "image_path",
        type=str,
        help="Absolute path to the input wallpaper image.",
    )
    parser.add_argument(
        "-m",
        "--mode",
        type=str,
        choices=["dark", "light"],
        default="dark",
        help="Theme mode: 'dark' or 'light' (default: dark).",
    )
    parser.add_argument(
        "-s",
        "--scheme",
        dest="scheme_variant",
        type=int,
        default=2,
        choices=range(9),
        help="Scheme ID: 0=Content, 1=Expressive, 2=Fidelity, 3=Monochrome, "
             "4=Neutral, 5=TonalSpot, 6=Vibrant, 7=Rainbow, 8=FruitSalad.",
    )
    parser.add_argument(
        "--contrast",
        type=float,
        default=0.0,
        help="matugen contrast, -1.0 (min) to 1.0 (max), default 0.0.",
    )
    parser.add_argument(
        "--fallback-color",
        dest="fallback_color",
        type=str,
        default=None,
        help="Fallback seed color passed to matugen if extraction fails.",
    )

    args = parser.parse_args()

    if not -1.0 <= args.contrast <= 1.0:
        parser.error("--contrast must be between -1.0 and 1.0")

    print(f"[*] Processing: {args.image_path}")
    print(
        f"[*] Params: Scheme={args.scheme_variant}, Contrast={args.contrast}, "
        f"Mode={args.mode}"
    )

    try:
        ColorExporter(
            wallpaper_data=args.image_path,
            theme_mode=args.mode,
            scheme_variant=args.scheme_variant,
            contrast=args.contrast,
            fallback_color=args.fallback_color,
        ).apply()
        print("[+] Plasma colors applied successfully.")
    except Exception as e:
        print(f"[!] Error applying colors: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
