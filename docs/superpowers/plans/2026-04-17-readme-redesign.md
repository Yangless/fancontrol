# README Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the repository homepage into a high-level open-source README, add an English README entrypoint, and keep the model-assisted config-tuning roadmap prominently visible.

**Architecture:** Keep `README.md` as the Chinese-first project homepage and add `README.en.md` as a lightweight English mirror with matching structure. Move operational depth out of the homepage by linking to existing docs instead of repeating long script, scheduling, and troubleshooting details.

**Tech Stack:** Markdown, GitHub README conventions, PowerShell verification commands

---

## File structure

- `D:\Y\others\fancontrol\README.md`
  - Chinese-first project homepage
  - Keeps badges, project overview, quick start, architecture summary, roadmap, and doc navigation
- `D:\Y\others\fancontrol\README.en.md`
  - English-facing mirror of the homepage
  - Links back to the Chinese README
  - Marks detailed docs as Chinese when needed
- Existing docs remain the detailed sources of truth and are only linked, not rewritten:
  - `D:\Y\others\fancontrol\docs\PROJECT_STRUCTURE.md`
  - `D:\Y\others\fancontrol\scripts\README.md`
  - `D:\Y\others\fancontrol\docs\CONFIG_ANALYSIS.md`
  - `D:\Y\others\fancontrol\docs\CONFIG_ITERATION_GUIDE.md`
  - `D:\Y\others\fancontrol\docs\README_CONSOLIDATED.md`
  - `D:\Y\others\fancontrol\archive\README.md`

### Task 1: Rewrite the Chinese homepage README

**Files:**
- Modify: `D:\Y\others\fancontrol\README.md`
- Reference: `D:\Y\others\fancontrol\docs\PROJECT_STRUCTURE.md`
- Reference: `D:\Y\others\fancontrol\docs\CONFIG_ANALYSIS.md`
- Reference: `D:\Y\others\fancontrol\docs\CONFIG_ITERATION_GUIDE.md`
- Reference: `D:\Y\others\fancontrol\scripts\README.md`

- [ ] **Step 1: Write the failing README structure check**

Run:

```powershell
pwsh -NoProfile -Command "
$patterns = @(
  '^\[English\]\(\./README\.en\.md\)$',
  '^## 项目概述$',
  '^## 为什么有这个仓库$',
  '^## 当前能力$',
  '^## 架构概览$',
  '^## 当前状态$',
  '^## 正在进行$',
  '^## 下一步$',
  '^## 文档导航$'
)
foreach ($pattern in $patterns) {
  if (Select-String -Path 'D:/Y/others/fancontrol/README.md' -Pattern $pattern -Quiet) {
    Write-Output "FOUND $pattern"
  } else {
    Write-Output "MISSING $pattern"
  }
}
"
```

Expected: at least the English switch link and the new roadmap/navigation headings report as `MISSING`.

- [ ] **Step 2: Run the check and confirm the current README fails it**

Run the command from Step 1.

Expected: several required headings are missing because the current README is still the older handbook-style homepage.

- [ ] **Step 3: Replace `README.md` with the new Chinese homepage content**

Write this file content:

