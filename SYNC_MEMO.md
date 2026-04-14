# FanControl Sync Memo

## 路径角色

- 运行目录：`C:\FanControl_Auto`
- 源码主目录：`D:\Y\others\fancontrol\scripts\current`

## 目录语义

- `scripts\current\`：当前最新、准备部署的脚本源码
- `scripts\iterating\`：正在试验的候选脚本
- `scripts\history\`：历史脚本、旧快照、旧版入口

## 日常修改规则

1. 默认先改 `D:\Y\others\fancontrol\scripts\current\`
2. 在 D 盘先验证
3. 验证通过后，再同步到 `C:\FanControl_Auto`

## 同步命令

```powershell
Copy-Item "D:\Y\others\fancontrol\scripts\current\*" "C:\FanControl_Auto\" -Force
```

## 注意事项

- 不要把 `C:\FanControl_Auto` 当作日常主编辑位置
- `C:\FanControl_Auto` 根目录只放系统当前直接运行的脚本
- 历史脚本请放到 `history\`
- 候选脚本请放到 `iterating\`

## 紧急热修

如果必须直接修改 `C:\FanControl_Auto`：

1. 先记录改了哪个文件
2. 改完立即回拷到 `D:\Y\others\fancontrol\scripts\current\`
3. 保证 D 盘源码和 C 盘运行副本重新一致
