# FanControl 自动化配置切换系统

> **当前版本：** v3.2 | **最后更新：** 2026-04-12 | **状态：** 生产运行中 ✅

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

```
C:\FanControl_Auto\             ← 实际运行目录（任务计划直接调用这里）
├── auto_switch.ps1             ← 当前运行入口
├── switch.ps1                  ← 当前手动干预入口
├── check_status.ps1            ← 当前状态查看工具
├── monitor_simple.ps1          ← 当前持续监控工具
├── fix_startup_logon.ps1       ← 当前开机任务修复脚本
├── RUNTIME_LAYOUT_MEMO.md      ← 运行目录备忘录
├── history\                    ← 历史脚本 / 旧部署工具 / 旧 XML / 备份
├── iterating\                  ← 候选脚本（尚未提升为运行入口）
├── state\
│   ├── override.flag           ← 免打扰标志（运行时生成/删除）
│   └── current_status.json     ← 最后一次切换状态（运行时更新）
├── logs\
│   ├── auto_switch.log         ← 自动切换详细日志
│   └── switch.log              ← 手动切换日志
└── monitor_data\               ← 持续监控数据（JSON/MD格式）

D:\Program Files (x86)\FanControl\
└── Configurations\
    ├── Quiet_mode.json         ← 安静模式配置（FanControl 原生）
    ├── Game.json               ← 游戏模式配置（FanControl 原生）
    ├── Game_ultr.json          ← 备用游戏配置（未使用）
    └── CACHE                   ← 当前配置缓存（FanControl 自动维护，验证用）

D:\Y\others\fancontrol\         ← 项目源码目录（源码主位置）
├── README.md                   ← 本文档
├── CHANGELOG.md                ← 开发历史
├── SYNC_MEMO.md                ← D→C 同步备忘录
├── scripts\
│   ├── current\                ← 当前最新脚本源码（默认编辑这里）
│   ├── iterating\              ← 正在试验的候选脚本
│   ├── history\                ← 历史脚本和旧快照
│   └── tools\                  ← XML / 部署说明 / 参考工具
└── ...（配置、文档和报告）
```

### 脚本分层约定

- `D:\Y\others\fancontrol\scripts\current\` 是当前脚本源码主位置
- `C:\FanControl_Auto\` 根目录是系统实际运行副本
- `iterating\` 表示“正在迭代”
- `history\` 表示“历史归档”
- 日常修改默认先改 D 盘，再同步到 C 盘

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

```powershell
$min = (Get-Date).Hour * 60 + (Get-Date).Minute

# Quiet 时段（三段合并，含跨天）
if (($min -ge 760 -and $min -lt 840) -or   # 12:40-14:00
    ($min -ge 1260) -or                     # 21:00-24:00
    ($min -lt 480)) {                        # 00:00-08:00
    # → Quiet_mode.json
} else {
    # → Game.json
}
```

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
1. 验证配置文件路径（FanControl.exe、Quiet_mode.json、Game.json）
   ↓ 失败 → 弹窗报错 + 写日志 + exit 1
2. 判断是否为强制触发点（12:40 或 21:00）
   ↓ 是强制点 → 删除 override.flag → 切换 Quiet → 验证 → 通知 → exit
3. 检查 override.flag 是否存在
   ↓ 存在 → 写日志 "skipped" → exit
4. 根据当前时间判断目标配置
5. 调用 FanControl.exe -c <config> -tray
6. 等待最多 10 秒，从 CACHE 文件验证配置是否生效
7. 更新 state/current_status.json
8. 显示系统托盘通知
```

**参数**：
- `-Force`：强制切换（忽略时间判断，直接切换到当前时段应有的配置）

### switch.ps1（手动干预脚本）

**调用方**：热键、Stream Deck、桌面快捷方式

**用法**：
```powershell
.\switch.ps1 -Mode game   # 切换到游戏模式，写入 override.flag
.\switch.ps1 -Mode quiet  # 切换到安静模式，写入 override.flag
.\switch.ps1 -Mode auto   # 清除 override.flag，恢复自动调度并校准配置
.\switch.ps1 -Help        # 显示帮助和当前状态
```

### check_status.ps1（状态查看）

```powershell
.\check_status.ps1          # 一次性显示完整状态
.\check_status.ps1 -Watch   # 每 5 秒刷新，持续监控
```

**显示内容**：进程状态、当前配置、override 状态、最后切换结果、最近日志、时段匹配检查

### monitor_simple.ps1（持续采样监控）

用于调试或验证切换是否成功，每 N 秒采一次样，每 M 分钟保存一次 JSON 报告。

```powershell
.\monitor_simple.ps1                              # 默认：5秒采样，5分钟保存
.\monitor_simple.ps1 -IntervalSeconds 2 -SummaryMinutes 1  # 高频调试
```

输出文件保存到 `C:\FanControl_Auto\monitor_data\monitor_YYYYMMDD_HHMMSS.json`

---

## 6. 快速上手

### 全新部署（从零开始）

```powershell
# 1. 创建目录
New-Item -ItemType Directory -Force "C:\FanControl_Auto\state"
New-Item -ItemType Directory -Force "C:\FanControl_Auto\logs"

# 2. 复制脚本文件到 C:\FanControl_Auto\
# （从 D:\Y\others\fancontrol\scripts\current\ 同步当前脚本）
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

### 修改时段规则

先编辑 `D:\Y\others\fancontrol\scripts\current\auto_switch.ps1` 中的 `Get-TargetConfig` 函数，验证后再同步到 `C:\FanControl_Auto\auto_switch.ps1`：

```powershell
function Get-TargetConfig {
    $min = (Get-Date).Hour * 60 + (Get-Date).Minute

    # 修改这里的时间边界（单位：分钟）
    if (($min -ge 760 -and $min -lt 840) -or   # 12:40-14:00 Quiet
        ($min -ge 1260) -or                     # 21:00-24:00 Quiet
        ($min -lt 480)) {                        # 00:00-08:00 Quiet
        return $QuietConfig
    } else {
        return $GameConfig
    }
}
```

同步修改 `D:\Y\others\fancontrol\scripts\current\check_status.ps1` 中的相同逻辑，再复制到 `C:\FanControl_Auto\check_status.ps1`。

修改时段后，**还需要更新对应的任务计划触发时间**：
```powershell
# 示例：将 08:00 改为 09:00
$trigger = New-ScheduledTaskTrigger -Daily -At "09:00"
Set-ScheduledTask -TaskName "FanControl-0800(Game)" -Trigger $trigger
```

### 修改强制触发点

`auto_switch.ps1` 第 172 行：

```powershell
$isForcePoint = ((Get-Date).Hour -eq 12 -and (Get-Date).Minute -eq 40) -or
                ((Get-Date).Hour -eq 21 -and (Get-Date).Minute -eq 0)
```

### 修改 FanControl 路径

`auto_switch.ps1` 顶部变量：

```powershell
$FanControlExe = "D:\Program Files (x86)\FanControl\FanControl.exe"
$ConfigDir     = "D:\Program Files (x86)\FanControl\Configurations"
$QuietConfig   = "$ConfigDir\Quiet_mode.json"
$GameConfig    = "$ConfigDir\Game.json"
```

同步修改 `switch.ps1` 和 `check_status.ps1` 中的相同路径变量。

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

## 参考

- FanControl 官网：https://getfancontrol.com/
- FanControl GitHub：https://github.com/Rem0o/FanControl
- Windows 任务计划 PowerShell 文档：https://learn.microsoft.com/powershell/module/scheduledtasks/