```markdown
# FanControl 自动化配置切换系统

[English](./README.en.md)

[![Test](https://github.com/Yangless/fancontrol/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/Yangless/fancontrol/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 面向 Windows + FanControl 的自动化配置切换仓库，支持按时段切换、登录触发、手动覆盖、运行期验证，并持续推进通过模型自动调整配置曲线参数的调优工作流。

## 项目概述

这个仓库把个人 FanControl 使用流程整理成一套更可维护的 Windows 自动化方案。它不只是“定时切配置”，还同时处理登录场景启动、手动免打扰、强制恢复、状态观测和运行期验证。

当前仓库的角色已经从单机脚本集合，演进为一个有清晰 source/runtime 边界、可测试、可维护、可继续扩展的自动化项目。

## 为什么有这个仓库

FanControl 本身能够加载配置，但不负责“按时段自动切换 + 手动覆盖 + 自动恢复 + 验证配置是否真的生效”这一整套调度与维护问题。

这个仓库补齐的是这层自动化与治理能力：

- 让日常切换不依赖手工操作
- 让临时手动切换不会永久破坏自动调度
- 让运行结果可观察、可验证，而不是只依赖“脚本执行过了”的假设
- 让配置优化和后续调参有明确的项目入口

## 当前能力

- 按时间窗口自动切换 `Game.json` / `Quiet_mode.json`
- 登录后自动启动 FanControl 并应用当前应使用的配置
- 通过 `switch.ps1` 支持手动切换与恢复自动调度
- 在 12:40 和 21:00 提供强制恢复点，避免长期停留在手动覆盖状态
- 通过状态文件、日志和观察脚本验证配置切换是否实际生效
- 将仓库源码目录与运行目录分离，降低直接改 runtime 的维护风险

## 架构概览

当前仓库按“源码权威目录 / 运行副本 / 配置快照”三层组织：

- `scripts/current/`：当前活跃脚本的 repo source of truth
- `C:\FanControl_Auto\`：任务计划程序直接调用的 runtime mirror
- `configs/`：仓库跟踪中的 FanControl 配置快照

当前两套主配置的语义也已经比较明确：

- `Game.json`：FanControl 主动接管风扇控制
- `Quiet_mode.json`：FanControl 退出主动控制，回到 BIOS / EC / GPU 默认策略

自动调度与手动切换共享同一套运行期状态与切换核心，因此当前项目重点已经从“先跑起来”转向“让行为更稳定、更可解释、更容易继续调优”。

## 快速开始

运行测试：

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

快速定位主要入口：

- 当前源码入口：`scripts/current/`
- 当前配置快照：`configs/`
- 当前运行副本：`C:\FanControl_Auto\`
- 脚本说明：[`scripts/README.md`](./scripts/README.md)
- 仓库结构说明：[`docs/PROJECT_STRUCTURE.md`](./docs/PROJECT_STRUCTURE.md)

如果你想直接理解配置逻辑与后续调优背景，优先阅读：

- [`docs/CONFIG_ANALYSIS.md`](./docs/CONFIG_ANALYSIS.md)
- [`docs/CONFIG_ITERATION_GUIDE.md`](./docs/CONFIG_ITERATION_GUIDE.md)

## 仓库结构

```text
fancontrol/
├── README.md
├── README.en.md
├── configs/                    # 跟踪中的 FanControl 配置快照
├── docs/                       # 结构说明、配置分析、计划与索引
├── scripts/
│   ├── current/                # 当前活跃脚本源码
│   ├── iterating/              # 候选脚本与实验迭代
│   ├── history/                # 历史快照与旧入口
│   └── README.md               # 脚本目录说明
├── tests/                      # Pester 测试
└── archive/                    # 历史报告与阶段性文档
```

更完整的目录说明请看 [`docs/PROJECT_STRUCTURE.md`](./docs/PROJECT_STRUCTURE.md)。

## 当前状态

- 自动切换链路已经可以稳定运行在当前 Windows + FanControl 环境中
- 手动 override、强制恢复点、状态写入和验证链路已经形成闭环
- runtime/source 分层已经明确，日常维护不再依赖直接编辑运行目录
- 配置分析文档和迭代指南已经具备，后续调优有了可持续积累的入口

## 正在进行

当前最值得关注的方向是：**通过模型自动调整 `config` 中各项曲线参数。**

这项工作不是简单“让模型改 JSON”，而是建立一个更可靠的调优工作流：

- 分析当前 `Game.json` 及相关配置在真实使用下的行为
- 把已有配置分析、采样观察和曲线调整串成可复用流程
- 让参数优化具备可观察、可回退、可比较的基础
- 逐步从人工经验调参过渡到模型辅助参数建议

## 下一步

- 定义更明确的噪音 / 散热平衡指标
- 对比候选曲线方案与实际采样结果
- 把当前文档化的配置分析转成更系统的调优输入
- 推进半自动、可审查的配置参数优化流程

## 文档导航

| 主题 | 文档 |
|---|---|
| 仓库结构 | [`docs/PROJECT_STRUCTURE.md`](./docs/PROJECT_STRUCTURE.md) |
| 脚本说明 | [`scripts/README.md`](./scripts/README.md) |
| 配置分析 | [`docs/CONFIG_ANALYSIS.md`](./docs/CONFIG_ANALYSIS.md) |
| 配置迭代指南 | [`docs/CONFIG_ITERATION_GUIDE.md`](./docs/CONFIG_ITERATION_GUIDE.md) |
| 文档索引 | [`docs/README_CONSOLIDATED.md`](./docs/README_CONSOLIDATED.md) |
| 历史报告 | [`archive/README.md`](./archive/README.md) |

## License

本项目采用 [MIT License](./LICENSE) 开源。
```

