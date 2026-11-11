#!/usr/bin/env python3
"""agent/model_worker.py — cancellable provider worker child (Phase 6).

The orchestrator's per-request 120 s deadline must terminate the *provider
transport*, not merely discard a Python thread's eventual result.  This module
runs the injectable ``model_call(message, history)`` in a dedicated child
process over a pipe:

* the parent waits at most ``deadline_s`` for a result;
* on expiry it sends SIGTERM, then SIGKILL after a short grace period, and
  reaps the child;
* the child sets ``PR_SET_PDEATHSIG`` on Linux so a killed parent cannot leave
  an orphaned provider call behind;
* provider exceptions are returned as typed worker errors so the orchestrator
  can distinguish ``MODEL_TIMEOUT`` from ``PROVIDER_ERROR``.

``fork`` is required because the production ``model_call`` is a closure over
the selected provider instance and is not required to be picklable.  The
supported runtime is Linux (see ``docs/supported-runtime-matrix.md``); if a
worker cannot be created the caller fails closed rather than falling back to an
uncancellable in-process call.
"""

from __future__ import annotations

import ctypes
import multiprocessing
import os
import signal
from typing import Any, Callable

_WORKER_CALL = "call"
_WORKER_STOP = "stop"
_KILL_GRACE_S = 1.0


class ModelCallTimeout(TimeoutError):
    """The provider call exceeded its independent wall-clock deadline."""


class ModelCallError(RuntimeError):
    """The provider call failed inside the worker child."""


class ModelCallWorkerUnavailable(RuntimeError):
    """The platform/process context cannot create the cancellable child."""


def _set_parent_death_signal(parent_pid: int) -> None:
    """Best-effort Linux ``PR_SET_PDEATHSIG`` for the worker child."""
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        # PR_SET_PDEATHSIG = 1; the signal is delivered if the parent dies.
        if libc.prctl(1, int(signal.SIGTERM)) != 0:
            return
        # Close the fork/exec race: if the parent died before prctl took
        # effect, do not continue as an orphan.
        if os.getppid() != parent_pid:
            os._exit(1)
    except Exception:  # pragma: no cover — best-effort platform hardening
        return


def _worker_loop(conn: Any, model_call: Callable[..., Any], parent_pid: int) -> None:
    """Child loop: one ``model_call`` per command, no inherited threads."""
    _set_parent_death_signal(parent_pid)
    while True:
        try:
            command = conn.recv()
        except EOFError:
            break
        if not isinstance(command, tuple) or len(command) != 3:
            break
        kind, message, history = command
        if kind == _WORKER_STOP:
            break
        if kind != _WORKER_CALL:
            break
        try:
            result = model_call(message, history)
            if isinstance(result, tuple) and len(result) == 2:
                text, meta = result
            else:
                text, meta = result, {}
            if not isinstance(text, str):
                conn.send(
                    (
                        "error",
                        "NON_STRING_OUTPUT",
                        "model_call returned non-string text",
                    )
                )
                continue
            provider_error = None
            if isinstance(meta, dict):
                raw_error = meta.get("provider_error")
                if isinstance(raw_error, str) and raw_error:
                    provider_error = raw_error[:32]
            conn.send(("ok", text, provider_error))
        except BaseException as exc:  # provider failures are data, not crashes
            try:
                conn.send(
                    ("error", type(exc).__name__, str(exc)[:300])
                )
            except Exception:
                break
    try:
        conn.close()
    except Exception:
        pass


def _is_timeout_name(name: str) -> bool:
    return "timeout" in str(name).lower()


