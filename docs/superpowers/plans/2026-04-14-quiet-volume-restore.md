# Quiet Volume Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mute system volume when FanControl enters Quiet mode, then restore the saved volume only at the Quiet-exit trigger points (`08:00` and `14:00`).

**Architecture:** Add a small runtime helper that owns saved-volume state under `C:\FanControl_Auto\state`, expose an explicit Quiet-exit minute helper in the time policy, and drive the behavior from `auto_switch.ps1` and manual `switch.ps1 -Mode quiet`. Extend the Pester sandbox with a fake volume backend so tests never touch the real machine volume.

**Tech Stack:** PowerShell, Pester 5, JSON state files

---

### Task 1: Extend the sandbox with fake volume state

**Files:**
- Modify: `D:\Y\others\fancontrol\tests\TestHelpers.ps1`

- [ ] **Step 1: Add sandbox paths for fake volume state and operation logs**

Expose a fake current-volume file, a fake saved-volume file, and a call log inside each test sandbox so runtime scripts can read and write deterministic values.

- [ ] **Step 2: Copy any new runtime helper into the sandbox**

Update the runtime-copy list so the new helper file is available beside `auto_switch.ps1` and `switch.ps1`.

### Task 2: Add failing tests for Quiet volume behavior

**Files:**
- Modify: `D:\Y\others\fancontrol\tests\FanControl.AutoSwitchSandbox.Tests.ps1`
- Modify: `D:\Y\others\fancontrol\tests\FanControl.SwitchSandbox.Tests.ps1`

- [ ] **Step 1: Add an auto-switch test for entering Quiet**

Cover the exact force point path (`12:40` or `21:00`) and assert that the script saves the previous volume and sets the current volume to `0`.

- [ ] **Step 2: Add an auto-switch test for exiting Quiet**

Cover the exact exit points (`08:00` and `14:00`) and assert that the script restores the saved volume and clears the saved-volume state.

- [ ] **Step 3: Add a manual switch test for `-Mode quiet`**

Assert that manual Quiet writes the override flag, saves the previous volume, and sets the fake current volume to `0`.

- [ ] **Step 4: Run the targeted tests and confirm they fail for the missing feature**

Run:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path '.\tests\FanControl.AutoSwitchSandbox.Tests.ps1','.\tests\FanControl.SwitchSandbox.Tests.ps1' -Output Detailed"
```

Expected: the new tests fail because no volume helper or Quiet volume logic exists yet.

### Task 3: Implement the minimal runtime logic

**Files:**
- Create: `D:\Y\others\fancontrol\scripts\current\volume_helper.ps1`
- Modify: `D:\Y\others\fancontrol\scripts\current\time_policy.ps1`
- Modify: `D:\Y\others\fancontrol\scripts\current\auto_switch.ps1`
- Modify: `D:\Y\others\fancontrol\scripts\current\switch.ps1`

- [ ] **Step 1: Add a focused helper for save/mute/restore behavior**

Implement helper functions that read the current volume, persist the saved volume only when needed, mute to `0`, restore on demand, and clear saved state after a successful restore.

- [ ] **Step 2: Add a Quiet-exit minute helper**

Expose `Test-IsQuietExitPointMinute` so `auto_switch.ps1` can distinguish Quiet-entry force points from Quiet-exit restore points.

- [ ] **Step 3: Wire the helper into `auto_switch.ps1`**

Mute when entering Quiet at the force points and restore when hitting `08:00` or `14:00`, while keeping normal auto mode and manual `-Mode auto` behavior unchanged.

- [ ] **Step 4: Wire the helper into `switch.ps1`**

Make `switch.ps1 -Mode quiet` save and mute volume before applying the Quiet config.

### Task 4: Verify and sync

**Files:**
- Verify: `D:\Y\others\fancontrol\tests\Invoke-FanControlTests.ps1`
- Sync: `C:\FanControl_Auto\auto_switch.ps1`
- Sync: `C:\FanControl_Auto\switch.ps1`
- Sync: `C:\FanControl_Auto\time_policy.ps1`
- Sync: `C:\FanControl_Auto\volume_helper.ps1`

- [ ] **Step 1: Re-run the full test suite**

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected: all tests pass, including the new Quiet volume coverage.

- [ ] **Step 2: Sync the active runtime scripts**

Run:

```powershell
Copy-Item '.\scripts\current\auto_switch.ps1' 'C:\FanControl_Auto\auto_switch.ps1' -Force
Copy-Item '.\scripts\current\switch.ps1' 'C:\FanControl_Auto\switch.ps1' -Force
Copy-Item '.\scripts\current\time_policy.ps1' 'C:\FanControl_Auto\time_policy.ps1' -Force
Copy-Item '.\scripts\current\volume_helper.ps1' 'C:\FanControl_Auto\volume_helper.ps1' -Force
```

Expected: live runtime matches the repository source-of-truth.