- [ ] **Step 4: Run the structure check again and confirm it passes**

Run the command from Step 1.

Expected: every required heading and the English switch link now report as `FOUND`.

- [ ] **Step 5: Commit the Chinese README rewrite**

Run:

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: redesign Chinese README homepage

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

Expected: one commit records the new Chinese-first homepage layout.

### Task 2: Add the English README mirror

**Files:**
- Create: `D:\Y\others\fancontrol\README.en.md`
- Reference: `D:\Y\others\fancontrol\README.md`

- [ ] **Step 1: Write the failing existence and heading check for the English README**

Run:

```powershell
pwsh -NoProfile -Command "
if (Test-Path 'D:/Y/others/fancontrol/README.en.md') {
  Write-Output 'README.en.md exists'
  $patterns = @(
    '^\[中文\]\(\./README\.md\)$',
    '^## Overview$',
    '^## Why this repository exists$',
    '^## Current capabilities$',
    '^## Architecture at a glance$',
    '^## Current status$',
    '^## In progress$',
    '^## Next$',
    '^## Documentation$'
  )
  foreach ($pattern in $patterns) {
    if (Select-String -Path 'D:/Y/others/fancontrol/README.en.md' -Pattern $pattern -Quiet) {
      Write-Output "FOUND $pattern"
    } else {
      Write-Output "MISSING $pattern"
    }
  }
} else {
  Write-Output 'README.en.md missing'
}
"
```

Expected: output is `README.en.md missing`.

- [ ] **Step 2: Run the check and confirm the file does not exist yet**

Run the command from Step 1.

Expected: the repository has no `README.en.md` yet.

- [ ] **Step 3: Create `README.en.md` with the English-facing summary**

Write this file content:

