# CHANGELOG

---

## v3.2 — 2026-04-12

### 修复：开机自启任务从未运行

**现象**：`FanControl-Startup` 任务的 `LastRunTime` 始终停留在 `1999/11/30`（Windows 任务计划"从未运行"的默认值），开机后 FanControl 需要手动打开。

**根本原因**：任务触发器类型为 `BootTrigger`（系统启动时触发），但 Principal 的 `LogonType` 设置为 `Interactive`（需要用户已登录）。系统启动时用户会话尚未建立，触发器激活后找不到可用的用户上下文，任务被跳过，且不报错。

**修复方案**：将触发器改为 `LogonTrigger`（用户登录时触发），添加 30 秒延迟（等待桌面和服务完全就绪）。

**变更文件**：
- `C:\FanControl_Auto\fix_startup_logon.ps1`（新增，用于重新注册任务）

**验证**：修复后立即测试运行，`LastTaskResult: 0`（成功），日志记录正常。

---

## v3.1 — 2026-04-12

### 新增：状态工具与持续监控工具

**背景**：需要一种方便的方式验证切换是否成功，以及在切换前后观察状态变化。

**新增脚本**：

- `check_status.ps1`：一次性或持续（`-Watch`）显示当前进程、配置、override、上次切换结果、日志摘要、时段匹配
- `monitor_simple.ps1`：定时采样（默认 5 秒一次），每隔 N 分钟将采样数据保存为 JSON 报告，适合验证切换时间点前后的状态变化

**分析工具**（监控数据用法示例）：
```powershell
$data = Get-Content "C:\FanControl_Auto\monitor_data\monitor_*.json" | ConvertFrom-Json
# 配置切换事件
for ($i = 1; $i -lt $data.Count; $i++) {
    if ($data[$i].CurrentConfig -ne $data[$i-1].CurrentConfig) {
        "$($data[$i].Timestamp): $($data[$i-1].CurrentConfig) → $($data[$i].CurrentConfig)"
    }
}
```

---

## v3.0 — 2026-04-11（修复版，Enhanced v3.0）

**背景**：v2.0 部署后发现多处问题，进行全面修复。

### 修复 1：配置路径不一致

旧脚本混用 `Game_ultr.json` 和 `Game.json`，统一改为 `Game.json`（与 FanControl Configurations 目录实际文件一致）。

### 修复 2：时间边界不明确

实际时段为 Quiet: 12:40-14:00 和 21:00-次日08:00，但旧脚本缺少注释，跨天逻辑（23:59→00:00）难以理解。重写 `Get-TargetConfig` 函数，加详细注释。

### 修复 3：启动任务延迟未生效

`FanControl-Startup` 使用 `BootTrigger + PT1M` 延迟，但任务从未运行（后续 v3.2 彻底修复为 LogonTrigger）。

### 新增功能：

- `Test-ConfigFiles()`：脚本启动前验证 FanControl.exe 和两个配置文件是否存在，失败时弹窗报错
- `Write-Log()`：所有关键操作写入日志文件（`logs/auto_switch.log`、`logs/switch.log`）
- `Test-ConfigSwitch()`：切换后最多等待 10 秒，从 CACHE 文件验证配置是否真正生效
- `Update-StatusFile()`：每次切换后将结果写入 `state/current_status.json`（供外部工具读取）
- `Show-Notification()`：切换成功/失败后显示 Windows 托盘气泡通知
- `switch.ps1 -Help`：显示使用说明和当前状态

**变更文件**：
- `C:\FanControl_Auto\auto_switch.ps1`（重写）
- `C:\FanControl_Auto\switch.ps1`（重写）
- `C:\FanControl_Auto\deploy_fixed.ps1`（新增）

---

## v2.0 — 2026-04-11（初次重构）

**背景**：v1.0 在生产使用中发现脚本无日志、无验证、静默失败，进行重构。

### 主要变更：

- 引入 `override.flag` 免打扰机制（手动切换后写入，强制触发点清除）
- 区分"强制触发点"（12:40、21:00）与普通切换：强制触发点忽略 override 并清除
- 开始记录日志（`logs/auto_switch.log`）
- 添加 `switch.ps1` 支持手动干预（`-Mode game/quiet/auto`）
- 添加 `-Force` 参数支持手动强制执行

---

## v1.0 — 2026-04-02（初始版本）

**功能**：

- 基于 Windows 任务计划程序，在 08:00 / 12:40 / 14:00 / 21:00 自动调用 `auto_switch.ps1`
- `auto_switch.ps1`：根据当前时间判断应切换到 Game 还是 Quiet，调用 `FanControl.exe -c <config> -tray`
- `deploy_tasks.ps1`：一键注册 4 个定时任务
- `FanControl-Startup` 任务（BootTrigger，后来发现从未运行，v3.2 修复）

**测试结果**：时段判断逻辑（0-1439 分钟边界值）全部通过，任务计划注册成功，配置切换验证通过。

---

## 开发过程中遇到的关键问题

| 问题 | 版本 | 教训 |
|------|------|------|
| 静默失败（无日志无通知） | v1.0→v2.0 | 后台脚本必须有日志，否则无法排查 |
| 配置文件命名不一致 | v2.0→v3.0 | 路径变量统一写在脚本顶部，避免散落 |
| BootTrigger + Interactive 组合失效 | v1.0→v3.2 | 开机启动 GUI 程序应用 LogonTrigger，不用 BootTrigger |
| override 状态残留 | v2.0 | 强制触发点必须清除 override，防止无限免打扰 |
| CACHE 文件验证滞后 | v3.0 | FanControl 需要 1-2 秒写入 CACHE，验证要有等待循环 |
