import subprocess

from nibras_installer.modules import utils


def test_run_command_returns_true_on_success(monkeypatch):
    monkeypatch.setattr(utils.subprocess, "run", lambda *_a, **_kw: None)

    assert utils.run_command("true") is True


def test_run_command_returns_false_on_failure(monkeypatch):
    def fake_run(*_a, **_kw):
        raise subprocess.CalledProcessError(1, "false", stderr=b"boom")

    monkeypatch.setattr(utils.subprocess, "run", fake_run)

    assert utils.run_command("false", exit_on_fail=False) is False