```markdown
# FanControl Automation for Windows

[中文](./README.md)

[![Test](https://github.com/Yangless/fancontrol/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/Yangless/fancontrol/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> A Windows + FanControl automation repository for scheduled profile switching, logon-triggered startup, manual override, runtime verification, and an evolving workflow for model-assisted curve tuning.

## Overview

This repository turns a personal FanControl automation workflow into a more maintainable Windows automation project. It covers scheduled profile switching, logon startup behavior, manual override, verification, and status visibility instead of treating the setup as a one-off script bundle.

## Why this repository exists

FanControl can load configurations, but it does not provide the full layer needed for time-based switching, temporary manual override, forced recovery points, and verification that the expected config actually became effective.

This repository fills that gap by providing:

- repeatable automation around daily profile switching
- manual intervention without permanently breaking automation
- runtime observability instead of assuming a switch succeeded
- a project entrypoint for ongoing tuning and config evolution

## Current capabilities

- time-based switching between `Game.json` and `Quiet_mode.json`
- logon-triggered startup and config application
- manual override through `switch.ps1`
- forced recovery points at 12:40 and 21:00
- runtime verification through logs, status files, and observer scripts
- separation between repository source and deployed runtime copy

## Architecture at a glance

The repository is organized around three layers:

- `scripts/current/` — source of truth for active scripts
- `C:\FanControl_Auto\` — deployed runtime mirror called by Windows Scheduled Tasks
- `configs/` — tracked FanControl config snapshots

The current config semantics are intentionally distinct:

- `Game.json` means FanControl actively controls fans
- `Quiet_mode.json` means FanControl gives control back to BIOS / EC / GPU defaults

## Quick start

Run the test suite:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Primary entrypoints:

- Active scripts: `scripts/current/`
- Config snapshots: `configs/`
- Runtime mirror: `C:\FanControl_Auto\`

## Current status

- the main switching workflow is stable in the current Windows + FanControl environment
- manual override, forced recovery, state output, and verification already form a usable loop
- source/runtime separation is now explicit
- config analysis and iteration docs exist, so future tuning work has a documented base

## In progress

The most important active direction is **model-assisted tuning of config curve parameters**.

That means building a safer workflow around:

- understanding how the current `Game.json` behavior performs in real usage
- connecting config analysis, observation, and curve changes into a reusable loop
- keeping tuning observable, reviewable, and reversible
- moving gradually from manual tuning to model-assisted parameter suggestions

## Next

- define clearer noise-versus-cooling tuning targets
- compare candidate curve sets against observed runtime behavior
- turn the existing analysis docs into more systematic tuning inputs
- move toward a semi-automated, reviewable config optimization workflow

## Documentation

| Topic | Document |
|---|---|
| Project structure | [`docs/PROJECT_STRUCTURE.md`](./docs/PROJECT_STRUCTURE.md) (Chinese) |
| Script guide | [`scripts/README.md`](./scripts/README.md) (Chinese) |
| Config analysis | [`docs/CONFIG_ANALYSIS.md`](./docs/CONFIG_ANALYSIS.md) (Chinese) |
| Config iteration guide | [`docs/CONFIG_ITERATION_GUIDE.md`](./docs/CONFIG_ITERATION_GUIDE.md) (Chinese) |
| Document index | [`docs/README_CONSOLIDATED.md`](./docs/README_CONSOLIDATED.md) (Chinese) |
| Historical reports | [`archive/README.md`](./archive/README.md) (Chinese) |

## License

This project is released under the [MIT License](./LICENSE).
```

- [ ] **Step 4: Run the English README check again and confirm it passes**

Run the command from Step 1.

Expected: the file exists and every required heading now reports as `FOUND`.

- [ ] **Step 5: Commit the English README addition**

Run:

