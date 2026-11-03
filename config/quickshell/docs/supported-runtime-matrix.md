# supported-runtime-matrix.md — NibrasShell AI Diagnostics (Release 1)

- **Status:** Phase 6 release-gate reference. Release 1 is read-only: the
  diagnostics path executes no state-changing remediation and returns only
  declarative, backend-rendered guidance.
- **Governing plan:** `docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md`
  (§10.3, §14, §16, §17, Phase 6).
- **Scope:** the AI diagnostics pipeline (`scripts/python/ai/agent`,
  `evidence`, `incident`, `policy`) and the QML children that start it
  (`services/AiTask.qml`, the QML AI diagnostics consumers, and
  `services/system/ResourceDiagnostics.qml`). The legacy v1 path remains
  behind its existing feature flag and is intentionally not reclassified.

## 1. Supported runtime matrix

| Runtime dimension | Supported / tested here | Status | Notes |
|---|---|---|---|
| Operating system | Linux (Fedora 43 host in the validation environment) | Supported | Non-Linux platforms are out of scope for R1. |
| Init / log source | systemd + journald | Supported | Structured evidence requires `journalctl --output=json`; a missing journald is a typed failure, never a silent fallback. |
| Python | System `python3` (3.14.7 in this environment) with the existing `requirements-3.13.txt` pins | Supported for validation | No new dependency was added; tests use stdlib `unittest`. |
| Quickshell | Quickshell 0.3.1 / Qt 6 | Supported with the documented Process limitation | `Process.signal(int)` is used for SIGTERM/SIGKILL escalation; it is best-effort because the exact in-process termination semantics are not documented in-repo. The task fails closed regardless. |
| Container runtime | Podman, rootless or rootful, read-only inspection | Supported when the user's runtime context is reachable | `podman inspect`/`info` only; wrong-context, permission, and unavailable states remain typed failures. |
| Host systemd units | `systemctl show` (system or user scope selected by backend) | Supported when readable | User-scope actions are gated separately; no mutation verbs exist in the tool allowlist. |
| Process inspection | `/proc/<pid>/status`, `/proc/<pid>/cgroup`, process metadata | Supported when visible | `/proc/<pid>/environ` is never read. `hidepid=2`, SELinux, or AppArmor denials are reported as permission/unavailable states. |
| Local model provider | OpenAI-compatible local endpoint (`requests`) | Preferred | No host data leaves the machine; client timeout is `(connect 5 s, read 60 s)`. |
| Ollama provider | Local/remote endpoint configured by the user | Supported with residual limitation | The installed client has no verified native request-cancellation API; the orchestrator supervisor is the total-deadline boundary. |
| Remote providers | OpenAI, OpenRouter, Gemini, DeepSeek | Optional | Redaction happens before send; egress is user-selected. SDK cancellation semantics remain best-effort; the orchestrator fails closed at 120 s. |
| Boot/incident payload | `nibras.incident/v1` structured envelope | Supported | Validated by the Phase 1–3 suites; old v1 envelope remains structurally readable through the legacy adapter. |
| Audit destination | `$XDG_STATE_HOME/nibrasshell/ai-diagnostics/audit.jsonl` (default `~/.local/state/...`) | Supported | Append-only JSONL, mode `0600` at creation; write failure is fail-open for the request and fail-closed for audit visibility. |

### Explicitly unsupported / degraded

- Non-systemd hosts (for the journal-based structured path).
- Windows/macOS/BSD.
- Container inspection without a reachable Podman context.
- `/proc` access blocked by kernel hardening, SELinux, or container namespace
  policy (reported as a typed permission/unavailable result).
- Claims that require a historical PID identity that no longer exists.
- Any request for environment variable values or names, labels, mounts, or
  secret-bearing fields: refused by default (§14).
- Any automatic remediation execution in R1. The `manual_guidance` /
  `explain_only` action kinds are declarative only.
- Guaranteed hard cancellation of a third-party SDK request inside the same
  Python process. The supervisor discards the result and the daemon thread is
  daemonized; the process must not be treated as a synchronous hard cancel.

## 2. Permission / context checklist

Run diagnostics as the **normal interactive user**; do not run the backend
with `sudo`:

- [ ] `journalctl -b 0 -p warning -n 1 --output=json` works for the current
      user (or the permission failure is visible and typed).
- [ ] `systemctl show <unit>` works in the intended scope; a system-unit
      permission denial must not be converted into "unit absent".
- [ ] Rootless `podman inspect` / `podman info` works in the same user scope
      as the incident; wrong-context results stay wrong-context.
