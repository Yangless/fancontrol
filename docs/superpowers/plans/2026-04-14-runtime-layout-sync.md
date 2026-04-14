# Runtime Layout Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the repository and runtime directories so active, iterating, and historical FanControl scripts are clearly separated without changing the live scheduled-task entrypoint.

**Architecture:** Keep `C:\FanControl_Auto\auto_switch.ps1` and the other active runtime files at the runtime root, move non-live runtime files into `history\`, and make `D:\Y\others\fancontrol\scripts\current\` the source-of-truth mirror for active scripts. Add sync memos and update docs to reflect the new structure and workflow.

**Tech Stack:** PowerShell, Windows Scheduled Tasks, Markdown documentation, filesystem moves/copies

---

### Task 1: Create target directories in the repository

**Files:**
- Create: `D:\Y\others\fancontrol\scripts\current\`
- Create: `D:\Y\others\fancontrol\scripts\iterating\`
- Create: `D:\Y\others\fancontrol\scripts\history\`

- [ ] **Step 1: Create the new repository script directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path `
  'D:\Y\others\fancontrol\scripts\current', `
  'D:\Y\others\fancontrol\scripts\iterating', `
  'D:\Y\others\fancontrol\scripts\history' | Out-Null
```

Expected: directories exist with no error.

- [ ] **Step 2: Verify the directories exist**

Run:

```powershell
Get-ChildItem 'D:\Y\others\fancontrol\scripts' -Directory |
  Select-Object Name
```

Expected: output includes `current`, `iterating`, `history`, and `tools`.

### Task 2: Promote repository active scripts and archive old groups

**Files:**
- Create: `D:\Y\others\fancontrol\scripts\current\auto_switch.ps1`
- Create: `D:\Y\others\fancontrol\scripts\current\switch.ps1`
- Create: `D:\Y\others\fancontrol\scripts\current\check_status.ps1`
- Create: `D:\Y\others\fancontrol\scripts\current\monitor_simple.ps1`
- Create: `D:\Y\others\fancontrol\scripts\current\fix_startup_logon.ps1`
- Move: `D:\Y\others\fancontrol\scripts\production\*`
- Move: `D:\Y\others\fancontrol\scripts\legacy\*`

- [ ] **Step 1: Copy active scripts from `production` into `current`**

Run:

```powershell
Copy-Item `
  'D:\Y\others\fancontrol\scripts\production\auto_switch.ps1', `
  'D:\Y\others\fancontrol\scripts\production\switch.ps1', `
  'D:\Y\others\fancontrol\scripts\production\check_status.ps1', `
  'D:\Y\others\fancontrol\scripts\production\monitor_simple.ps1', `
  'D:\Y\others\fancontrol\scripts\production\fix_startup_logon.ps1' `
  -Destination 'D:\Y\others\fancontrol\scripts\current' -Force
```

Expected: five active scripts now exist in `scripts\current\`.

- [ ] **Step 2: Move all legacy scripts into `scripts\history\legacy_snapshot`**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'D:\Y\others\fancontrol\scripts\history\legacy_snapshot' | Out-Null
Move-Item 'D:\Y\others\fancontrol\scripts\legacy\*' 'D:\Y\others\fancontrol\scripts\history\legacy_snapshot\'
```

Expected: `scripts\legacy\` becomes empty and all previous legacy files are preserved under `history\legacy_snapshot\`.

- [ ] **Step 3: Move the old `production` directory into `scripts\history\production_snapshot_2026-04-13`**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'D:\Y\others\fancontrol\scripts\history\production_snapshot_2026-04-13' | Out-Null
Move-Item 'D:\Y\others\fancontrol\scripts\production\*' 'D:\Y\others\fancontrol\scripts\history\production_snapshot_2026-04-13\'
```

Expected: `scripts\production\` becomes empty and the previous production snapshot is preserved in `history\`.

- [ ] **Step 4: Verify current script set**

Run:

```powershell
Get-ChildItem 'D:\Y\others\fancontrol\scripts\current' -File |
  Select-Object Name
```

Expected: exactly the five active runtime scripts are listed.

### Task 3: Update repository documentation and add the sync memo

**Files:**
- Modify: `D:\Y\others\fancontrol\README.md`
- Modify: `D:\Y\others\fancontrol\scripts\README.md`
- Add: `D:\Y\others\fancontrol\SYNC_MEMO.md`

- [ ] **Step 1: Update documentation to reference `scripts\current`, `scripts\iterating`, and `scripts\history`**

Change the docs so:

```text
scripts\current\   = active source-of-truth
scripts\iterating\ = work in progress
scripts\history\   = retired snapshots
```

Expected: old references that imply `scripts\production` is the live source are removed or rewritten.

- [ ] **Step 2: Add a sync memo for the repository**

Create `D:\Y\others\fancontrol\SYNC_MEMO.md` with:

```markdown
# FanControl Sync Memo

- Live runtime path: `C:\FanControl_Auto`
- Source-of-truth path: `D:\Y\others\fancontrol\scripts\current`
- `scripts\iterating\` holds candidate scripts not yet deployed
- `scripts\history\` holds retired versions and snapshots

## Required workflow

1. Edit `D:\Y\others\fancontrol\scripts\current\` or `scripts\iterating\`
2. Verify the change
3. Sync the active files to `C:\FanControl_Auto`

## Sync command

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```

## Warning

Do not treat `C:\FanControl_Auto` as the primary editing location unless doing an emergency hotfix.
After any hotfix in `C:\FanControl_Auto`, copy the final version back into `D:\Y\others\fancontrol\scripts\current\`.
```

