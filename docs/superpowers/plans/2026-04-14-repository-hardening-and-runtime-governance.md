# Repository Hardening And Runtime Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the FanControl repository from a partially-engineered personal script project into a single-source, testable, and document-governed codebase with clear runtime boundaries.

**Architecture:** Keep `scripts/current/` as the only repository source of truth for active scripts, treat `C:\FanControl_Auto\` as a deploy-only runtime mirror, introduce shared runtime path and runtime state helpers, and reduce duplicated logic in `auto_switch.ps1`, `switch.ps1`, `check_status.ps1`, and `monitor_simple.ps1`. Make documentation authoritative by separating "current structure" from "background/history", and verify every stage with repo-local tests plus targeted runtime checks.

**Tech Stack:** PowerShell, Pester 5.x, Markdown, Windows Scheduled Tasks, FanControl runtime mirror

---

## Verified Baseline

- The repository currently contains `docs/PROJECT_STRUCTURE.md`, but that file is a整理报告 rather than a current-state structure spec.
- `docs/README_CONSOLIDATED.md` mixes navigation/history with future structure recommendations.
- `SYNC_MEMO.md` already describes a repo/runtime split, but that split is enforced only by convention.
- `SCRIPT_SYNC_REPORT.md` is **not present** in the tracked repository. If that file exists elsewhere on disk, treat it as an external stale artifact and archive it rather than recreating it in the repo.
- The current test suite passes with `pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1`.

---

## Target End State

- `docs/PROJECT_STRUCTURE.md` is the single authority for current repository layout and role definitions.
- `docs/README_CONSOLIDATED.md` is navigation/history only and stops defining live structure.
- Root directory contains only first-line entrypoints and necessary assets; configs live under `configs/`.
- Active scripts no longer hardcode runtime paths in multiple files; all active scripts resolve paths through one helper.
- Active scripts no longer assemble runtime state independently; all active scripts consume one unified state model.
- `switch.ps1` no longer shells out to a hardcoded runtime script path to restore auto mode.
- Verification distinguishes "command issued", "cache observed", and "confidence".
- `check_status.ps1` and `monitor_simple.ps1` have behavior tests, including multi-source conflict scenarios.

---

### Task 1: Freeze the baseline and document the actual current state

**Files:**
- Modify: `docs/PROJECT_STRUCTURE.md`
- Modify: `docs/README_CONSOLIDATED.md`
- Modify: `README.md`
- Modify: `scripts/README.md`
- Modify: `SYNC_MEMO.md`

- [ ] **Step 1: Capture the current repository facts before changing structure**

Run:

```powershell
Get-ChildItem -Force
Get-ChildItem scripts -Recurse | Select-Object FullName
rg -n "scripts/production|scripts/legacy|configs/|source-of-truth|运行目录|README_CONSOLIDATED|PROJECT_STRUCTURE" README.md docs scripts SYNC_MEMO.md
```

Expected: a saved baseline of what the repository currently contains and where outdated wording still appears.

- [ ] **Step 2: Rewrite `docs/PROJECT_STRUCTURE.md` to describe only the current real structure**

Required content:

```text
- current repository root directories and their roles
- current scripts/current, scripts/iterating, scripts/history, scripts/tools meaning
- current root-level files that are intentionally kept
- runtime mirror relationship to C:\FanControl_Auto
- what is current fact vs what is future work
```

Expected: `docs/PROJECT_STRUCTURE.md` stops being a "整理完成报告" and becomes the authoritative current-state structure spec.

- [ ] **Step 3: Reduce `docs/README_CONSOLIDATED.md` to navigation/history only**

Required changes:

```text
- keep document index, time line, and history links
- remove or clearly mark future-structure suggestions
- add a short line that current structure is defined only in docs/PROJECT_STRUCTURE.md
```

Expected: no ambiguity between "this is how the repo is now" and "this is a possible future layout".

- [ ] **Step 4: Make `README.md`, `scripts/README.md`, and `SYNC_MEMO.md` agree on source/runtime roles**

Required wording:

```text
Repo source of truth: scripts/current/
Runtime mirror: C:\FanControl_Auto\
Deploy action: copy verified source files into runtime mirror
Emergency hotfix rule: if runtime was edited directly, sync back immediately
```

Expected: the same role language appears in all four documents with no conflicting terminology.

- [ ] **Step 5: Verify doc consistency**

Run:

```powershell
rg -n "scripts/production|scripts/legacy" README.md docs scripts SYNC_MEMO.md
```

Expected: no active document outside `archive/` or `scripts/history/` still describes `scripts/production` or `scripts/legacy` as current live structure.

---

### Task 2: Clean the repository root and move config assets under `configs/`

**Files:**
- Create: `configs/`
- Move: `Game.json`
- Move: `Quiet_mode.json`
- Move: `Game_ultr.json`
- Modify: `README.md`
- Modify: `docs/PROJECT_STRUCTURE.md`
- Modify: `docs/README_CONSOLIDATED.md`
- Modify: `docs/CONFIG_ANALYSIS.md`
- Modify: `docs/CONFIG_ITERATION_GUIDE.md`

- [ ] **Step 1: Create the config directory and move tracked config snapshots**

Run:

```powershell
New-Item -ItemType Directory -Force -Path '.\configs' | Out-Null
Move-Item '.\Game.json' '.\configs\Game.json'
Move-Item '.\Quiet_mode.json' '.\configs\Quiet_mode.json'
Move-Item '.\Game_ultr.json' '.\configs\Game_ultr.json'
```

Expected: the three config snapshots exist under `configs/` and no longer live at repository root.

- [ ] **Step 2: Update all repository references to the moved config files**

Run:

```powershell
rg -n "\bGame\.json\b|\bQuiet_mode\.json\b|\bGame_ultr\.json\b" README.md docs scripts tests
```

Required update rule:

```text
- when referring to tracked repo assets, use configs/Game.json style paths
- when referring to live FanControl runtime configs, keep D:\Program Files (x86)\FanControl\Configurations
```

Expected: docs stop conflating "tracked repo config snapshots" with "live FanControl config directory".

- [ ] **Step 3: Verify root cleanup**

Run:

```powershell
Get-ChildItem -Force | Select-Object Name
```

Expected: root keeps `README.md`, `CHANGELOG.md`, `LICENSE`, `docs/`, `scripts/`, `tests/`, `archive/`, `.github/`, `.claude/`, `configs/`, and a small number of intentional top-level files only.

---

### Task 3: Introduce a shared runtime path layer

**Files:**
- Create: `scripts/current/runtime_paths.ps1`
- Modify: `scripts/current/auto_switch.ps1`
- Modify: `scripts/current/switch.ps1`
- Modify: `scripts/current/check_status.ps1`
- Modify: `scripts/current/monitor_simple.ps1`
- Modify: `scripts/current/volume_helper.ps1`
- Modify: `scripts/current/fix_startup_logon.ps1`
- Modify: `tests/TestHelpers.ps1`
- Create: `tests/FanControl.RuntimePaths.Tests.ps1`

- [ ] **Step 1: Add `runtime_paths.ps1` as the only place that knows runtime defaults**

Create a helper with this shape:

```powershell
function Get-FanControlPaths {
    $runtimeRoot = if ($env:FANCONTROL_RUNTIME_ROOT) { $env:FANCONTROL_RUNTIME_ROOT } else { 'C:\FanControl_Auto' }
    $configDir = if ($env:FANCONTROL_CONFIG_DIR) { $env:FANCONTROL_CONFIG_DIR } else { 'D:\Program Files (x86)\FanControl\Configurations' }
    $fanControlExe = if ($env:FANCONTROL_EXE) { $env:FANCONTROL_EXE } else { 'D:\Program Files (x86)\FanControl\FanControl.exe' }

    return [PSCustomObject]@{
        RuntimeRoot = $runtimeRoot
        ConfigDir = $configDir
        FanControlExe = $fanControlExe
        StateDir = Join-Path $runtimeRoot 'state'
        LogDir = Join-Path $runtimeRoot 'logs'
        MonitorDir = Join-Path $runtimeRoot 'monitor_data'
        StatusFile = Join-Path (Join-Path $runtimeRoot 'state') 'current_status.json'
        OverrideFlag = Join-Path (Join-Path $runtimeRoot 'state') 'override.flag'
        QuietConfig = Join-Path $configDir 'Quiet_mode.json'
        GameConfig = Join-Path $configDir 'Game.json'
        CacheFile = Join-Path $configDir 'CACHE'
        RuntimeAutoSwitch = Join-Path $runtimeRoot 'auto_switch.ps1'
    }
}
```

Expected: all runtime-sensitive paths can be overridden without source rewriting.

- [ ] **Step 2: Refactor every active script to import `runtime_paths.ps1` first**

Required change:

```text
- remove duplicated literal path blocks from auto_switch.ps1, switch.ps1, check_status.ps1, monitor_simple.ps1
- derive state/log/config/runtime paths from Get-FanControlPaths
- keep fix_startup_logon.ps1 explicit about the live task target, but source that target via Get-FanControlPaths where possible
```

Expected: active scripts no longer each define their own runtime path constants.

- [ ] **Step 3: Replace brittle test-time string rewriting with environment overrides**

Required test helper changes:

```text
- stop replacing literal source strings for runtime root/config root wherever env override can be used instead
- keep only the minimal test-only replacements that are genuinely unavoidable
```

Expected: `tests/TestHelpers.ps1` stops depending on exact source string matches for basic path redirection.

- [ ] **Step 4: Add path helper tests**

Minimum assertions:

```powershell
(Get-FanControlPaths).RuntimeRoot | Should -Be 'C:\FanControl_Auto'
$env:FANCONTROL_RUNTIME_ROOT = 'D:\Temp\Sandbox'
(Get-FanControlPaths).StateDir | Should -Be 'D:\Temp\Sandbox\state'
```

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected: existing sandbox tests still pass after the refactor and new runtime-path tests pass.

---

### Task 4: Introduce a unified runtime state model

**Files:**
- Create: `scripts/current/runtime_state.ps1`
- Modify: `scripts/current/auto_switch.ps1`
- Modify: `scripts/current/check_status.ps1`
- Modify: `scripts/current/monitor_simple.ps1`
- Modify: `tests/TestHelpers.ps1`
- Create: `tests/FanControl.RuntimeState.Tests.ps1`

- [ ] **Step 1: Add `runtime_state.ps1` with a single consolidated state function**

Create a helper with this public entry:

```powershell
function Get-FanControlRuntimeState {
    param(
        [datetime]$Now = (Get-Date)
    )

    [PSCustomObject]@{
        Timestamp = $Now.ToString('yyyy-MM-dd HH:mm:ss')
        DesiredConfig = $null
        EffectiveConfig = $null
        OverrideActive = $false
        OverrideMode = $null
        ProcessRunning = $false
        VerificationStatus = 'Unknown'
        StateConfidence = 'Low'
        CacheReadable = $false
        StatusReadable = $false
        CacheAgeSeconds = $null
        StatusAgeSeconds = $null
        LastStatus = $null
    }
}
```

Expected: there is one place that reads process, `CACHE`, `current_status.json`, and `override.flag`.

- [ ] **Step 2: Define state precedence explicitly**

Use these rules:

```text
DesiredConfig = override target if override is active, else time-policy target
EffectiveConfig = CACHE.CurrentConfigFileName when cache is readable, else null
VerificationStatus = current_status.json.Status when readable and recent, else Unknown
StateConfidence = High when process running + cache readable + desired/effective consistent
StateConfidence = Medium when some but not all sources agree
StateConfidence = Low when status sources are missing or conflicting
```

Expected: state output becomes a real model, not a dump of unrelated facts.

- [ ] **Step 3: Update status/monitor scripts to consume only the unified state object**

Required change:

```text
- check_status.ps1 formats one unified object
- monitor_simple.ps1 records one unified object per sample
- neither script reimplements its own cache/process/override merge logic
```

Expected: new tools get simpler and conflicting rules disappear.

- [ ] **Step 4: Add multi-source conflict tests**

Minimum scenarios:

```text
- override active but CACHE still shows previous config
- status file says SUCCESS but process is not running
- CACHE missing and status file unreadable
- status file stale but CACHE fresh
```

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected: conflict scenarios now have explicit expectations for `DesiredConfig`, `EffectiveConfig`, `VerificationStatus`, and `StateConfidence`.

---

### Task 5: Decouple manual switching from the runtime entry script

**Files:**
- Create: `scripts/current/config_switch_core.ps1`
- Modify: `scripts/current/auto_switch.ps1`
- Modify: `scripts/current/switch.ps1`
- Modify: `tests/FanControl.AutoSwitchSandbox.Tests.ps1`
- Modify: `tests/FanControl.SwitchSandbox.Tests.ps1`
- Create: `tests/FanControl.SwitchCore.Tests.ps1`

- [ ] **Step 1: Extract shared switch operations into `config_switch_core.ps1`**

Create these functions:

```powershell
function Invoke-FanControlConfigSwitch { }
function Invoke-AutoCalibrationSwitch { }
function Write-FanControlStatus { }
```

Required responsibilities:

```text
Invoke-FanControlConfigSwitch = run FanControl command + verify + emit status payload
Invoke-AutoCalibrationSwitch = pick current desired config and call shared switch
Write-FanControlStatus = write current_status.json in one schema
```

Expected: `auto_switch.ps1` and `switch.ps1` share the same implementation path instead of calling each other by file path.

- [ ] **Step 2: Refactor `switch.ps1` auto mode to call shared calibration logic directly**

Required behavior:

```text
- clear override
- determine current desired config from shared state/time policy
- invoke shared config switch
- return non-zero exit code if calibration fails
```

Expected: `switch.ps1 -Mode auto` no longer depends on `C:\FanControl_Auto\auto_switch.ps1`.

- [ ] **Step 3: Refactor `auto_switch.ps1` to become a thin scheduled-task entrypoint**

Required behavior:

```text
- load helpers
- evaluate force-point or normal mode
- call shared switch core
- log/notify based on result
```

Expected: `auto_switch.ps1` owns scheduling decisions only, not all switching internals.

- [ ] **Step 4: Add manual/auto path tests**

Minimum assertions:

```text
- switch.ps1 -Mode auto does not shell out to runtime auto_switch path
- manual game/quiet/auto paths return non-zero on failed verification
- auto_switch and switch auto mode produce the same target when override is absent
```

Expected: coupling regression is permanently covered.

---

### Task 6: Make time policy and verification data-driven

**Files:**
- Modify: `scripts/current/time_policy.ps1`
- Modify: `scripts/current/config_switch_core.ps1`
- Modify: `scripts/current/auto_switch.ps1`
- Create: `tests/FanControl.TimePolicyData.Tests.ps1`

- [ ] **Step 1: Replace inline minute checks with a data structure**

Use a small table:

```powershell
$script:FanControlSchedule = @(
    @{ Start = 0; End = 480; Config = 'Quiet_mode.json'; Force = $false; Label = 'NightQuiet' },
    @{ Start = 480; End = 760; Config = 'Game.json'; Force = $false; Label = 'MorningGame' },
    @{ Start = 760; End = 840; Config = 'Quiet_mode.json'; Force = $true; Label = 'LunchQuiet' },
    @{ Start = 840; End = 1260; Config = 'Game.json'; Force = $false; Label = 'AfternoonGame' },
    @{ Start = 1260; End = 1440; Config = 'Quiet_mode.json'; Force = $true; Label = 'EveningQuiet' }
)
```

Expected: schedule policy becomes inspectable and easier to extend.

- [ ] **Step 2: Add helper functions that work from the schedule table**

Required public functions:

```powershell
function Get-TimePolicyWindow { }
function Get-ConfigNameForMinute { }
function Test-IsForcePointMinute { }
function Test-IsQuietExitPointMinute { }
```

Expected: existing callers keep stable names while the implementation becomes data-driven.

- [ ] **Step 3: Strengthen verification semantics**

Required fields in written status:

```text
CommandIssued = true/false
ObservedConfig = CACHE value or null
ObservedAt = cache timestamp if available
VerificationConfidence = High/Medium/Low
```

Required logic:

```text
High = observed config matches target and cache timestamp is newer than command start
Medium = observed config matches target but freshness is uncertain
Low = cache unreadable, stale, or mismatched
```

Expected: status is no longer just SUCCESS/FAILED without evidence strength.

- [ ] **Step 4: Verify schedule and verification logic**

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected: boundary tests still pass and new table-driven tests prove the same rules without hardcoded `if` chains.

---

### Task 7: Reclassify and harden monitoring and status tools

**Files:**
- Modify: `scripts/current/check_status.ps1`
- Modify: `scripts/current/monitor_simple.ps1`
- Modify: `README.md`
- Modify: `docs/PROJECT_STRUCTURE.md`
- Create: `tests/FanControl.CheckStatus.Tests.ps1`
- Create: `tests/FanControl.Monitor.Tests.ps1`

- [ ] **Step 1: Decide tool role and rename or reposition if needed**

Decision rule:

```text
- if monitor_simple.ps1 stays under scripts/current/, it must be a supported production diagnostic tool
- if it remains experimental, move it to scripts/iterating/ or scripts/tools/
```

Expected: tool placement matches intended support level.

- [ ] **Step 2: Give `monitor_simple.ps1` explicit operating modes**

Required parameters:

```powershell
param(
    [ValidateSet('Snapshot','Watch','Sample')][string]$Mode = 'Sample',
    [int]$IntervalSeconds = 10,
    [int]$SummaryMinutes = 1,
    [int]$MaxSamples = 0
)
```

Required behavior:

```text
Snapshot = read once and print/write once
Watch = print continuously without unbounded in-memory accumulation
Sample = collect bounded samples and emit summary files
```

Expected: the tool stops behaving like a perpetual experiment script by default.

- [ ] **Step 3: Make both tools resilient to broken runtime artifacts**

Required cases:

```text
- broken CACHE should not crash the tool
- missing status file should degrade output, not terminate
- missing output dir should be created or return a clear error
```

Expected: status/monitor tools remain usable during failures.

- [ ] **Step 4: Add behavior tests for operator-facing scripts**

Minimum assertions:

```text
- check_status prints unified fields from shared runtime state
- check_status survives invalid CACHE
- monitor snapshot mode writes exactly one record
- monitor sample mode respects MaxSamples
- monitor handles invalid CACHE without terminating on first read
```

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected: operator-facing tooling now has first-class test coverage.

---

### Task 8: Final verification, rollout, and governance checks

**Files:**
- Verify: `scripts/current/*`
- Verify: `configs/*`
- Verify: `docs/*`
- Verify: `tests/*`

- [ ] **Step 1: Run the full repository test suite**

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected: all tests pass.

- [ ] **Step 2: Verify no active code path still hardcodes runtime literals outside the path helper**

Run:

```powershell
rg -n "C:\\FanControl_Auto|D:\\Program Files \(x86\)\\FanControl" scripts/current tests
```

Expected:

```text
- allowed hits: runtime_paths.ps1, narrowly-scoped scheduled-task code, tests that assert defaults
- disallowed hits: duplicated literal path blocks in active scripts
```

- [ ] **Step 3: Verify doc authority and cleaned structure**

Run:

```powershell
rg -n "scripts/production|scripts/legacy" README.md docs scripts SYNC_MEMO.md
Get-ChildItem -Force | Select-Object Name
Get-ChildItem configs | Select-Object Name
```

Expected: docs no longer describe stale structure as current, and config snapshots live under `configs/`.

- [ ] **Step 4: Sync verified active scripts to the runtime mirror**

Run:

```powershell
Copy-Item '.\scripts\current\*' 'C:\FanControl_Auto\' -Force
```

Expected: runtime mirror now matches the verified repo source files.

- [ ] **Step 5: Verify live scheduled-task bindings and runtime/source parity**

Run:

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like 'FanControl-*' } |
  Select-Object TaskName, @{n='Arguments';e={($_.Actions | ForEach-Object Arguments) -join '; '}}

$files = Get-ChildItem '.\scripts\current' -File | Select-Object -ExpandProperty Name
foreach ($f in $files) {
  $repo = Join-Path (Resolve-Path '.\scripts\current') $f
  $live = Join-Path 'C:\FanControl_Auto' $f
  [PSCustomObject]@{
    File = $f
    ExistsInRuntime = Test-Path $live
    SameHash = if (Test-Path $live) { ((Get-FileHash $repo).Hash -eq (Get-FileHash $live).Hash) } else { $false }
  }
}
```

Expected: scheduled tasks still point to `C:\FanControl_Auto\auto_switch.ps1`, and every active source file matches the runtime mirror.

---

## Delivery Order

1. Task 1 first. Do not touch runtime logic before documentation authority is fixed.
2. Task 2 next. Root cleanup should happen before more docs drift accumulates.
3. Tasks 3-5 are the core engineering work and should be done in TDD order.
4. Task 6 follows once shared switch/state/path layers exist.
5. Task 7 depends on the shared runtime state layer.
6. Task 8 is mandatory before declaring the repository hardened.

## Non-Goals

- Do not redesign FanControl behavior or fan curves in this plan.
- Do not add weekend/holiday scheduling yet; only prepare the time policy so that expansion is straightforward.
- Do not change scheduled-task entry filenames during this hardening pass.

## Acceptance Criteria

- A new engineer can identify the single authoritative structure doc in under one minute.
- Active scripts are runnable from repository source using environment overrides, without source rewriting.
- `switch.ps1`, `auto_switch.ps1`, `check_status.ps1`, and `monitor_simple.ps1` all import shared helpers instead of duplicating path/state logic.
- Operator-facing tools continue to function when runtime artifacts are missing or invalid.
- Full test suite passes and includes dedicated coverage for runtime paths, runtime state, check status, monitor behavior, and conflict scenarios.

