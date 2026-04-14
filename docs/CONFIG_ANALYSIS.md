# FanControl 配置文件分析与优化建议

> **分析日期**: 2026-04-13 | **配置版本**: v262 | **分析范围**: Game.json, Quiet_mode.json, Game_ultr.json

---

## 配置文件概览

### 文件清单
| 文件名 | 用途 | 使用状态 | 行数 |
|--------|------|---------|------|
| Game.json | 游戏模式配置 | ✅ 生产使用 | 812 行 |
| Quiet_mode.json | 安静模式配置 | ✅ 生产使用 | 476 行 |
| Game_ultr.json | 备用游戏配置 | ⚠️ 未使用 | 812 行 |

---

## 配置结构分析

### 顶层结构
```json
{
  "__VERSION__": "262",          // FanControl 配置版本号
  "FanControl": { ... },         // 核心控制配置
  "Sensors": { ... },            // 传感器设置
  "MainWindow": { ... }          // UI 设置
}
```

---

## Game.json 详细分析

### 1. FanControl.Controls (风扇控制)

#### 活跃风扇列表
| 风扇名称 | Identifier | 状态 | 风扇曲线 | 温度源 |
|---------|-----------|------|---------|--------|
| CPU Fan | /lpc/nct6687d/control/0 | ✅ 启用 | Auto | CPU Package |
| System Fan #2 | /lpc/nct6687d/control/3 | ✅ 启用 | Auto 1 | CPU Package |
| System Fan #3 | /lpc/nct6687d/control/4 | ✅ 启用 | Auto 2 | Core Average |
| System Fan #4 | /lpc/nct6687d/control/5 | ✅ 启用 | Auto 2 | Core Average |

**禁用风扇**:
- Pump Fan, System Fan #1/#5/#6 (IsHidden: true, Enable: false)
- GPU Control 1/2 (Enable: false, GPU 自带控制)

#### 关键参数解析
```json
{
  "SelectedFanCurve": { "Name": "Auto" },
  "SelectedStart": 25,              // 启动转速百分比
  "SelectedStop": 16,               // 停止转速百分比
  "MinimumPercent": 0,              // 最小转速限制
  "SelectedCommandStepUp": 8,       // 转速上升步进
  "SelectedCommandStepDown": 8,     // 转速下降步进
  "Calibration": [                  // 转速校准表
    [10, 379],                      // [PWM%, RPM]
    [20, 382],
    // ... 更多校准点
  ]
}
```

---

### 2. FanControl.FanCurves (风扇曲线)

#### Auto (CPU Fan 使用)
```json
{
  "Name": "Auto",
  "SelectedTempSource": { "Identifier": "/intelcpu/0/temperature/16" },  // CPU Package
  "Step": 2,                    // 温度步进
  "Deadband": 3,                // 死区范围
  "SelectedResponseTime": 2,    // 响应时间（秒）
  "IdleTemperature": 35,        // 空闲温度
  "MinFanSpeed": 30,            // 最小风扇转速
  "MaxFanSpeed": 80,            // 最大风扇转速
  "LoadTemperature": 70         // 负载温度
}
```

#### Auto 1 (System Fan #2 使用)
```json
{
  "IdleTemperature": 40,        // 比Auto高5°C
  "MinFanSpeed": 20,            // 允许更低转速
  "LoadTemperature": 70
}
```

#### Auto 2 (System Fan #3/#4 使用)
```json
{
  "SelectedTempSource": { "Identifier": "/intelcpu/0/temperature/1" },  // Core Average
  "IdleTemperature": 50,        // 更高的启动阈值
  "MinFanSpeed": 0,             // 允许停转
  "LoadTemperature": 80
}
```

---

### 3. Sensors 配置

#### LibreHardwareMonitorSettings
```json
{
  "Controller": false,
  "CPU": true,                  // ✅ 启用 CPU 监控
  "EmbeddedEC": true,           // ✅ 启用嵌入式控制器
  "GPU": true,                  // ✅ 启用 GPU 监控
  "Motherboard": true,          // ✅ 启用主板传感器
  "Storage": false,             // ❌ 禁用存储传感器（减少开销）
  "ZeroRPMOverride": true       // 覆盖零转速模式
}
```