- [ ] `/proc/<pid>/status` and `/proc/<pid>/cgroup` are readable for the
      subject; `/proc/<pid>/environ` is **never** opened.
- [ ] Environment values and names are absent from the incident, the model
      prompt, tool results, audit lines, and QML copy paths.
- [ ] The audit directory is user-owned; the log is metadata-only and
      contains no raw commands, prompts, log messages, or tool argv.
- [ ] The AI child is observed for at most 310 s; timeout produces a failed
      task and the AiService queue/cooldown resumes.
- [ ] No `sudo`, package-manager, `systemctl start/stop/restart/enable`,
      container create/update/remove, or shell command is executed by the
      diagnostics path.

## 3. Audit log contract

The production v2 path passes `audit.AuditLogger.from_env()` to the
orchestrator. Each event is sanitized and bounded:

```json
{
  "schema_version": "nibras.audit/v1",
  "ts": "2026-11-03T12:00:00.000Z",
  "correlation_id": "00000000-0000-0000-0000-000000000001",
  "stage": "orchestrate",
  "outcome": "GUIDANCE_VALIDATED",
  "reason_codes": ["R_OK"],
  "redaction_counts": {"tool:journal_query": 2},
  "budget_usage": {"model_calls_used": 3, "model_calls_max": 4},
  "latency_ms": {"total": 812.4, "model_calls": [{"call_index": 1, "role": "A", "elapsed_ms": 240.1}]}
}
```

Stages: `collect`, `discover`, `orchestrate`, `validate`, `render`.
Disable writes with `NIBRAS_SHELL_AI_AUDIT_DISABLED=1`; override the path with
`NIBRAS_SHELL_AI_AUDIT_LOG` for tests or an explicit deployment policy.
Audit setup/write errors never change the safe diagnostic result.

## 4. Measured-latency logging and calibration

Every model call is timed independently around the 120 s supervisor, and every
executed tool is timed around the 5 s subprocess wrapper. Raw measurements are
additive fields in:

- the envelope: `orchestrator.latency_ms.model_calls`,
  `orchestrator.latency_ms.tool_calls`, and `orchestrator.latency_ms.total`;
- the JSONL audit: `latency_ms` plus `budget_usage`.

Calibration procedure for the release operator:

1. Enable `NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE=1` and choose the intended
   provider (local preferred).
2. Run at least five representative incidents from the supported runtime.
3. Read `latency_ms` and `budget_usage` from the audit JSONL; compare p50/p95
   against the 120 s per-request, 300 s incident, and 310 s QML limits.
4. Do not lower a limit based on synthetic timing. The constants remain
   **PROPOSED** until real local-model measurements are obtained.

This Phase 6 environment has no runnable local model/provider endpoint, so no
empirical provider calibration value is claimed. The Phase 6 tests measure the
instrumentation path with an injected model; they do not claim provider
latency.

## 5. Provider-cancellation review

| Provider | Native client limit | Hard cancellation | Supervisor / result |
|---|---|---|---|
| Local (`requests`) | `(connect 5 s, read 60 s)` passed as a tuple | No in-process hard cancel; read timeout is inter-byte inactivity, not total wall clock | 120 s orchestrator supervisor discards the result; worker is daemonized; no retry after deadline. |
| OpenAI | `timeout=120 s` passed where the installed SDK exposes it | Not claimed; SDK behavior is version-dependent | Same supervisor; safe timeout failure. |
| OpenRouter | `timeout=120 s` passed where the installed SDK exposes it | Not claimed | Same supervisor; safe timeout failure. |
| Gemini | No verified native timeout wiring in this phase | Not claimed | Same supervisor; safe timeout failure. |
| Ollama | No verified native timeout wiring in this phase | Not claimed | Same supervisor; safe timeout failure. |

The orchestrator never treats a late/partial response as success. Tool
subprocesses have their own 5 s deadline, SIGTERM→SIGKILL, and output caps.
All cancellation paths preserve the "no automatic state-changing behavior"
rule: timeout/failure returns `no_action_taken: true`.

## 6. QML lifecycle review

- `services/AiTask.qml` has an independent 310 s watchdog. On expiry it sends
  SIGTERM, escalates to SIGKILL after a 1 s grace period, suppresses partial
  stdout parsing, marks the task failed exactly once, and lets `AiService`
  restore its queue slot and cooldown.
- `services/system/ResourceDiagnostics.qml` has the same 310 s watchdog and
  escalation pattern; a timed-out action returns the bounded default result
  and releases the queue.
- `AiTask` no longer writes the raw provider envelope to the console; it logs
  only the received byte count. This reduces incidental model/output exposure.
