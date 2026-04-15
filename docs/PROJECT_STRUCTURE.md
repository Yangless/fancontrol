# FanControl 项目当前结构规范

> 更新日期：2026-04-14
>
> 本文档是仓库当前结构的唯一权威说明，只描述已经存在的真实结构，不描述未来建议。

## 1. 文档边界

- 本文档回答“仓库现在长什么样、各目录负责什么、repo 和 runtime 的边界在哪里”。
- `README.md` 负责项目总览、使用方式和运维说明。
- `docs/README_CONSOLIDATED.md` 只负责文档导航和历史索引，不再定义当前结构。
- 如果在仓库外看到 `SCRIPT_SYNC_REPORT.md` 等旧整理稿，应视为历史产物，不是当前权威来源。

## 2. 当前仓库根目录

截至 2026-04-14，仓库根目录当前实际包含以下内容：

```text
fancontrol/
├── .claude/
├── .github/
├── archive/
├── configs/
├── docs/
├── scripts/
├── tests/
├── .gitignore
├── CHANGELOG.md
├── LICENSE
├── README.md
└── SYNC_MEMO.md
```

### 根目录角色说明

- `.claude/`：本地代理/自动化协作相关配置。
- `.github/`：CI 工作流与 GitHub 配置。
- `archive/`：历史报告和阶段性文档归档，不作为当前结构定义来源。
- `configs/`：仓库跟踪中的配置快照。
- `docs/`：当前维护中的文档、技术说明、计划与规格。
- `scripts/`：脚本源码、实验脚本、历史快照和部署辅助资料。
- `tests/`：Pester 测试与测试辅助脚本。
- `CHANGELOG.md`：版本演进记录。
- `README.md`：项目入口和使用说明。
- `SYNC_MEMO.md`：repo source 和 runtime mirror 的同步约束。
- `configs/` 下当前包含 `Game.json`、`Quiet_mode.json`、`Game_ultr.json` 三个配置快照。

## 3. scripts 目录当前结构

```text
scripts/
├── current/
├── history/
├── iterating/
├── tools/
└── README.md
```

### `scripts/current/`

这是当前活跃脚本在仓库中的唯一源码权威目录，也是默认编辑入口。

当前文件：

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

其中：

- `runtime_paths.ps1` 是统一路径层，负责解析 runtime root、config root、FanControl.exe 和状态目录。
- `runtime_state.ps1` 是统一状态层，负责读取进程、CACHE、status、override。
- `config_switch_core.ps1` 是统一切换核心，负责切换、验证和状态写入。
- `time_policy.ps1` 是统一时间策略层，负责调度窗口、强制点和 Quiet 退出点判断。

### `scripts/iterating/`

用于放置正在试验、尚未提升为活跃源码的候选脚本。这里的文件不应默认视为生产入口。

### `scripts/history/`

用于保留旧脚本快照和历史遗留文件。当前子目录命名方式还不统一，但它们都属于历史归档层，不属于当前结构定义：

- `legacy_snapshot/`
- `production_snapshot_2026-04-13/`
- `root_legacy_files/`

### `scripts/tools/`

保存任务 XML、部署说明和其他辅助资料，不作为活跃调度入口。

## 4. repo source 与 runtime mirror 的关系

当前项目明确区分两个位置：

- 仓库源码权威位置：`D:\Y\others\fancontrol\scripts\current\`
- 运行时镜像位置：`C:\FanControl_Auto\`

### 当前规则

- `scripts/current/` 是唯一源码 source of truth。
- `C:\FanControl_Auto\` 是 deploy-only runtime mirror，任务计划和快捷方式直接调用这里。
- 部署动作是把已经验证过的仓库脚本复制到 runtime mirror。
- `state/`、`logs/`、`monitor_data/` 等运行期产物只属于 runtime，不属于仓库源码。

### 当前同步方式

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```

### 紧急热修规则

如果必须直接修改 `C:\FanControl_Auto\`：

1. 记录改了哪些文件。
2. 立即把最终版本同步回 `scripts/current/`。
3. 确保仓库源码重新成为唯一事实来源。

## 5. docs 目录当前角色

```text
docs/
├── CONFIG_ANALYSIS.md
├── CONFIG_ITERATION_GUIDE.md
├── PROJECT_STRUCTURE.md
├── README_CONSOLIDATED.md
└── superpowers/
```

角色说明：

- `PROJECT_STRUCTURE.md`：当前结构权威说明。
- `README_CONSOLIDATED.md`：导航与历史索引。
- `CONFIG_ANALYSIS.md`：配置文件分析。
- `CONFIG_ITERATION_GUIDE.md`：配置迭代方法。
- `superpowers/`：代理执行计划、规格和工作记录，不作为项目当前结构权威来源。

## 6. 当前事实与后续工作

下面用于明确“现在是什么”和“接下来要改什么”：

| 主题 | 当前事实 | 后续工作 |
|------|---------|---------|
| 活跃脚本源码 | `scripts/current/` 是唯一权威源码目录 | 继续保持，不再引入平行活跃目录 |
| 运行入口 | 任务计划仍直接调用 `C:\FanControl_Auto\` | 后续加强同步与校验机制 |
| 配置快照位置 | `configs/` 保存仓库跟踪中的配置快照 | 后续统一更多配置版本命名与管理规则 |
| 历史脚本归档 | `scripts/history/` 目录存在，但命名维度混用 | 后续统一历史命名规则 |
| 状态与路径逻辑 | 已有 `runtime_paths.ps1`、`runtime_state.ps1`、`config_switch_core.ps1` 和 `time_policy.ps1` 作为共享层 | 继续减少遗留脚本中的旁路逻辑和运行时特例 |

## 7. 判断当前结构时的优先级

遇到结构信息冲突时，按以下优先级判断：

1. 先看实际仓库目录和文件。
2. 再看本文档 `docs/PROJECT_STRUCTURE.md`。
3. 再看 `README.md`、`scripts/README.md`、`SYNC_MEMO.md` 的说明。
4. 历史报告、外部整理稿、运行目录备忘录都不能覆盖本文档。
