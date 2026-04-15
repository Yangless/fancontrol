# FanControl 自动化配置切换系统

[![Test](https://github.com/Yangless/fancontrol/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/Yangless/fancontrol/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **当前版本：** v3.2 | **最后更新：** 2026-04-14 | **状态：** 生产运行中

这是一个面向 Windows + FanControl 的自动化脚本仓库，用来在固定时间段和登录场景下切换风扇配置，并保留手动干预与运行期验证能力。

## 快速入口

- 当前维护的源码入口：`scripts/current/`
- 当前结构权威说明：`docs/PROJECT_STRUCTURE.md`
- 当前跟踪中的配置快照：`configs/`
- 当前自动化测试入口：`tests/Invoke-FanControlTests.ps1`
- 详细文档索引：`docs/README_CONSOLIDATED.md`
- 历史报告索引：`archive/README.md`
- 系统实际运行副本：`C:\FanControl_Auto\`
- 当前公开许可证：`MIT`

### Source / Runtime 规则

- Repo source of truth：`scripts/current/`
- Runtime mirror：`C:\FanControl_Auto\`
- Deploy action：把验证通过的 `scripts/current/` 文件复制到 `C:\FanControl_Auto\`
- Emergency hotfix rule：如果直接改了 `C:\FanControl_Auto\`，必须立即同步回 `scripts/current/`

### 本仓库适合谁

- 想把 FanControl 配置切换自动化的人
- 想参考 PowerShell + Windows 任务计划实现方式的人
- 想直接复用当前脚本结构并按自己机器路径调整的人

### 公开仓库整理说明

- 根目录只保留当前仍然有入口价值的文件
- 历史报告、阶段性整理报告统一放入 `archive/`
- 更完整的技术文档统一放入 `docs/`

### 快速测试

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

测试套件现已基于 `Pester 5.x` 运行。

---

## 目录

1. [项目概述](#1-项目概述)
2. [目录结构](#2-目录结构)
3. [架构设计](#3-架构设计)
4. [任务计划清单](#4-任务计划清单)
5. [脚本说明](#5-脚本说明)
6. [快速上手](#6-快速上手)
7. [日常维护](#7-日常维护)
8. [故障排查](#8-故障排查)
9. [修改配置](#9-修改配置)
10. [开发历史](#10-开发历史)
11. [Next](#11-next)

---

## 1. 项目概述

FanControl 不支持按时间段自动切换配置，本系统通过 Windows 任务计划程序调用 PowerShell 脚本，实现：

- **自动时段切换**：每天 4 个时间点自动切换游戏/安静模式
- **手动免打扰**：临时切换后，自动调度暂停，不干扰手动设定
- **强制恢复**：关键时间点（12:40、21:00）强制恢复自动调度
- **开机自启**：登录后 30 秒自动启动 FanControl 并应用正确配置
- **IPC 热切换**：利用 `FanControl.exe -c <config>` 实现无感切换（不重启进程）

### 关键技术点

FanControl 官方支持命令行参数 `-c <配置文件路径>`：
- 若 FanControl **未运行**：直接启动并加载指定配置
- 若 FanControl **已运行**：通过 IPC 发送切换消息，进程不重启，配置无缝热切换

---

## 2. 目录结构

当前真实结构以 `docs/PROJECT_STRUCTURE.md` 为准。这里仅保留与使用直接相关的分层说明。

```text
D:\Y\others\fancontrol\         ← 仓库根目录
├── README.md                   ← 项目入口
├── CHANGELOG.md                ← 版本历史
├── SYNC_MEMO.md                ← repo/runtime 同步规则
├── archive\                    ← 历史报告
├── configs\                    ← 跟踪中的配置快照
├── docs\                       ← 文档与计划
├── scripts\
│   ├── current\                ← 当前活跃脚本的唯一源码权威目录
│   ├── iterating\              ← 候选脚本
│   ├── history\                ← 历史快照与旧入口
│   └── tools\                  ← 部署辅助资料
└── tests\                      ← Pester 测试

C:\FanControl_Auto\             ← runtime mirror，任务计划直接调用这里
├── auto_switch.ps1
├── switch.ps1
├── check_status.ps1
├── monitor_simple.ps1
├── fix_startup_logon.ps1
├── logs\
├── monitor_data\
└── state\

D:\Program Files (x86)\FanControl\
└── Configurations\             ← FanControl 原生配置目录与 CACHE 文件
```

### 脚本分层约定

- `scripts/current/` 是 repo source of truth
- `C:\FanControl_Auto\` 是 deploy-only runtime mirror
- 日常修改默认先改仓库，再部署到运行目录
- 如果直接修改了运行目录，必须立即同步回仓库源码

---

## 3. 架构设计

### 时段规则

| 时段 | 时间范围 | 配置 | 触发类型 |
|------|---------|------|---------|
| Quiet | 12:40 – 14:00 | Quiet_mode.json | 强制（12:40 清除 override） |
| Game  | 08:00 – 12:40 | Game.json | 常规 |
| Game  | 14:00 – 21:00 | Game.json | 常规 |
| Quiet | 21:00 – 次日 08:00 | Quiet_mode.json | 强制（21:00 清除 override） |

### 时间判断逻辑

当前时间策略已经收敛到 `scripts/current/time_policy.ps1` 的表驱动窗口定义，活跃脚本不再各自写一份 `if` 链。

| Label | Start | End | Config | Force |
|------|------:|----:|--------|-------|
| NightQuiet | 0 | 480 | Quiet_mode.json | 否 |
| MorningGame | 480 | 760 | Game.json | 否 |
| LunchQuiet | 760 | 840 | Quiet_mode.json | 是 |
| AfternoonGame | 840 | 1260 | Game.json | 否 |
| EveningQuiet | 1260 | 1440 | Quiet_mode.json | 是 |

对外仍保留以下稳定入口：

- `Get-ConfigNameForMinute`
- `Test-IsForcePointMinute`
- `Test-IsQuietExitPointMinute`
- `Get-TimePolicyWindow`

### 当前配置实现逻辑

当前两套主配置不是“同一组曲线的两个档位”，而是两种不同的运行语义：

- `Game.json`：FanControl 主动接管风扇控制
- `Quiet_mode.json`：FanControl 退出风扇控制，行为回到 BIOS / EC / GPU 默认策略

`Game.json` 当前的风扇绑定关系是：

| 风扇 | 曲线 | 温度源 | 当前含义 |
|------|------|--------|---------|
| CPU Fan | Auto | CPU Package | 第一优先级响应风扇 |
| System Fan #2 | Auto 1 | CPU Package | 第二层辅助响应 |
| System Fan #3 | Auto 2 | Core Average | 延后介入，允许低负载停转 |
| System Fan #4 | Auto 2 | Core Average | 与 #3 类似，但启动点略低 |

`Game.json` 当前的三条曲线阈值为：

| 曲线 | IdleTemp | MinFanSpeed | MaxFanSpeed | LoadTemp |
|------|---------:|------------:|------------:|---------:|
| Auto | 35 | 30 | 80 | 70 |
| Auto 1 | 40 | 20 | 80 | 70 |
| Auto 2 | 50 | 0 | 80 | 80 |

这意味着当前 Game 模式的实际策略是：

- CPU 风扇最早介入
- 一路机箱风扇中等强度跟随
- 两路机箱风扇更晚介入，偏轻载静音

`Quiet_mode.json` 当前的实现则是：

- 所有 `Controls.Enable = false`
- 所有 `SelectedFanCurve = null`
- `FanCurves = []`

所以 Quiet 模式不是低速曲线模式，而是“FanControl 不再控制风扇”的退出控制模式。

### 状态机

```
┌─────────────────┐    switch.ps1 game/quiet    ┌──────────────────┐
│   自动调度模式   │ ─────────────────────────→  │   免打扰模式      │
│ (无 override)   │                              │ (有 override.flag)│
│                 │ ←─────────────────────────  │                  │
└─────────────────┘    switch.ps1 auto           └──────────────────┘
        ↑                或 强制触发点（12:40/21:00）
        └────────────────────────────────────────────────────────────
```

### 强制触发点的作用

12:40 和 21:00 是"强制触发"：不管有没有 override.flag，都会：
1. 删除 override.flag
2. 强制切换到 Quiet 模式
3. 恢复自动调度

这确保用户不会因为忘记手动恢复，导致始终停在游戏模式不切换。

---

## 4. 任务计划清单

当前注册的 5 个任务（均在任务计划程序根目录 `\`）：

| 任务名 | 触发器 | 延迟 | 操作 | 强制？ |
|--------|-------|------|------|-------|
| FanControl-Startup | 用户登录时（LogonTrigger） | 30 秒 | 运行 auto_switch.ps1 | 否 |
| FanControl-0800(Game) | 每日 08:00 | 无 | 运行 auto_switch.ps1 | 否 |
| FanControl-1240(Quiet) | 每日 12:40 | 无 | 运行 auto_switch.ps1 | **是** |
| FanControl-1400(Game) | 每日 14:00 | 无 | 运行 auto_switch.ps1 | 否 |
| FanControl-2100(Quiet) | 每日 21:00 | 无 | 运行 auto_switch.ps1 | **是** |

> **注意**：所有任务调用同一个脚本 `auto_switch.ps1`，脚本内部根据当前时间自行判断应该切换到哪个配置，并判断是否为强制触发点。

### 查看任务状态

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like 'FanControl-*' } |
    ForEach-Object {
        $info = $_ | Get-ScheduledTaskInfo
        [PSCustomObject]@{
            Name       = $_.TaskName
            State      = $_.State
            LastRun    = $info.LastRunTime
            LastResult = $info.LastTaskResult  # 0 = 成功
        }
    } | Format-Table -AutoSize
```

---

## 5. 脚本说明

### auto_switch.ps1（核心脚本）

**调用方**：任务计划程序（自动），或手动测试

**执行流程**：

```
1. 通过共享切换核心验证配置文件路径（FanControl.exe、Quiet_mode.json、Game.json）
   ↓ 失败 → 弹窗报错 + 写日志 + exit 1
2. 判断是否为强制触发点（12:40 或 21:00）
   ↓ 是强制点 → 删除 override.flag → 切换 Quiet → 验证 → 通知 → exit
3. 检查 override.flag 是否存在
   ↓ 存在 → 写日志 "skipped" → exit
4. 通过 `time_policy.ps1` 解析当前策略窗口
5. 调用共享切换核心执行 `FanControl.exe -c <config> -tray`
6. 等待最多 10 秒，从 CACHE 文件验证配置是否生效，并写出 `ObservedConfig` / `ObservedAt` / `VerificationConfidence`
7. 更新 `state/current_status.json`
8. 显示系统托盘通知
```

**参数**：
- `-Force`：进入强制 Quiet 分支（主要用于 12:40 / 21:00 强制点或手动测试）

**共享依赖**：

- `runtime_paths.ps1`：统一运行时路径解析
- `time_policy.ps1`：统一时段窗口和强制点判断
- `config_switch_core.ps1`：统一切换、验证、状态写入
- `volume_helper.ps1`：静音/恢复音量

### switch.ps1（手动干预脚本）

**调用方**：热键、Stream Deck、桌面快捷方式

**用法**：
```powershell
.\switch.ps1 -Mode game   # 切换到游戏模式，写入 override.flag
.\switch.ps1 -Mode quiet  # 切换到安静模式，写入 override.flag
.\switch.ps1 -Mode auto   # 清除 override.flag，恢复自动调度并校准配置
.\switch.ps1 -Help        # 显示帮助和当前状态
```

`-Mode auto` 现在直接调用共享切换核心做“自动模式校准”，不再反向 shell 到 `C:\FanControl_Auto\auto_switch.ps1`。

### check_status.ps1（状态查看）

```powershell
.\check_status.ps1          # 一次性显示完整状态
.\check_status.ps1 -Watch   # 每 5 秒刷新，持续监控
```

**显示内容**：进程状态、当前配置、override 状态、最后切换结果、最近日志、时段匹配检查

当前输出基于统一运行时状态层 `runtime_state.ps1`，会同时展示：

- `DesiredConfig`
- `EffectiveConfig`
- `VerificationStatus`
- `VerificationConfidence`
- `ObservedConfig`
- `StateConfidence`

### monitor_simple.ps1（诊断与采样监控）

用于调试或验证切换是否成功，当前已经是受支持的运行时诊断工具，基于统一状态层输出。

```powershell
.\monitor_simple.ps1 -Mode Snapshot                           # 单次快照并写盘
.\monitor_simple.ps1 -Mode Watch -IntervalSeconds 5          # 持续打印状态，不累计内存
.\monitor_simple.ps1 -Mode Sample -IntervalSeconds 2 -SummaryMinutes 1  # 批量采样并周期写盘
```

输出文件保存到 `C:\FanControl_Auto\monitor_data\monitor_YYYYMMDD_HHMMSS.json`

### 共享辅助层

当前活跃脚本还包含三个非入口但关键的共享层：

- `runtime_paths.ps1`：唯一的运行时路径默认值和环境覆盖入口
- `runtime_state.ps1`：统一读取进程、CACHE、status、override 四类事实源
- `config_switch_core.ps1`：统一处理切换、验证、状态写入，供 `auto_switch.ps1` 和 `switch.ps1` 复用

---

## 6. 快速上手

### 全新部署（从零开始）

```powershell
# 1. 创建目录
New-Item -ItemType Directory -Force "C:\FanControl_Auto\state"
New-Item -ItemType Directory -Force "C:\FanControl_Auto\logs"

# 2. 部署已验证的仓库脚本到 runtime mirror
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force

# 3. 注册或修复开机启动任务
powershell -ExecutionPolicy Bypass -File "C:\FanControl_Auto\fix_startup_logon.ps1"

# 4. 日常定时任务如需重建，请参考归档目录：
# C:\FanControl_Auto\history\deployment\

# 5. 验证
Get-ScheduledTask | Where-Object { $_.TaskName -like 'FanControl-*' }
```

### 手动绑定快捷方式

| 用途 | 命令 |
|------|------|
| 切换游戏模式 | `powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\FanControl_Auto\switch.ps1" -Mode game` |
| 切换安静模式 | `powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\FanControl_Auto\switch.ps1" -Mode quiet` |
| 恢复自动调度 | `powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\FanControl_Auto\switch.ps1" -Mode auto` |

### Stream Deck 配置

插件：**System → Open**

- App/File：`powershell.exe`
- Arguments：`-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\FanControl_Auto\switch.ps1" -Mode game`

---

## 7. 日常维护

### 验证系统运行正常

```powershell
# 查看当前状态（最常用）
C:\FanControl_Auto\check_status.ps1

# 查看最近日志
Get-Content C:\FanControl_Auto\logs\auto_switch.log -Tail 20

# 查看所有任务上次运行结果（LastTaskResult = 0 为成功）
Get-ScheduledTask | Where-Object { $_.TaskName -like 'FanControl-*' } |
    ForEach-Object { $_ | Get-ScheduledTaskInfo } |
    Select-Object TaskName, LastRunTime, LastTaskResult
```

### 验证切换成功

切换后检查 `C:\FanControl_Auto\state\current_status.json`：

```json
{
  "Status": "SUCCESS",       ← 切换成功
  "Verified": true,          ← 从 CACHE 文件验证通过
  "TargetConfig": "Game.json",
  "ActualConfig": "Game.json"  ← 两者一致
}
```

### 手动触发切换（测试用）

```powershell
# 手动运行任意任务
Start-ScheduledTask -TaskName "FanControl-Startup"
Start-ScheduledTask -TaskName "FanControl-1400(Game)"

# 直接运行脚本
powershell -ExecutionPolicy Bypass -File "C:\FanControl_Auto\auto_switch.ps1"
```

### 清理旧日志

```powershell
# 日志文件不会自动轮转，建议定期清理
# 清理 30 天前的监控数据
Get-ChildItem "C:\FanControl_Auto\monitor_data\*.json" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force
```

---

## 8. 故障排查

### 问题：开机后 FanControl 没有自动启动

**诊断**：
```powershell
Get-ScheduledTaskInfo -TaskName "FanControl-Startup" |
    Select-Object LastRunTime, LastTaskResult
# LastRunTime = 1999/11/30 → 从未运行过
# LastTaskResult ≠ 0 → 运行出错
```

**原因**：启动任务使用了 `BootTrigger`，与 `Interactive` 登录类型存在时序冲突，任务在用户会话建立前已触发。

**修复**：重新注册为 `LogonTrigger`（用户登录时触发）+ 30 秒延迟：
```powershell
powershell -ExecutionPolicy Bypass -File "C:\FanControl_Auto\fix_startup_logon.ps1"
```

---

### 问题：定时切换未执行

**诊断**：
```powershell
# 查看任务上次运行结果
Get-ScheduledTaskInfo -TaskName "FanControl-1400(Game)" | Select-Object LastRunTime, LastTaskResult
```

**常见错误码**：

| 错误码 | 含义 | 解决方案 |
|--------|------|---------|
| 0 | 成功 | — |
| 267011 (0x41303) | 从未运行 | 检查触发器配置 |
| 2147946720 | 任务调度错误 | 重新注册任务 |
| 1 | 脚本 exit 1 | 查看日志，通常是配置文件路径错误 |

---

### 问题：配置切换后未生效

**诊断**：
```powershell
# 检查 CACHE 文件（FanControl 当前实际使用的配置）
Get-Content "D:\Program Files (x86)\FanControl\Configurations\CACHE" | ConvertFrom-Json |
    Select-Object CurrentConfigFileName
```

**可能原因**：
1. FanControl 进程未运行 → `auto_switch.ps1` 会启动它
2. 配置文件不存在 → 脚本会弹窗报错
3. 配置文件路径变更 → 修改脚本顶部的 `$QuietConfig` / `$GameConfig` 变量

---

### 问题：override.flag 残留导致自动切换无效

**症状**：定时任务按时执行，但配置没变，日志显示 "Override mode active"

**解决**：
```powershell
# 方案1：手动清除
Remove-Item "C:\FanControl_Auto\state\override.flag" -Force

# 方案2：使用脚本恢复
.\switch.ps1 -Mode auto

# 方案3：等到 12:40 或 21:00，强制触发点会自动清除
```

---

### 快速诊断命令

```powershell
# 一键查看全部状态
C:\FanControl_Auto\check_status.ps1

# 查看进程
Get-Process FanControl -ErrorAction SilentlyContinue

# 查看当前配置
(Get-Content "D:\Program Files (x86)\FanControl\Configurations\CACHE" | ConvertFrom-Json).CurrentConfigFileName

# 查看 override 状态
Test-Path "C:\FanControl_Auto\state\override.flag"

# 查看最近日志
Get-Content "C:\FanControl_Auto\logs\auto_switch.log" -Tail 10
```

---

## 9. 修改配置

说明：

- 仓库跟踪中的配置快照位于 `configs/`
- FanControl 实际读取的 live config 位于 `D:\Program Files (x86)\FanControl\Configurations\`
- 修改配置时，要区分“仓库快照更新”和“live config 部署”

### 修改时段规则

先编辑 repo source of truth `D:\Y\others\fancontrol\scripts\current\time_policy.ps1` 中的策略表，验证后再部署到 `C:\FanControl_Auto\`：

```powershell
$script:FanControlSchedule = @(
    [PSCustomObject]@{ Start = 0; End = 480; Config = 'Quiet_mode.json'; Force = $false; Label = 'NightQuiet' },
    [PSCustomObject]@{ Start = 480; End = 760; Config = 'Game.json'; Force = $false; Label = 'MorningGame' },
    [PSCustomObject]@{ Start = 760; End = 840; Config = 'Quiet_mode.json'; Force = $true; Label = 'LunchQuiet' },
    [PSCustomObject]@{ Start = 840; End = 1260; Config = 'Game.json'; Force = $false; Label = 'AfternoonGame' },
    [PSCustomObject]@{ Start = 1260; End = 1440; Config = 'Quiet_mode.json'; Force = $true; Label = 'EveningQuiet' }
)
```

不需要再同步修改 `check_status.ps1` 或 `monitor_simple.ps1` 的同类时间判断逻辑，它们已经走共享状态层。

修改时段后，**还需要更新对应的任务计划触发时间**：
```powershell
# 示例：将 08:00 改为 09:00
$trigger = New-ScheduledTaskTrigger -Daily -At "09:00"
Set-ScheduledTask -TaskName "FanControl-0800(Game)" -Trigger $trigger
```

### 修改强制触发点

同样在 `scripts/current/time_policy.ps1` 中修改 `Force = $true` 的窗口起点。当前强制点由表定义，而不是写死在 `auto_switch.ps1`：

```powershell
[PSCustomObject]@{ Start = 760; End = 840; Config = 'Quiet_mode.json'; Force = $true; Label = 'LunchQuiet' }
[PSCustomObject]@{ Start = 1260; End = 1440; Config = 'Quiet_mode.json'; Force = $true; Label = 'EveningQuiet' }
```

### 修改 FanControl 路径

统一修改 `scripts/current/runtime_paths.ps1`，不要再分别改多个入口脚本：

```powershell
function Get-FanControlPaths {
    $runtimeRoot = 'C:\FanControl_Auto'
    $configDir = 'D:\Program Files (x86)\FanControl\Configurations'
    $fanControlExe = 'D:\Program Files (x86)\FanControl\FanControl.exe'
}
```

`switch.ps1`、`auto_switch.ps1`、`check_status.ps1`、`monitor_simple.ps1` 都已经从这里取路径。任何直接对 runtime mirror 的热修，都应立即回拷到 `scripts/current/`。

### 重新部署任务计划

修改脚本后需要重启任务才能生效（任务计划读取的是脚本文件，不是缓存，所以修改脚本文件本身立即生效；但若修改了触发时间，需重新注册任务）：

```powershell
# 重新注册所有任务
powershell -ExecutionPolicy Bypass -File "C:\FanControl_Auto\deploy_tasks.ps1"

# 仅重新注册开机任务
powershell -ExecutionPolicy Bypass -File "C:\FanControl_Auto\fix_startup_logon.ps1"
```

---

## 10. 开发历史

详见 [CHANGELOG.md](CHANGELOG.md)

### 简要摘要

| 版本 | 日期 | 关键变更 |
|------|------|---------|
| v1.0 | 2026-04-02 | 初始版本：基础时段切换 + 任务计划 |
| v2.0 | 2026-04-11 | 重写：添加日志、验证、错误通知、手动覆盖机制 |
| v3.0 | 2026-04-11 | 修复：统一配置路径、完善时间边界注释、修复启动延迟 |
| v3.1 | 2026-04-12 | 新增：check_status.ps1 状态工具、monitor_simple.ps1 监控工具 |
| v3.2 | 2026-04-12 | **修复开机自启**：BootTrigger → LogonTrigger + 30s 延迟 |

---

## 11. Next

下一项工作：

- 自动调整 config 中各项曲线参数

目标是把当前依赖手工调整的曲线阈值和响应参数，逐步演进为可自动分析、可自动修正的配置调优流程。

---

## 参考

- FanControl 官网：https://getfancontrol.com/
- FanControl GitHub：https://github.com/Rem0o/FanControl
- Windows 任务计划 PowerShell 文档：https://learn.microsoft.com/powershell/module/scheduledtasks/