- Residual limitation: Quickshell 0.3.1's exact `Process` termination
  semantics are not documented in-repo. The watchdog is therefore a
  best-effort signal path plus a fail-closed result; manual verification is
  listed in `docs/diag-contract-notes.md` §11. The only skipped unit test is
  the historical Phase-3 row-20 runtime probe; its source contract is covered
  by the Phase-6 suite and the real-runtime behavior remains a manual check.

## 7. Privacy review (environment default-deny, AC #13)

- `evidence/redact.py::redact_environment()` returns `{}` for any provided
  environment mapping and refuses a non-empty allowlist in R1; it records only
  the `env-dropped` count.
- No production code contains a `/proc/<pid>/environ` read. `tools.py` reads
  status/cgroup metadata only; the journal collector does not read process
  environment.
- `contract.py` refuses environment/widening argument keys before execution
  (`WIDENING_KEYS`, `R_REFUSED_WIDENING`).
- Audit records contain only typed metadata; they do not accept incident text,
  prompts, tool argv, commands, or secret values.
- Provider requests are redacted before send; remote providers remain an
  explicit user choice. The local provider is the privacy-preferred mode.
- Legacy v1 remains behind its flag; Phase 6 does not change or broaden it.

## 8. Acceptance criteria evidence map (AC #1–#17)

| AC | Evidence |
|---|---|
| AC #1 | `test_phase1_discovery.py` motivating journal rows; `test_phase2_incident.py` cgroup provenance; manual motivating scenario review. |
| AC #2 | `test_phase3_orchestrator.py::TestOrchestratorEndToEnd.test_row4_host_remediation_prohibited_keys`; `test_phase4_policy.py` host-remediation rows; `test_phase6_release_hardening.py::TestNoAutomaticStateChange.test_tool_allowlist_is_read_only_and_closed`. |
| AC #3 | `test_phase1_discovery.py` ambiguous/unavailable rows; `test_phase2_incident.py`; `test_phase4_policy.py` unresolved-evidence rows. |
| AC #4 | `test_phase2_incident.py` missing-cgroup and missing-sender rows; `test_phase1_discovery.py` unknown-sender rows. |
| AC #5 | `test_phase2_incident.py` typed failure rows; `test_phase3_orchestrator.py` timeout/failure rows. |
| AC #6 | `test_phase3_orchestrator.py` injection/opaque-ref/prohibited-key rows; `test_phase4_policy.py`. |
| AC #7 | `test_phase6_release_hardening.py::TestNoAutomaticStateChange.test_tool_requests_only_invoke_read_only_argv` + `test_null_tool_model_executes_no_command`; full suite has no write-capable tool. |
| AC #8 | `test_phase3_orchestrator.py` evidence-ref validation rows; `test_phase4_policy.py` evidence-linkage rows. |
| AC #9 | `test_phase5_qml_adapters.py::test_boot_details_has_no_fail_open_enum_defaults` and status-render rows. |
| AC #10 | `test_phase5_qml_adapters.py` golden legacy/diagnosis fixtures; `test_phase6_release_hardening.py::TestSupportedRuntimeMatrix` runtime/checklist contract. |
| AC #11 | `test_phase1_discovery.py` conmon/workload separation; `test_phase4_policy.py` domain gates. |
| AC #12 | `test_phase2_incident.py` cursor round-trip; `test_phase3_orchestrator.py` integer-cursor rejection. |
| AC #13 | `test_phase2_incident.py::TestRedaction.test_env_default_deny`; `test_phase3_orchestrator.py::test_row10_env_request_in_flow`; `test_phase6_release_hardening.py::TestPrivacyReview`. |
| AC #14 | `test_phase1_discovery.py` cgroup trio; `test_phase2_incident.py::test_row4_cgroup_trio_three_fields_and_no_upgrade`. |
| AC #15 | `test_phase5_qml_adapters.py` legacy quarantine and diagnosis adapter rows. |
| AC #16 | `test_phase4_policy.py` closed-status vocabulary and template rendering; `test_phase5_qml_adapters.py` status labels. |
| AC #17 | `test_phase3_orchestrator.py` call/tool budget rows; `test_phase6_release_hardening.py::TestMeasuredLatencyAndAudit` budget ledger. |

Manual checks that cannot be fully automated are in
`docs/diag-contract-notes.md` §11 and are limited to real QML/Quickshell and
real-provider latency execution. No acceptance criterion depends on an
automatic state-changing action.

## 9. Release/rollback note

This phase is additive. The v2 orchestration path remains behind
`--orchestrator v2`; the production v1 path is untouched. Release and rollback
remain user-managed; no branch, commit, push, or rollback operation was
performed by the agent.
