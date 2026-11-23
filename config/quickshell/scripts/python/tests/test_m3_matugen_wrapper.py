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


def fake_payload(modes=("dark", "light"), with_palettes=True):
    colors = {}
    for index, token in enumerate(plasma_color.COLOR_TOKENS):
        value = f"#{index + 1:06x}"
        light = f"#{index + 64:06x}"
        token_data = {"default": {"color": value}}
        if "dark" in modes:
            token_data["dark"] = {"color": value}
        if "light" in modes:
            token_data["light"] = {"color": light}
        colors[token] = token_data
    payload = {
        "colors": colors,
        "image": "wallpaper.png",
        "is_dark_mode": True,
        "mode": "dark",
    }
    if with_palettes:
        payload["palettes"] = {"primary": {"0": "#000000", "100": "#ffffff"}}
    return payload


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
            self.assertNotIn("--dry-run", matugen_command)
            self.assertNotIn("--old-json-output", matugen_command)
            self.assertNotIn("-c", matugen_command)
            self.assertNotIn("--chroma", matugen_command)
            self.assertNotIn("--tone", matugen_command)

            schemes = base / ".local/share/color-schemes"
            dark = (schemes / "MaterialYouDark.colors").read_text(encoding="utf-8")
            light = (schemes / "MaterialYouLight.colors").read_text(encoding="utf-8")
            for name in ("MaterialYouDark2.colors", "MaterialYouLight2.colors"):
                self.assertFalse((schemes / name).exists())
            self.assertIn("ColorScheme=MaterialYouDark", dark)
            self.assertIn("ColorScheme=MaterialYouLight", light)
            self.assertIn("[Colors:Window]", dark)
            self.assertIn("Enable=true", dark)
            self.assertIn("Enable=false", light)
            self.assertEqual(digest, hashlib.sha1(dark.encode("utf-8")).hexdigest())

            konsole_dir = base / ".local/share/konsole"
            name = "MaterialYou"
            text = (konsole_dir / f"{name}.colorscheme").read_text(encoding="utf-8")
            color_sections = sum(
                1 for line in text.splitlines() if line.startswith("[Color")
            )
            self.assertEqual(color_sections, 24)
            self.assertIn(f"Description={name}", text)
            self.assertIn("Opacity=0.8", text)
            self.assertNotIn("\nity=", text)
            self.assertFalse((konsole_dir / "MaterialYouAlt.colorscheme").exists())

            kdeglobals = base / ".config/kdeglobals"
            self.assertFalse(kdeglobals.exists())

            kwrite_calls = [call for call in calls if call[0] == "kwriteconfig6"]
            self.assertEqual(len(kwrite_calls), 3)
            for call in kwrite_calls:
                self.assertEqual(call[call.index("--file") + 1], str(kdeglobals))
                self.assertEqual(call[call.index("--group") + 1], "General")
            self.assertIn("AccentColor", kwrite_calls[0])
            self.assertIn("transparent", kwrite_calls[0])
            self.assertIn("accentColorFromWallpaper", kwrite_calls[1])
            self.assertIn("false", kwrite_calls[1])
            hash_call = kwrite_calls[2]
            self.assertEqual(
                hash_call[hash_call.index("--key") + 1 :], ["ColorSchemeHash", digest]
            )

            apply_calls = [call for call in calls if call[0] == "plasma-apply-colorscheme"]
            self.assertEqual(len(apply_calls), 2)
            self.assertLess(calls.index(kwrite_calls[0]), calls.index(apply_calls[0]))
            self.assertTrue(apply_calls[0][1].endswith("MaterialYouDark2.colors"))
            self.assertTrue(apply_calls[1][1].endswith("MaterialYouDark.colors"))

    def test_single_mode_without_palettes(self):
        calls = []

        def runner(command, **kwargs):
            calls.append(command)
            if command[0] == "matugen":
                payload = fake_payload(modes=("light",), with_palettes=False)
                return Completed(stdout=json.dumps(payload))
            return Completed()

        with tempfile.TemporaryDirectory() as home:
            plasma_color.ColorExporter(
                "wallpaper.png", "light", 2, 0.0, home=home, runner=runner
            ).apply()
            schemes = Path(home) / ".local/share/color-schemes"
            self.assertTrue((schemes / "MaterialYouLight.colors").exists())
            self.assertFalse((schemes / "MaterialYouDark.colors").exists())
            for name in ("MaterialYouDark2.colors", "MaterialYouLight2.colors"):
                self.assertFalse((schemes / name).exists())

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
