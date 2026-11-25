import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "m3"))
import plasma_color  # noqa: E402

_dynamic_spec = importlib.util.spec_from_file_location(
    "dynamic_m3", Path(__file__).resolve().parents[1] / "m3" / "dynamic-m3.py"
)
dynamic_m3 = importlib.util.module_from_spec(_dynamic_spec)
_dynamic_spec.loader.exec_module(dynamic_m3)


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

    def test_quickshell_palette_mapping_is_complete(self):
        payload = fake_payload()
        exporter = plasma_color.ColorExporter("wallpaper.png", "light", 2, 0.0)
        palette = exporter._quickshell_palette(payload)

        self.assertEqual(len(plasma_color.QML_COLOR_TOKENS), 34)
        self.assertEqual(set(palette), set(plasma_color.QML_COLOR_TOKENS))
        self.assertTrue(
            set(plasma_color.QML_COLOR_TOKENS.values()).issubset(plasma_color.COLOR_TOKENS)
        )
        self.assertEqual(
            plasma_color.QML_COLOR_TOKENS["_onInverseSurface"], "inverse_on_surface"
        )

        for qml_key, token in plasma_color.QML_COLOR_TOKENS.items():
            expected_index = plasma_color.COLOR_TOKENS.index(token) + 64
            self.assertEqual(palette[qml_key], f"#{expected_index:06x}")

    def test_quickshell_palette_normalizes_short_hex(self):
        payload = fake_payload(modes=("light",))
        payload["colors"]["primary"]["light"]["color"] = "#abc"
        exporter = plasma_color.ColorExporter("wallpaper.png", "light", 2, 0.0)

        self.assertEqual(exporter._quickshell_palette(payload)["_primary"], "#aabbcc")

    def test_missing_matugen_token_fails(self):
        payload = fake_payload()
        del payload["colors"]["primary"]

        def runner(command, **kwargs):
            return Completed(stdout=json.dumps(payload))

        exporter = plasma_color.ColorExporter(
            "wallpaper.png", "dark", 2, 0.0, runner=runner
        )
        with self.assertRaisesRegex(ValueError, "missing colors.primary"):
            exporter._matugen_json()

    def test_dynamic_m3_emits_one_stdout_palette_line(self):
        envelope = {
            "mode": "light",
            "colors": {"_primary": "#123456"},
        }

        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "wallpaper.png"
            image.write_bytes(b"image")
            stdout = StringIO()
            stderr = StringIO()

            with patch.object(dynamic_m3, "ColorExporter") as exporter_type:
                exporter_type.return_value.apply.return_value = ("digest", envelope)
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    dynamic_m3.main([str(image), "-m", "light"])

        lines = stdout.getvalue().strip().splitlines()
        palette_lines = [
            line for line in lines if line.startswith(dynamic_m3.M3_PALETTE_PREFIX)
        ]
        self.assertEqual(len(palette_lines), 1)
        self.assertEqual(lines[-1], palette_lines[0])
        self.assertEqual(
            json.loads(palette_lines[0][len(dynamic_m3.M3_PALETTE_PREFIX) :]),
            envelope,
        )
        self.assertIn("[*] Processing:", stdout.getvalue())
        self.assertIn("[+] Plasma colors applied successfully.", stdout.getvalue())
        self.assertEqual(stderr.getvalue(), "")

    def test_dynamic_m3_failure_emits_error_without_palette(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "wallpaper.png"
            image.write_bytes(b"image")
            stdout = StringIO()
            stderr = StringIO()

            with patch.object(dynamic_m3, "ColorExporter") as exporter_type:
                exporter_type.return_value.apply.side_effect = RuntimeError("boom")
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    with self.assertRaises(SystemExit) as raised:
                        dynamic_m3.main([str(image), "-m", "light"])

        self.assertEqual(raised.exception.code, 1)
        self.assertNotIn(dynamic_m3.M3_PALETTE_PREFIX, stdout.getvalue())
        error_lines = [
            line for line in stdout.getvalue().splitlines()
            if line.startswith(dynamic_m3.M3_ERROR_PREFIX)
        ]
        self.assertEqual(len(error_lines), 1)
        error_payload = json.loads(
            error_lines[0][len(dynamic_m3.M3_ERROR_PREFIX) :]
        )
        self.assertIn("boom", error_payload["message"])
        self.assertEqual(stderr.getvalue(), "")

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
            digest, envelope = exporter.apply()
            base = Path(home)
            self.assertEqual(envelope["mode"], "dark")
            self.assertEqual(set(envelope["colors"]), set(plasma_color.QML_COLOR_TOKENS))

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
            self.assertIn("Opacity=0.9", text)
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
