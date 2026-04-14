# Scripts 目录说明

本目录保存 FanControl 自动切换系统的脚本源码、候选版本和历史归档。

---

## 当前分层

```text
scripts/
├── current/        # 当前生效脚本的源码主目录（D 盘真源）
├── iterating/      # 正在试验、尚未部署到 C 盘根目录的候选脚本
├── history/        # 历史脚本、旧快照、旧版根目录遗留文件
├── tools/          # XML / 部署说明 / 参考工具
└── README.md
```

### 目录语义

- `current/`：当前运行脚本在仓库中的源码镜像，也是后续修改的默认入口
- `iterating/`：下一轮修改、验证中的候选版本
- `history/`：不要默认执行，只用于回溯、参考、比对
- `tools/`：任务 XML、部署说明等辅助资料

---

## 当前激活脚本

`scripts/current/` 当前保存以下活跃文件：

- `auto_switch.ps1`
- `auto_switch_recovery.ps1`
- `switch.ps1`
- `check_status.ps1`
- `monitor_simple.ps1`
- `fix_startup_logon.ps1`

它们与运行目录 `C:\FanControl_Auto\` 根目录中的同名脚本保持一致。

---

## 运行目录约定

运行目录为：

```text
C:\FanControl_Auto\
├── auto_switch.ps1
├── switch.ps1
├── check_status.ps1
├── monitor_simple.ps1
├── fix_startup_logon.ps1
├── RUNTIME_LAYOUT_MEMO.md
├── history\
├── iterating\
├── logs\
├── monitor_data\
└── state\
```

说明：

- `C:\FanControl_Auto\` 根目录只保留系统当前直接使用的脚本
- 任务计划仍直接调用 `C:\FanControl_Auto\auto_switch.ps1`
- 历史脚本和旧部署工具已移到 `C:\FanControl_Auto\history\`

---

## 同步规则

### 源码主位置

默认先修改：

```text
D:\Y\others\fancontrol\scripts\current\
```

验证通过后，再同步到：

```text
C:\FanControl_Auto\
```

### 同步命令

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```

### 禁止反向习惯

- 不要把 `C:\FanControl_Auto\` 当作日常主编辑目录
- 除非是紧急热修，否则不要先改 C 盘再补 D 盘
- 如果确实在 C 盘做了热修，必须立即把最终文件回拷到 `scripts/current/`

---

## 历史内容说明

### `history/legacy_snapshot/`

保存旧版 `scripts/legacy/` 的完整归档。

### `history/production_snapshot_2026-04-13/`

保存整理前 `scripts/production/` 的快照。

### `history/root_legacy_files/`

保存仓库根目录下原先混放的旧脚本：

- `AutoFanSwitch.ps1`
- `AutoFanSwitch_test.ps1`
- `AutoFanSwitch.bat`
- `TestFan.bat`

---

## tools 目录

`tools/` 保存不属于“当前运行脚本”的辅助文件，例如：

- `FanControl_Task.xml`
- `startup_task.xml`
- `startup_task_export.xml`
- `startup_task_fixed.xml`
- `部署说明.md`

---

## 推荐工作流

### 修改当前脚本

1. 编辑 `scripts/current/` 下的目标脚本
2. 在仓库中先完成检查
3. 同步到 `C:\FanControl_Auto\`
4. 用状态工具或任务计划验证结果

### 做新一轮实验

1. 在 `scripts/iterating/` 新建候选脚本
2. 命名包含目的或版本，如：
   - `auto_switch_force-fix.ps1`
   - `auto_switch_v3_3_candidate.ps1`
3. 验证后再决定是否提升为 `current/`

### 查看当前状态

```powershell
C:\FanControl_Auto\check_status.ps1
Get-Content C:\FanControl_Auto\logs\auto_switch.log -Tail 20
```

---

## 维护备注

- `scripts/current/` 才代表“现在最新且准备部署”的脚本版本
- `C:\FanControl_Auto\` 代表“现在系统正在跑”的脚本副本
- `iterating/` 代表“正在迭代但还没上线”
- `history/` 代表“历史版本，不要混入当前判断”