class ModelWorker:
    """A persistent, cancellable child process for one orchestrator run."""

    def __init__(
        self,
        model_call: Callable[..., Any],
        *,
        kill_grace_s: float = _KILL_GRACE_S,
    ) -> None:
        self._model_call = model_call
        self._kill_grace_s = max(float(kill_grace_s), 0.0)
        self._proc: Any = None
        self._conn: Any = None
        self._pid: int | None = None

    @property
    def pid(self) -> int | None:
        return self._pid

    def _ensure_worker(self) -> None:
        if self._proc is not None:
            if self._proc.is_alive():
                return
            self._kill_worker()
        parent_conn = child_conn = None
        try:
            # Explicit fork: production model_call is a closure and need not
            # be picklable.  Do not silently fall back to an in-process call.
            ctx = multiprocessing.get_context("fork")
            parent_conn, child_conn = ctx.Pipe(duplex=True)
            proc = ctx.Process(
                target=_worker_loop,
                args=(child_conn, self._model_call, os.getpid()),
                daemon=True,
            )
            proc.start()
        except Exception as exc:
            for conn in (parent_conn, child_conn):
                if conn is not None:
                    try:
                        conn.close()
                    except Exception:
                        pass
            raise ModelCallWorkerUnavailable(
                f"cancellable provider worker unavailable: {type(exc).__name__}"
            ) from exc
        assert parent_conn is not None and child_conn is not None
        child_conn.close()
        self._proc = proc
        self._conn = parent_conn
        self._pid = proc.pid

    def _kill_worker(self) -> None:
        proc, conn = self._proc, self._conn
        self._proc = None
        self._conn = None
        self._pid = None
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
        if proc is None:
            return
        try:
            if proc.is_alive():
                proc.terminate()
                proc.join(self._kill_grace_s)
            if proc.is_alive():
                proc.kill()
                proc.join(self._kill_grace_s)
            proc.close()
        except Exception:  # pragma: no cover — process already reaped
            pass

    def request(
        self, message: str, history: list, deadline_s: float
    ) -> tuple[str, str | None]:
        """Run one model call; raise typed timeout/error or return text.

        Returns ``(text, provider_error)`` on success.  ``provider_error`` is a
        non-fatal provider status (for example ``"CONNECTION"``) that the
        orchestrator maps to a typed failure before parsing model output.
        """
        self._ensure_worker()
        assert self._conn is not None  # narrowed by _ensure_worker
        try:
            self._conn.send((_WORKER_CALL, message, history))
        except Exception as exc:
            self._kill_worker()
            raise ModelCallError(
                f"worker command failed: {type(exc).__name__}"
            ) from exc
        if not self._conn.poll(max(float(deadline_s), 0.01)):
            self._kill_worker()
            raise ModelCallTimeout(
                f"model call exceeded {float(deadline_s):g}s; worker child terminated"
            )
        try:
            payload = self._conn.recv()
        except (EOFError, OSError) as exc:
            self._kill_worker()
            raise ModelCallError(
                f"worker exited without a result: {type(exc).__name__}"
            ) from exc
        if not isinstance(payload, tuple) or len(payload) < 2:
            self._kill_worker()
            raise ModelCallError("worker returned a malformed result")
        kind = payload[0]
        if kind == "error":
            name = str(payload[1]) if len(payload) > 1 else "WorkerError"
            detail = str(payload[2]) if len(payload) > 2 else ""
            self._kill_worker()
            if _is_timeout_name(name):
                raise ModelCallTimeout(f"{name}: {detail}")
            raise ModelCallError(f"{name}: {detail}")
        if kind != "ok" or not isinstance(payload[1], str):
            self._kill_worker()
            raise ModelCallError("worker returned a non-string model result")
        provider_error = payload[2] if len(payload) > 2 else None
        if isinstance(provider_error, str) and provider_error:
            # Let the supervisor record the typed provider status.  A provider
            # error is terminal for the run, so the worker is still reaped.
            self._kill_worker()
            return payload[1], provider_error
        return payload[1], None

    def close(self) -> None:
        """Ask the child to exit, then reap it; idempotent."""
        proc, conn = self._proc, self._conn
        if proc is not None and proc.is_alive() and conn is not None:
            try:
                conn.send((_WORKER_STOP, None, None))
                proc.join(self._kill_grace_s)
            except Exception:
                pass
        self._kill_worker()

    def __enter__(self) -> "ModelWorker":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()
