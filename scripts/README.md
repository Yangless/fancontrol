# Scripts 目录说明

本目录保存 FanControl 自动切换系统的脚本源码、候选脚本、历史快照和部署辅助资料。

## 核心规则

- 仓库源码 source of truth：`scripts/current/`
- 运行时镜像 runtime mirror：`C:\FanControl_Auto\`
- 部署动作：把已经验证通过的 `scripts/current/` 文件复制到 `C:\FanControl_Auto\`
- 紧急热修规则：如果直接改了 `C:\FanControl_Auto\`，必须立刻同步回 `scripts/current/`

## 当前分层

```text
scripts/
├── current/
├── history/
├── iterating/
├── tools/
└── README.md
```

### 目录语义

- `current/`：当前活跃脚本的唯一源码权威目录，默认修改这里。
- `iterating/`：正在试验、尚未提升为活跃源码的候选脚本。
- `history/`：历史快照和旧入口文件，只用于回溯和比对。
- `tools/`：任务 XML、部署说明和其他辅助资料。

## 当前活跃脚本

`scripts/current/` 当前包含：

- `auto_switch.ps1`
- `auto_switch_recovery.ps1`
- `check_status.ps1`
- `config_switch_core.ps1`
- `fix_startup_logon.ps1`
- `monitor_simple.ps1`
- `runtime_paths.ps1`
- `runtime_state.ps1`
- `switch.ps1`
- `time_policy.ps1`
- `volume_helper.ps1`

共享职责约定：

- `runtime_paths.ps1`：统一路径与环境覆盖。
- `runtime_state.ps1`：统一运行时事实读取。
- `config_switch_core.ps1`：统一切换与验证核心。
- `time_policy.ps1`：统一时段窗口和强制点规则。

这些文件在验证通过后，会部署到 `C:\FanControl_Auto\` 供任务计划和快捷方式调用。

## runtime mirror 说明

`C:\FanControl_Auto\` 是系统直接运行的副本目录，不是日常主编辑目录。

当前运行目录通常包含：

```text
C:\FanControl_Auto\
├── auto_switch.ps1
├── switch.ps1
├── check_status.ps1
├── monitor_simple.ps1
├── fix_startup_logon.ps1
├── history\
├── iterating\
├── logs\
├── monitor_data\
└── state\
```

说明：

- 任务计划仍直接调用 `C:\FanControl_Auto\auto_switch.ps1`
- `logs/`、`monitor_data/`、`state/` 都是运行期数据，不属于仓库源码
- runtime mirror 的文件应由仓库源码部署而来，而不是长期手工维护

## 同步规则

### 标准流程

1. 修改 `scripts/current/` 中的目标脚本。
2. 在仓库中完成检查和验证。
3. 将通过验证的文件同步到 `C:\FanControl_Auto\`。
4. 在运行环境验证任务计划、状态工具或日志结果。

### 同步命令

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```

### 紧急热修

如果必须直接修改 runtime mirror：

1. 记录热修文件和原因。
2. 在 `C:\FanControl_Auto\` 完成必要修复。
3. 立即把最终版本回拷到 `scripts/current/`。
4. 再次以仓库版本为准完成后续验证。

## 历史层说明

`scripts/history/` 当前保留以下归档子目录：

- `legacy_snapshot/`
- `production_snapshot_2026-04-13/`
- `root_legacy_files/`

这些名称反映的是历史来源，不代表当前推荐命名规范，更不代表活跃源码目录。
