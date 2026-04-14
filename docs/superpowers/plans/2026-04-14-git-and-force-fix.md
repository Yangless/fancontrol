# Git Setup And Force Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize a Git repository, preserve the user's requested four-commit history, and then fix the `switch.ps1 -Mode auto` regression with a failing test first.

**Architecture:** Use Git to snapshot the already-completed layout cleanup in separate commits for repository initialization, file reorganization, and documentation. For the bugfix, add a small PowerShell regression test that proves `-Mode auto` should calibrate to the current time period instead of always forcing Quiet mode, then implement the smallest fix in the active scripts and sync to the runtime copy.

**Tech Stack:** Git, PowerShell, Markdown documentation

---

### Task 1: Initialize Git and create the first commit

**Files:**
- Create: `D:\Y\others\fancontrol\.git\`

- [ ] **Step 1: Initialize the repository**

Run:

```powershell
git init
```

Expected: `.git` is created and Git prints the initialization message.

- [ ] **Step 2: Stage only Git bootstrap metadata**

Run:

```powershell
git add .
git reset HEAD .
```

Expected: the index is cleared so later commits can be staged deliberately.

- [ ] **Step 3: Create the initialization commit**

Run:

```powershell
git commit --allow-empty -m "chore: initialize git repository"
```

Expected: one root commit exists even if no files are staged yet.

### Task 2: Commit the directory reorganization only

**Files:**
- Add: `D:\Y\others\fancontrol\scripts\current\*`
- Add: `D:\Y\others\fancontrol\scripts\history\*`
- Add: `D:\Y\others\fancontrol\scripts\iterating\`
- Add: `D:\Y\others\fancontrol\scripts\tools\FanControl_Task.xml`
- Delete: pre-reorganization script paths that no longer exist in their old locations

- [ ] **Step 1: Stage only the layout changes**

Run:

```powershell
git add scripts
git reset HEAD scripts\README.md
```

Expected: only moved and created script/layout paths remain staged.

- [ ] **Step 2: Review staged paths**

Run:

```powershell
git diff --cached --name-status
```

Expected: staged output contains the script moves/new directories but not root docs like `README.md` or `SYNC_MEMO.md`.

- [ ] **Step 3: Commit the layout change**

Run:

```powershell
git commit -m "refactor: reorganize repository layout"
```

Expected: commit contains the script structure split without the doc-only updates.

### Task 3: Commit docs and memo updates only

**Files:**
- Modify: `D:\Y\others\fancontrol\README.md`
- Modify: `D:\Y\others\fancontrol\docs\README_CONSOLIDATED.md`
- Modify: `D:\Y\others\fancontrol\docs\PROJECT_STRUCTURE.md`
- Modify: `D:\Y\others\fancontrol\scripts\README.md`
- Add: `D:\Y\others\fancontrol\SYNC_MEMO.md`
- Add: `D:\Y\others\fancontrol\docs\superpowers\specs\2026-04-14-runtime-layout-sync-design.md`
- Add: `D:\Y\others\fancontrol\docs\superpowers\plans\2026-04-14-runtime-layout-sync.md`

- [ ] **Step 1: Stage the documentation paths**

Run:

```powershell
git add README.md docs scripts\README.md SYNC_MEMO.md
```

Expected: doc and memo changes are staged.

- [ ] **Step 2: Verify only docs are staged**

Run:

```powershell
git diff --cached --name-status
```

Expected: staged output is documentation/memo/spec/plan content only.

- [ ] **Step 3: Commit the docs split**

Run:

```powershell
git commit -m "docs: add layout memo and update structure docs"
```

Expected: commit contains the explanatory docs and memos but no new code logic changes.

### Task 4: Add the failing regression test for auto-restore behavior

**Files:**
- Create: `D:\Y\others\fancontrol\scripts\iterating\test_auto_restore_logic.ps1`

- [ ] **Step 1: Write a failing regression test script**

Create a PowerShell test script that:

- extracts the active runtime logic from `scripts\current\auto_switch.ps1`
- simulates daytime, non-force-point behavior
- asserts that the auto-restore calibration should target `Game.json`
- fails against current logic because the `-Force` path forces `Quiet_mode.json`

- [ ] **Step 2: Run the regression test and confirm it fails for the expected reason**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\Y\others\fancontrol\scripts\iterating\test_auto_restore_logic.ps1"
```

Expected: exit code `1` and output showing the current behavior incorrectly resolves to `Quiet_mode.json` for auto-restore calibration.

### Task 5: Implement the minimal fix and sync the runtime copy

**Files:**
- Modify: `D:\Y\others\fancontrol\scripts\current\auto_switch.ps1`
- Modify: `D:\Y\others\fancontrol\scripts\current\switch.ps1`
- Modify: `C:\FanControl_Auto\auto_switch.ps1`
- Modify: `C:\FanControl_Auto\switch.ps1`

- [ ] **Step 1: Implement the minimal fix in repository source files**

Change the logic so:

- forced Quiet remains limited to the real force points (`12:40`, `21:00`)
- `switch.ps1 -Mode auto` restores automatic mode and calibrates to the current time period instead of invoking the force-Quiet path

- [ ] **Step 2: Sync the active scripts to the runtime root**

Run:

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\auto_switch.ps1" "C:\FanControl_Auto\auto_switch.ps1" -Force
Copy-Item "D:\Y\others\fancontrol\scripts\current\switch.ps1" "C:\FanControl_Auto\switch.ps1" -Force
```

Expected: runtime copies match repository source.

### Task 6: Verify the fix and create the fourth commit

**Files:**
- Verify: `D:\Y\others\fancontrol\scripts\iterating\test_auto_restore_logic.ps1`
- Verify: `D:\Y\others\fancontrol\scripts\current\auto_switch.ps1`
- Verify: `D:\Y\others\fancontrol\scripts\current\switch.ps1`

- [ ] **Step 1: Re-run the regression test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\Y\others\fancontrol\scripts\iterating\test_auto_restore_logic.ps1"
```

Expected: exit code `0` and output confirming daytime auto-restore resolves to `Game.json`.

- [ ] **Step 2: Verify the runtime copies still match the repository copies**

Run:

```powershell
$files = 'auto_switch.ps1','switch.ps1'
$files | ForEach-Object {
  $repo = Join-Path 'D:\Y\others\fancontrol\scripts\current' $_
  $live = Join-Path 'C:\FanControl_Auto' $_
  [PSCustomObject]@{
    File = $_
    Same = ((Get-FileHash $repo).Hash -eq (Get-FileHash $live).Hash)
  }
}
```

Expected: both rows show `Same = True`.

- [ ] **Step 3: Stage only the bugfix and regression test**

Run:

```powershell
git add scripts\current\auto_switch.ps1 scripts\current\switch.ps1 scripts\iterating\test_auto_restore_logic.ps1
```

Expected: only the bugfix code and regression test are staged.

- [ ] **Step 4: Commit the bugfix**

Run:

```powershell
git commit -m "fix: restore auto mode without forcing quiet"
```

Expected: the fourth commit contains the test-first regression and the minimal code fix.
