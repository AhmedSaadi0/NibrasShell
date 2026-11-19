import nibras_installer.modules.dependencies as deps
from nibras_installer.modules import i18n

VNSTAT_SERVICE_DIR = "/etc/sv/vnstatd"
NETHOGS_PATH = "/usr/bin/nethogs"


def _fake_run(calls, result=True):
    """بديل run_command يسجل الأوامر ويعيد نتيجة محددة"""

    def _run(cmd, **_kw):
        calls.append(cmd)
        return result

    return _run


def _no_nethogs(monkeypatch):
    """ضمان عدم الاعتماد على وجود nethogs على الجهاز المُشغِّل للاختبارات"""
    monkeypatch.setattr(
        deps.shutil, "which", lambda *_a, **_kw: None
    )


def _nethogs_at(monkeypatch, path=NETHOGS_PATH):
    monkeypatch.setattr(
        deps.shutil,
        "which",
        lambda name: path if name == "nethogs" else None,
    )


def _void_service_dir(monkeypatch, exists=True):
    """محاكاة وجود مجلد خدمة runit على أي توزيعة"""
    monkeypatch.setattr(
        deps.os.path, "isdir", lambda p: p == VNSTAT_SERVICE_DIR and exists
    )


def test_install_fedora_calls_python_env(monkeypatch):
    called = {"env": False}

    monkeypatch.setattr(deps, "run_command_verbose", lambda *_args, **_kw: None)
    monkeypatch.setattr(deps, "run_command", lambda *_args, **_kw: None)
    monkeypatch.setattr(deps.subprocess, "run", lambda *_args, **_kw: None)

    def fake_env():
        called["env"] = True

    monkeypatch.setattr(deps, "install_python_env", fake_env)

    deps.install_fedora(False)
    assert called["env"] is True


def test_install_arch_calls_python_env(monkeypatch):
    called = {"env": False}

    monkeypatch.setattr(deps, "run_command_verbose", lambda *_args, **_kw: None)

    def fake_env():
        called["env"] = True

    monkeypatch.setattr(deps, "install_python_env", fake_env)

    deps.install_arch(False)
    assert called["env"] is True


def test_install_void_calls_python_env(monkeypatch):
    called = {"env": False}

    monkeypatch.setattr(deps, "run_command_verbose", lambda *_args, **_kw: None)

    def fake_env():
        called["env"] = True

    monkeypatch.setattr(deps, "install_python_env", fake_env)

    deps.install_void(False)
    assert called["env"] is True


def test_install_dependencies_enables_vnstat(monkeypatch):
    calls = []

    monkeypatch.setattr(deps, "install_fedora", lambda *_: None)
    monkeypatch.setattr(deps, "run_command", _fake_run(calls))
    _no_nethogs(monkeypatch)

    deps.install_dependencies("fedora", install_optional=False)

    assert any("systemctl enable --now vnstat.service" in c for c in calls)


def test_install_dependencies_enables_vnstat_with_runit_on_void(monkeypatch):
    calls = []

    monkeypatch.setattr(deps, "install_void", lambda *_: None)
    monkeypatch.setattr(deps, "run_command", _fake_run(calls))
    _void_service_dir(monkeypatch, exists=True)
    _no_nethogs(monkeypatch)

    deps.install_dependencies("void", install_optional=False)

    assert not any("systemctl" in c for c in calls)
    assert any(
        f"ln -sfn {VNSTAT_SERVICE_DIR} /var/service/vnstatd" in c for c in calls
    )


def test_install_dependencies_falls_back_to_default_runsvdir_on_void(monkeypatch):
    calls = []

    monkeypatch.setattr(deps, "install_void", lambda *_: None)
    _void_service_dir(monkeypatch, exists=True)
    _no_nethogs(monkeypatch)

    def fake_run(cmd, **_kw):
        calls.append(cmd)
        return "/var/service" not in cmd

    monkeypatch.setattr(deps, "run_command", fake_run)

    deps.install_dependencies("void", install_optional=False)

    assert any(
        f"ln -sfn {VNSTAT_SERVICE_DIR} /var/service/vnstatd" in c for c in calls
    )
    assert any(
        f"ln -sfn {VNSTAT_SERVICE_DIR} /etc/runit/runsvdir/default/vnstatd" in c
        for c in calls
    )