---

## Quiet_mode.json 对比分析

### 关键差异

| 配置项 | Game.json | Quiet_mode.json | 影响 |
|--------|-----------|----------------|------|
| Controls.Enable | 4个风扇启用 | **全部禁用** | ⚠️ 所有风扇手动控制关闭 |
| FanCurves | 3条曲线定义 | **空数组** | 无自动控制曲线 |
| SelectedFanCurve | 指定曲线 | **全部 null** | 无风扇曲线绑定 |

### Quiet_mode 配置逻辑
**设计意图**: 完全禁用自动风扇控制，让 FanControl 进入"静默监控模式"

**实际效果**:
1. 所有风扇回到 BIOS/主板默认控制
2. FanControl 仅作为监控工具运行
3. 依赖主板自身的风扇策略（通常更安静）

---

## Game_ultr.json 分析

### 与 Game.json 差异
```bash
diff Game.json Game_ultr.json
# 无差异（文件完全相同）
```

**建议**: 可考虑删除此文件，或作为"性能模式"配置（未使用）

---

## 配置优化建议

### 1. 可迭代改进方法框架

#### 方法论：参数分离 + 渐进调优
```
config_v3.3.json  ←─ 修改单项参数
    ↓
测试运行 (monitor_simple.ps1 采样)
    ↓
效果评估 (温度/噪音/性能)
    ↓
满意 → config_v3.4.json
不满意 → 回滚 + 调整其他参数
```

#### 参数修改优先级
1. **高影响参数**（显著改变风扇行为）:
   - `IdleTemperature` (+/- 5°C 调整)
   - `MinFanSpeed` / `MaxFanSpeed` (调整转速范围)
   - `LoadTemperature` (负载温度阈值)

2. **中影响参数**:
   - `Step` (温度敏感度)
   - `Deadband` (避免频繁启停)
   - `SelectedResponseTime` (响应速度)

3. **低影响参数**:
   - `SelectedCommandStepUp/Down` (平滑过渡)

---

### 2. 具体优化方向

#### 方向 1: 降低噪音（Game.json）
**当前问题**: CPU Fan 在 35°C 即开始提升转速

**优化方案**:
```json
// Auto 曲线调整
{
  "IdleTemperature": 40,        // 35 → 40 (提高启动阈值)
  "MinFanSpeed": 25,            // 30 → 25 (降低最低转速)
  "Deadband": 4                 // 3 → 4 (减少频繁调整)
}
```

**测试步骤**:
1. 修改 Game.json 并备份为 `Game_v3.3_quiet.json`
2. 运行 `monitor_simple.ps1` 采集 30 分钟数据
3. 对比温度峰值、平均转速、噪音主观感受

---

#### 方向 2: 增强 Game 模式散热
**场景**: 高负载游戏时温度偏高

**优化方案**:
```json
// Auto 曲线调整
{
  "MaxFanSpeed": 90,            // 80 → 90 (允许更高转速)
  "LoadTemperature": 65         // 70 → 65 (更早进入高转速)
}
```

**风险**: 噪音明显增加，需平衡

---

#### 方向 3: Quiet_mode 实际控制
**当前问题**: 完全禁用控制，依赖主板策略

**替代方案**: 创建"低噪音曲线"而非禁用
```json
// 新增 LowNoise 曲线
{
  "Name": "LowNoise",
  "IdleTemperature": 50,        // 较高启动阈值
  "MinFanSpeed": 15,            // 低转速
  "MaxFanSpeed": 50,            // 限制最大转速
  "LoadTemperature": 85         // 仅在高温时提升
}
```

**优势**: 保持 FanControl 控制，避免主板策略冲突

---

### 3. 配置版本管理建议

#### 命名规范
```
configs/
├── Game.json              # 生产配置（当前版本）
├── Game_v3.2.json         # 历史版本备份
├── Game_v3.3_quiet.json   # 实验配置（降噪测试）
├── Game_v3.3_perf.json    # 实验配置（性能测试）
└── Quiet_mode.json
```