```bash
git add README.en.md
git commit -m "$(cat <<'EOF'
docs: add English README entrypoint

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

Expected: one commit records the English-facing project summary.

### Task 3: Verify navigation links and README consistency

**Files:**
- Modify: `D:\Y\others\fancontrol\README.md`
- Modify: `D:\Y\others\fancontrol\README.en.md`
- Verify: `D:\Y\others\fancontrol\docs\PROJECT_STRUCTURE.md`
- Verify: `D:\Y\others\fancontrol\scripts\README.md`
- Verify: `D:\Y\others\fancontrol\docs\CONFIG_ANALYSIS.md`
- Verify: `D:\Y\others\fancontrol\docs\CONFIG_ITERATION_GUIDE.md`
- Verify: `D:\Y\others\fancontrol\docs\README_CONSOLIDATED.md`
- Verify: `D:\Y\others\fancontrol\archive\README.md`

- [ ] **Step 1: Run a local link verification script for both README files**

Run:

```powershell
pwsh -NoProfile -Command "
$paths = @(
  'D:/Y/others/fancontrol/README.md',
  'D:/Y/others/fancontrol/README.en.md',
  'D:/Y/others/fancontrol/docs/PROJECT_STRUCTURE.md',
  'D:/Y/others/fancontrol/scripts/README.md',
  'D:/Y/others/fancontrol/docs/CONFIG_ANALYSIS.md',
  'D:/Y/others/fancontrol/docs/CONFIG_ITERATION_GUIDE.md',
  'D:/Y/others/fancontrol/docs/README_CONSOLIDATED.md',
  'D:/Y/others/fancontrol/archive/README.md'
)
$missing = $paths | Where-Object { -not (Test-Path $_) }
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Output "MISSING $_" }
  exit 1
}
$readmeChecks = @(
  @{ Path = 'D:/Y/others/fancontrol/README.md'; Pattern = '^\[English\]\(\./README\.en\.md\)$' },
  @{ Path = 'D:/Y/others/fancontrol/README.en.md'; Pattern = '^\[中文\]\(\./README\.md\)$' },
  @{ Path = 'D:/Y/others/fancontrol/README.md'; Pattern = '^\| 主题 \| 文档 \|$' },
  @{ Path = 'D:/Y/others/fancontrol/README.en.md'; Pattern = '^\| Topic \| Document \|$' },
  @{ Path = 'D:/Y/others/fancontrol/README.md'; Pattern = '通过模型自动调整 `config` 中各项曲线参数' },
  @{ Path = 'D:/Y/others/fancontrol/README.en.md'; Pattern = 'model-assisted tuning of config curve parameters' }
)
foreach ($check in $readmeChecks) {
  if (-not (Select-String -Path $check.Path -Pattern $check.Pattern -Quiet)) {
    Write-Output "CHECK FAILED $($check.Path) :: $($check.Pattern)"
    exit 1
  }
}
Write-Output 'README verification passed'
"
```

Expected: `README verification passed`.

- [ ] **Step 2: If the script fails, fix the specific README text or link target and rerun it**

Apply only the minimal correction needed. For example, if the Chinese README lost the roadmap sentence, restore this exact paragraph:

```markdown
当前最值得关注的方向是：**通过模型自动调整 `config` 中各项曲线参数。**

这项工作不是简单“让模型改 JSON”，而是建立一个更可靠的调优工作流：

- 分析当前 `Game.json` 及相关配置在真实使用下的行为
- 把已有配置分析、采样观察和曲线调整串成可复用流程
- 让参数优化具备可观察、可回退、可比较的基础
- 逐步从人工经验调参过渡到模型辅助参数建议
```

If the English README lost the matching section, restore this exact paragraph:

```markdown
The most important active direction is **model-assisted tuning of config curve parameters**.

That means building a safer workflow around:

- understanding how the current `Game.json` behavior performs in real usage
- connecting config analysis, observation, and curve changes into a reusable loop
- keeping tuning observable, reviewable, and reversible
- moving gradually from manual tuning to model-assisted parameter suggestions
```

Expected: after the minimal fix, the verification script from Step 1 passes.

- [ ] **Step 3: Review the rendered diff scope**

Run:

```bash
git diff -- README.md README.en.md
```

Expected: the diff is limited to the README redesign, English entrypoint creation, and wording/layout changes; no unrelated files appear.

- [ ] **Step 4: Run the verification script one final time**

Run the command from Step 1 again.

Expected: `README verification passed`.

- [ ] **Step 5: Commit the final README verification pass**

Run:

```bash
git add README.md README.en.md
git commit -m "$(cat <<'EOF'
docs: verify README navigation and roadmap

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

Expected: one final docs commit records the verified bilingual README state.

## Self-review

- **Spec coverage:** Task 1 implements the Chinese-first homepage structure, concise positioning, quick-start links, doc navigation, and the visible `当前状态 / 正在进行 / 下一步` roadmap. Task 2 adds the English switch target and keeps the same project narrative in English. Task 3 verifies that both READMEs keep the required navigation links, existing doc targets, and the model-assisted tuning roadmap.
- **Placeholder scan:** No `TODO`, `TBD`, or deferred implementation wording remains in tasks. Every content-editing step includes exact Markdown.
- **Type consistency:** The final headings are consistent across plan steps: Chinese README uses `项目概述 / 为什么有这个仓库 / 当前能力 / 架构概览 / 当前状态 / 正在进行 / 下一步 / 文档导航`, and English README uses `Overview / Why this repository exists / Current capabilities / Architecture at a glance / Current status / In progress / Next / Documentation`.