Expected: the memo exists and clearly explains the source/deploy split.

### Task 4: Reorganize the runtime directory without changing live entry filenames

**Files:**
- Create: `C:\FanControl_Auto\history\scripts\`
- Create: `C:\FanControl_Auto\history\deployment\`
- Create: `C:\FanControl_Auto\history\monitoring\`
- Create: `C:\FanControl_Auto\history\task_xml\`
- Create: `C:\FanControl_Auto\history\backups\`
- Create: `C:\FanControl_Auto\iterating\`
- Move: historical runtime scripts and XML files from `C:\FanControl_Auto\`

- [ ] **Step 1: Create runtime history and iteration directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path `
  'C:\FanControl_Auto\history\scripts', `
  'C:\FanControl_Auto\history\deployment', `
  'C:\FanControl_Auto\history\monitoring', `
  'C:\FanControl_Auto\history\task_xml', `
  'C:\FanControl_Auto\history\backups', `
  'C:\FanControl_Auto\iterating' | Out-Null
```

Expected: all target directories are created.

- [ ] **Step 2: Move historical runtime scripts into categorized history folders**

Run:

```powershell
Move-Item `
  'C:\FanControl_Auto\auto_switch_enhanced.ps1', `
  'C:\FanControl_Auto\auto_switch_fixed.ps1', `
  'C:\FanControl_Auto\switch_fixed.ps1', `
  'C:\FanControl_Auto\test_time_logic.ps1' `
  -Destination 'C:\FanControl_Auto\history\scripts' -Force

Move-Item `
  'C:\FanControl_Auto\deploy_enhanced.ps1', `
  'C:\FanControl_Auto\deploy_fixed.ps1', `
  'C:\FanControl_Auto\deploy_startup.ps1', `
  'C:\FanControl_Auto\deploy_tasks.ps1', `
  'C:\FanControl_Auto\fix_startup_delay.ps1', `
  'C:\FanControl_Auto\fix_startup_task.ps1' `
  -Destination 'C:\FanControl_Auto\history\deployment' -Force

Move-Item `
  'C:\FanControl_Auto\monitor.ps1', `
  'C:\FanControl_Auto\start_monitor.ps1' `
  -Destination 'C:\FanControl_Auto\history\monitoring' -Force

Move-Item `
  'C:\FanControl_Auto\startup_task.xml', `
  'C:\FanControl_Auto\startup_task_export.xml', `
  'C:\FanControl_Auto\startup_task_fixed.xml' `
  -Destination 'C:\FanControl_Auto\history\task_xml' -Force
```

Expected: runtime root keeps only active scripts, docs, and runtime data directories.

- [ ] **Step 3: Move timestamped runtime backups into `history\backups`**

Run:

```powershell
Move-Item 'C:\FanControl_Auto\backup_*' 'C:\FanControl_Auto\history\backups\'
```

Expected: timestamped backup folders are preserved under `history\backups\`.

- [ ] **Step 4: Add a runtime memo**

Create `C:\FanControl_Auto\RUNTIME_LAYOUT_MEMO.md` with:

```markdown
# FanControl Runtime Layout Memo

- This directory is the live deployed runtime location.
- Active scripts stay at the root because Windows scheduled tasks call them directly.
- History lives under `history\`.
- Candidates for the next deployment belong in `iterating\`.

## Active root files

- `auto_switch.ps1`
- `switch.ps1`
- `check_status.ps1`
- `monitor_simple.ps1`
- `fix_startup_logon.ps1`

## Source-of-truth

Edit scripts in `D:\Y\others\fancontrol\scripts\current\` first.

## Deployment sync command

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```
```

Expected: the runtime directory explains itself to the next person who opens it.

### Task 5: Verify the live layout and task bindings

**Files:**
- Verify: `C:\FanControl_Auto\auto_switch.ps1`
- Verify: `D:\Y\others\fancontrol\scripts\current\auto_switch.ps1`
- Verify: scheduled tasks `FanControl-*`

- [ ] **Step 1: Verify runtime root active files**

Run:

```powershell
Get-ChildItem 'C:\FanControl_Auto' -File |
  Select-Object Name
```

Expected: active runtime scripts remain at the root together with memo/doc files only.

- [ ] **Step 2: Verify repository source-of-truth active files**

Run:

```powershell
Get-ChildItem 'D:\Y\others\fancontrol\scripts\current' -File |
  Select-Object Name
```

Expected: the same active script set exists in `scripts\current\`.

- [ ] **Step 3: Verify scheduled tasks still target the root runtime script**

Run:

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like 'FanControl-*' } |
  Select-Object TaskName, @{n='Arguments';e={($_.Actions | ForEach-Object Arguments) -join '; '}}
```

Expected: every task still points to `"C:\FanControl_Auto\auto_switch.ps1"`.

- [ ] **Step 4: Verify active source and runtime copies still match**

Run:

```powershell
$files = 'auto_switch.ps1','switch.ps1','check_status.ps1','monitor_simple.ps1','fix_startup_logon.ps1'
foreach ($f in $files) {
  $repo = Join-Path 'D:\Y\others\fancontrol\scripts\current' $f
  $live = Join-Path 'C:\FanControl_Auto' $f
  [PSCustomObject]@{
    File = $f
    Same = ((Get-FileHash $repo).Hash -eq (Get-FileHash $live).Hash)
  }
}
```

Expected: all rows show `Same = True`.
