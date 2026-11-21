import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "m3"))
import plasma_color  # noqa: E402


class Completed:
    def __init__(self, stdout="", stderr="", returncode=0):
        self.stdout = stdout
        self.stderr = stderr
        self.returncode = returncode


def fake_payload():
    colors = {}
    for index, token in enumerate(plasma_color.COLOR_TOKENS):
        value = f"#{index + 1:06x}"
        light = f"#{index + 64:06x}"
        colors[token] = {"dark": value, "default": value, "light": light}
    return {
        "colors": colors,
        "image": "wallpaper.png",
        "is_dark_mode": True,
        "mode": "dark",
        "palettes": {"primary": {"0": "#000000", "100": "#ffffff"}},
    }


class MatugenWrapperTest(unittest.TestCase):
    def test_scheme_mapping(self):
        self.assertEqual(plasma_color.SCHEME_TYPES[0], "scheme-content")
        self.assertEqual(plasma_color.SCHEME_TYPES[2], "scheme-fidelity")
        self.assertEqual(plasma_color.SCHEME_TYPES[5], "scheme-tonal-spot")
        self.assertEqual(plasma_color.SCHEME_TYPES[8], "scheme-fruit-salad")

    def test_invalid_contrast(self):
        with self.assertRaises(ValueError):
            plasma_color.ColorExporter("x.png", "dark", 2, 1.5)

    def test_outputs_and_commands(self):
        calls = []

        def runner(command, **kwargs):
            calls.append(command)
            if command[0] == "matugen":
                return Completed(stdout=json.dumps(fake_payload()))
            return Completed()

        with tempfile.TemporaryDirectory() as home:
            exporter = plasma_color.ColorExporter(
                "wallpaper.png", "dark", 2, 0.25, home=home, runner=runner
            )
            digest = exporter.apply()
            base = Path(home)

            matugen_command = calls[0]
            self.assertEqual(matugen_command[0], "matugen")
            self.assertEqual(matugen_command[1:4], ["-q", "image", "wallpaper.png"])
            self.assertIn("-t", matugen_command)
            self.assertEqual(matugen_command[matugen_command.index("-t") + 1], "scheme-fidelity")
            self.assertIn("-m", matugen_command)
            self.assertEqual(matugen_command[matugen_command.index("-m") + 1], "dark")
            self.assertEqual(matugen_command[matugen_command.index("--contrast") + 1], "0.25")
            self.assertEqual(matugen_command[matugen_command.index("-j") + 1], "hex")
            self.assertIn("--dry-run", matugen_command)
            self.assertNotIn("-c", matugen_command)
            self.assertNotIn("--chroma", matugen_command)
            self.assertNotIn("--tone", matugen_command)

            schemes = base / ".local/share/color-schemes"
            dark = (schemes / "MaterialYouDark.colors").read_text(encoding="utf-8")
            dark2 = (schemes / "MaterialYouDark2.colors").read_text(encoding="utf-8")
            light = (schemes / "MaterialYouLight.colors").read_text(encoding="utf-8")
            self.assertTrue((schemes / "MaterialYouLight2.colors").exists())
            self.assertEqual(dark, dark2)
            self.assertIn("ColorScheme=MaterialYouDark", dark)
            self.assertIn("ColorScheme=MaterialYouLight", light)
            self.assertIn("[Colors:Window]", dark)
            self.assertIn("Enable=true", dark)
            self.assertIn("Enable=false", light)
            self.assertEqual(digest, hashlib.sha1(dark.encode("utf-8")).hexdigest())

            konsole_dir = base / ".local/share/konsole"
            for name in ("MaterialYou", "MaterialYouAlt"):
                text = (konsole_dir / f"{name}.colorscheme").read_text(encoding="utf-8")
                color_sections = sum(
                    1 for line in text.splitlines() if line.startswith("[Color")
                )
                self.assertEqual(color_sections, 24)
                self.assertIn(f"Description={name}", text)
                self.assertIn("Opacity=0.8", text)
                self.assertNotIn("\nity=", text)

            kdeglobals = (base / ".config/kdeglobals").read_text(encoding="utf-8")
            self.assertIn(f"ColorSchemeHash={digest}", kdeglobals)

            apply_calls = [call for call in calls if call[0] == "plasma-apply-colorscheme"]
            self.assertEqual(len(apply_calls), 2)
            self.assertTrue(apply_calls[0][1].endswith("MaterialYouDark2.colors"))
            self.assertTrue(apply_calls[1][1].endswith("MaterialYouDark.colors"))

    def test_fallback_color_is_passed(self):
        calls = []

        def runner(command, **kwargs):
            calls.append(command)
            if command[0] == "matugen":
                return Completed(stdout=json.dumps(fake_payload()))
            return Completed()

        with tempfile.TemporaryDirectory() as home:
            plasma_color.ColorExporter(
                "wallpaper.png",
                "light",
                0,
                -0.5,
                fallback_color="#ff0000",
                home=home,
                runner=runner,
            ).apply()
            self.assertEqual(calls[0][-2:], ["--fallback-color", "#ff0000"])


if __name__ == "__main__":
    unittest.main()