#### Git 管理
```bash
# 配置变更流程
git checkout -b config/optimize-game-v3.3
cp configs/Game.json configs/Game_v3.3_quiet.json
# 修改参数
monitor_simple.ps1  # 采集数据
git add configs/Game_v3.3_quiet.json
git commit -m "config: optimize Game for noise reduction"
# 测试满意后合并到主配置
cp configs/Game_v3.3_quiet.json configs/Game.json
```

---

### 4. 自动化配置切换增强

#### 当前问题
- 固定时段切换，无法根据实际负载调整
- 手动干预需要操作 switch.ps1

#### 未来方向: 负载感知切换
```powershell
# 伪代码示例
$cpuLoad = Get-Counter '\Processor(_Total)\% Processor Time'
if ($cpuLoad -gt 80% -and $currentMode -eq 'Quiet') {
    switch.ps1 -Mode game
    Write-Log "自动切换到 Game 模式（高负载）"
}
```

**挑战**: 需要更频繁的监控，增加系统开销

---

## 配置验证工具

### JSON Schema 验证
```powershell
# 检查配置完整性
function Test-ConfigSchema {
    param($configPath)

    $config = Get-Content $configPath | ConvertFrom-Json

    # 必需字段检查
    $requiredFields = @('__VERSION__', 'FanControl', 'Sensors', 'MainWindow')
    foreach ($field in $requiredFields) {
        if (-not $config.PSObject.Properties.Name -contains $field) {
            throw "配置文件缺少必需字段: $field"
        }
    }

    # 风扇曲线引用检查
    if ($config.FanControl.Controls.Enabled) {
        foreach ($control in $config.FanControl.Controls) {
            if ($control.SelectedFanCurve) {
                $curveExists = $config.FanControl.FanCurves |
                    Where-Object { $_.Name -eq $control.SelectedFanCurve.Name }
                if (-not $curveExists) {
                    throw "风扇曲线不存在: $($control.SelectedFanCurve.Name)"
                }
            }
        }
    }
}
```

---

## 配置迁移检查清单

### 从旧版本升级时
- [ ] 检查 `__VERSION__` 兼容性
- [ ] 验证温度传感器 Identifier 未变化
- [ ] 确认风扇传感器 Identifier 匹配
- [ ] 测试风扇曲线引用完整性
- [ ] 备份当前配置文件

### 跨机器迁移
- [ ] 更新 `FanControlExe` 路径（如不同）
- [ ] 检查传感器硬件兼容性（主板型号可能不同）
- [ ] 重新校准 Calibration 表（风扇型号可能不同）

---

## 监控与调优实践

### 数据采集
```powershell
# 使用 monitor_simple.ps1 采集基准数据
monitor_simple.ps1 -IntervalSeconds 5 -SummaryMinutes 10

# 修改配置后再次采集
# 对比两个 JSON 文件中的温度/转速变化
```

### 数据分析脚本
```powershell
# 分析监控数据
$data = Get-Content "monitor_*.json" | ConvertFrom-Json

# 计算平均温度
$avgTemp = $data | ForEach-Object { $_.CpuPackage } | Measure-Object -Average

# 计算平均转速
$avgFan = $data | ForEach-Object { $_.FanSpeeds.'CPU Fan' } | Measure-Object -Average

Write-Host "平均温度: $([math]::Round($avgTemp.Average, 1))°C"
Write-Host "平均转速: $([math]::Round($avgFan.Average, 0)) RPM"
```

---

## 总结

### 当前配置特点
- ✅ **Game.json**: 主动散热策略，适合高负载场景
- ✅ **Quiet_mode.json**: 完全禁用控制，依赖主板策略
- ⚠️ **Game_ultr.json**: 冗余文件，建议删除或重定义

### 优化方向
1. **短期**: 调整 IdleTemperature/MinFanSpeed 平衡噪音
2. **中期**: 为 Quiet_mode 创建低噪音曲线
3. **长期**: 实现负载感知自动切换

### 配置管理建议
1. 使用 Git 版本控制配置文件
2. 每次修改前备份，标注修改意图
3. 使用 monitor_simple.ps1 验证效果
4. 保留历史配置以便回滚

---

**下一步行动**:
- 选择一个优化方向（建议从"降噪"开始）
- 创建实验配置文件
- 采集对比数据
- 根据结果决定是否合并到生产配置
