# FanControl Sync Memo

## 角色定义

- 仓库源码 source of truth：`D:\Y\others\fancontrol\scripts\current\`
- 运行时镜像 runtime mirror：`C:\FanControl_Auto\`
- 部署动作：把已验证的仓库脚本复制到 runtime mirror

## 当前目录语义

- `scripts\current\`：当前活跃脚本的唯一源码权威目录
- `scripts\iterating\`：正在试验、尚未提升的候选脚本
- `scripts\history\`：历史脚本、旧快照、旧入口文件

## 标准修改规则

1. 默认先修改 `D:\Y\others\fancontrol\scripts\current\`
2. 在仓库内完成验证
3. 验证通过后，再同步到 `C:\FanControl_Auto`

## 同步命令

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```

## 禁止的日常习惯

- 不要把 `C:\FanControl_Auto` 当作日常主编辑位置
- 不要把 runtime mirror 当作结构事实来源
- 不要在未回拷源码前只修改运行目录

## 紧急热修规则

如果必须直接修改 `C:\FanControl_Auto`：

1. 先记录改了哪个文件以及原因
2. 改完后立即回拷到 `D:\Y\others\fancontrol\scripts\current\`
3. 再次确认仓库源码与 runtime mirror 保持一致

## 备注

- 任务计划当前仍直接调用 `C:\FanControl_Auto\auto_switch.ps1`
- `state\`、`logs\`、`monitor_data\` 属于运行期数据，不回写到仓库
