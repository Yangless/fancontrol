# FanControl Runtime Layout Sync Design

**Date:** 2026-04-14

## Goal

Reorganize both `C:\FanControl_Auto` and `D:\Y\others\fancontrol` so it is immediately clear which scripts are:

- currently running in production
- the next scripts being iterated
- historical or superseded

The live Windows scheduled tasks must continue to call `C:\FanControl_Auto\auto_switch.ps1` without any task-path change.

## Confirmed Current State

- Windows scheduled tasks `FanControl-*` currently execute:
  - `powershell.exe -File "C:\FanControl_Auto\auto_switch.ps1"`
- The following live/runtime scripts are identical to the repository `scripts/production` copies:
  - `auto_switch.ps1`
  - `switch.ps1`
  - `check_status.ps1`
  - `monitor_simple.ps1`
  - `fix_startup_logon.ps1`
- `C:\FanControl_Auto` also contains multiple older scripts, migration helpers, monitor experiments, XML exports, and timestamped backups.

## Design Decision

Use **stable live entry names + layered directories**.

### Why

- Scheduled tasks and manual usage already depend on the current root entry names.
- Changing the task target now adds risk without adding real value.
- Moving non-live files out of the root is enough to make the runtime directory understandable.

## Target Layout

### Runtime directory: `C:\FanControl_Auto`

Root keeps only the active runtime entry files plus runtime data directories:

```text
C:\FanControl_Auto\
├── auto_switch.ps1
├── switch.ps1
├── check_status.ps1
├── monitor_simple.ps1
├── fix_startup_logon.ps1
├── RUNTIME_LAYOUT_MEMO.md
├── history\
│   ├── scripts\
│   ├── deployment\
│   ├── monitoring\
│   ├── task_xml\
│   └── backups\
├── iterating\
├── logs\
├── monitor_data\
└── state\
```

Rules:

- Root means "actively used by the system now".
- `iterating\` means "candidate scripts not yet promoted to runtime root".
- `history\` means "do not execute unless intentionally revisiting history".

### Repository directory: `D:\Y\others\fancontrol\scripts`

```text
scripts\
├── current\
├── iterating\
├── history\
└── tools\
```

Rules:

- `current\` is the source of truth for the live runtime scripts.
- `iterating\` is where the next edited version is prepared before promotion.
- `history\` stores retired versions and older helpers.
- `tools\` keeps XML/task/deployment reference artifacts and non-runtime utilities.

## Classification Policy

### Active runtime files

Remain in runtime root and in repository `scripts\current\`:

- `auto_switch.ps1`
- `switch.ps1`
- `check_status.ps1`
- `monitor_simple.ps1`
- `fix_startup_logon.ps1`

### Iteration files

Place only future candidates here. No current file is moved into `iterating\` during this cleanup unless it is explicitly a work-in-progress variant.

### Historical files

These are historical and should leave the runtime root:

- `auto_switch_enhanced.ps1`
- `auto_switch_fixed.ps1`
- `switch_fixed.ps1`
- `deploy_enhanced.ps1`
- `deploy_fixed.ps1`
- `deploy_startup.ps1`
- `deploy_tasks.ps1`
- `fix_startup_delay.ps1`
- `fix_startup_task.ps1`
- `monitor.ps1`
- `start_monitor.ps1`
- `test_time_logic.ps1`
- `startup_task.xml`
- `startup_task_export.xml`
- `startup_task_fixed.xml`
- `backup_*`

## Naming Rules

- Keep active runtime filenames stable and simple.
- Put meaning in the directory first, not in a long filename.
- New candidates in `iterating\` should use a purpose suffix, for example:
  - `auto_switch_force-fix.ps1`
  - `auto_switch_v3_3_candidate.ps1`
- Do not create another `*_fixed.ps1` or `*_enhanced.ps1` in the runtime root.

## Sync Workflow

`D:\Y\others\fancontrol` is the editable source repository.

`C:\FanControl_Auto` is the deployed runtime copy.

Required workflow:

1. Edit repository files in `scripts\current\` or `scripts\iterating\`.
2. Verify behavior from the repository copy first where practical.
3. Promote verified files to `C:\FanControl_Auto\` root only when they are intended to be live.
4. Keep the same active set in both places:
   - repo source: `scripts\current\`
   - runtime copy: `C:\FanControl_Auto\`

## Memo Requirements

Create a human-readable memo that states:

- which path is the live runtime directory
- which repository directory is the source of truth
- which folders mean current / iterating / history
- the exact copy command to sync from `D:` to `C:`
- a warning not to casually edit runtime root files first

## Guardrails

- Do not rename or relocate the live runtime root entry files in a way that breaks scheduled tasks.
- Do not delete runtime logs, state, or monitor data during this cleanup.
- Historical scripts may be moved but not destroyed.
- If a file's role is ambiguous, prefer moving it into `history\` rather than leaving it in the runtime root.

## Implementation Scope

This cleanup includes:

- directory creation
- file moves for clear classification
- repository layout synchronization
- documentation updates for the new layout
- a runtime sync memo in both locations if useful

This cleanup does not include:

- changing scheduled task targets
- fixing the separate `auto_switch.ps1` runtime logic bug
- changing FanControl JSON configurations