def test_install_dependencies_reports_missing_vnstat_service_dir(monkeypatch):
    calls = []

    monkeypatch.setattr(deps, "install_void", lambda *_: None)
    monkeypatch.setattr(deps, "run_command", _fake_run(calls))
    _void_service_dir(monkeypatch, exists=False)
    _no_nethogs(monkeypatch)

    deps.install_dependencies("void", install_optional=False)

    assert not any("ln -sfn" in c for c in calls)


def test_install_dependencies_sets_nethogs_caps(monkeypatch):
    calls = []

    monkeypatch.setattr(deps, "install_fedora", lambda *_: None)
    monkeypatch.setattr(deps, "run_command", _fake_run(calls))
    _nethogs_at(monkeypatch)

    deps.install_dependencies("fedora", install_optional=False)

    cap_calls = [c for c in calls if "setcap" in c]
    assert len(cap_calls) == 1
    assert "cap_net_admin" in cap_calls[0]
    assert "cap_net_raw" in cap_calls[0]
    assert "cap_dac_read_search" in cap_calls[0]
    assert "cap_sys_ptrace+eip" in cap_calls[0]
    assert cap_calls[0].endswith(NETHOGS_PATH)


def test_install_dependencies_skips_caps_when_nethogs_missing(monkeypatch):
    calls = []

    monkeypatch.setattr(deps, "install_fedora", lambda *_: None)
    monkeypatch.setattr(deps, "run_command", _fake_run(calls))
    _no_nethogs(monkeypatch)

    deps.install_dependencies("fedora", install_optional=False)

    assert not any("setcap" in c for c in calls)


def test_install_dependencies_reports_vnstat_failure(monkeypatch, capsys):
    calls = []

    monkeypatch.setattr(deps, "install_fedora", lambda *_: None)
    monkeypatch.setattr(deps, "run_command", _fake_run(calls, result=False))
    _no_nethogs(monkeypatch)

    i18n.load_languages()
    i18n.set_lang("en")

    deps.install_dependencies("fedora", install_optional=False)

    assert i18n.msg("vnstat_service_failed") in capsys.readouterr().out


def test_fedora_packages_include_libcap(monkeypatch):
    cmds = []

    monkeypatch.setattr(
        deps, "run_command_verbose", lambda cmd, **_kw: cmds.append(cmd)
    )
    monkeypatch.setattr(
        deps.subprocess, "run", lambda cmd, **_kw: cmds.append(cmd)
    )
    monkeypatch.setattr(deps, "install_python_env", lambda: None)

    deps.install_fedora(False)

    pkg_cmd = " ".join(cmds)
    assert "libcap" in pkg_cmd
    assert "vnstat" in pkg_cmd
    assert "nethogs" in pkg_cmd


def test_arch_packages_include_vnstat_and_nethogs(monkeypatch):
    cmds = []

    monkeypatch.setattr(
        deps, "run_command_verbose", lambda cmd, **_kw: cmds.append(cmd)
    )
    monkeypatch.setattr(deps, "install_python_env", lambda: None)

    deps.install_arch(False)

    pkg_cmd = " ".join(cmds)
    assert "vnstat" in pkg_cmd
    assert "nethogs" in pkg_cmd
    assert "libcap" in pkg_cmd


def test_void_packages_include_libcap_progs(monkeypatch):
    cmds = []

    monkeypatch.setattr(
        deps, "run_command_verbose", lambda cmd, **_kw: cmds.append(cmd)
    )
    monkeypatch.setattr(deps, "install_python_env", lambda: None)

    deps.install_void(False)

    pkg_cmd = " ".join(cmds)
    assert "libcap-progs" in pkg_cmd
    # حزمة libcap في فود تحتوي المكتبة فقط، الأدوات في libcap-progs
    assert "libcap " not in pkg_cmd
