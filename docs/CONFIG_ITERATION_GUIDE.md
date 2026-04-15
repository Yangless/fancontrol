# 配置文件迭代改进方法指南

> **目标**: 建立一套可重复、可验证的配置优化流程

## 路径约定

- 仓库快照：`configs/`
- FanControl live config：`D:\Program Files (x86)\FanControl\Configurations\`
- 先修改仓库快照，再决定是否部署到 live config 目录进行测试

---

## 核心方法论

### 三步循环法
```
修改 → 测试 → 评估 → (满意则合并，不满意则调整)
```

---

## 第一步：配置修改

### 修改原则
1. **单参数原则**: 每次只修改一个参数
2. **小步原则**: 参数调整幅度控制在 10-20%
3. **记录原则**: 在文件名和注释中说明修改意图

### 修改流程

#### 1. 创建实验配置
```powershell
# 命名规范: <基础配置>_<版本号>_<优化目标>.json
Copy-Item .\configs\Game.json .\configs\Game_v3.3_quiet-test.json
```

#### 2. 添加元数据（可选）
```json
{
  "__VERSION__": "262",
  "__CUSTOM__": {
    "description": "降噪测试配置 v3.3",
    "base_version": "v3.2",
    "modified_params": ["IdleTemperature", "MinFanSpeed"],
    "date": "2026-04-13"
  },
  "FanControl": { ... }
}
```

#### 3. 修改目标参数
使用文本编辑器或 JSON 编辑工具:
```json
// 修改前
"IdleTemperature": 35,
"MinFanSpeed": 30,

// 修改后
"IdleTemperature": 40,  // 35→40: 提高启动阈值，降低噪音
"MinFanSpeed": 25,      // 30→25: 允许更低转速
```

---

## 第二步：测试验证

### 使用 monitor_simple.ps1 采集数据

#### 基准测试（修改前）
```powershell
# 1. 确保使用原始配置
FanControl.exe -c "D:\Program Files (x86)\FanControl\Configurations\Game.json"

# 2. 启动监控
C:\FanControl_Auto\monitor_simple.ps1 -IntervalSeconds 5 -SummaryMinutes 10

# 3. 等待 10 分钟，保存为 baseline
# 输出文件: monitor_20260413_100000.json
Move-Item .\monitor_20260413_100000.json .\baseline_game_v3.2.json
```

#### 实验测试（修改后）
```powershell
# 1. 切换到实验配置
Copy-Item .\configs\Game_v3.3_quiet-test.json "D:\Program Files (x86)\FanControl\Configurations\Game_v3.3_quiet-test.json" -Force
FanControl.exe -c "D:\Program Files (x86)\FanControl\Configurations\Game_v3.3_quiet-test.json"

# 2. 启动监控
C:\FanControl_Auto\monitor_simple.ps1 -IntervalSeconds 5 -SummaryMinutes 10

# 3. 等待 10 分钟，保存为实验结果
# 输出文件: monitor_20260413_110000.json
Move-Item .\monitor_20260413_110000.json .\experiment_game_v3.3_quiet.json
```

---

## 第三步：效果评估

### 评估维度

| 维度 | 指标 | 评估方法 |
|------|------|---------|
| 温度 | CPU Package 峰值/平均值 | JSON 数据分析 |
| 转速 | 风扇 RPM 峰值/平均值 | JSON 数据分析 |
| 噪音 | 主观感受 (1-10 分) | 人工评分 |
| 性能 | CPU 频率/负载 | 任务管理器监控 |

### 数据分析脚本
```powershell
# analysis.ps1
param($baselineFile, $experimentFile)

$baseline = Get-Content $baselineFile | ConvertFrom-Json
$experiment = Get-Content $experimentFile | ConvertFrom-Json

function Get-Stats {
    param($data, $property)
    $values = $data | ForEach-Object { $_.$property }
    return @{
        Avg = [math]::Round(($values | Measure-Object -Average).Average, 1)
        Max = [math]::Round(($values | Measure-Object -Maximum).Maximum, 1)
        Min = [math]::Round(($values | Measure-Object -Minimum).Minimum, 1)
    }
}

$cpuBase = Get-Stats $baseline 'CpuPackage'
$cpuExp = Get-Stats $experiment 'CpuPackage'

Write-Host "=== CPU Package 温度对比 ==="
Write-Host "基准: 平均 $([math]::Round($cpuBase.Avg, 1))°C, 最高 $($cpuBase.Max)°C"
Write-Host "实验: 平均 $([math]::Round($cpuExp.Avg, 1))°C, 最高 $($cpuExp.Max)°C"
Write-Host "变化: 平均 $([math]::Round($cpuExp.Avg - $cpuBase.Avg, 1))°C"

# 转速对比
$fanBase = Get-Stats $baseline 'FanCpu'
$fanExp = Get-Stats $experiment 'FanCpu'

Write-Host "`n=== CPU 风扇转速对比 ==="
Write-Host "基准: 平均 $([math]::Round($fanBase.Avg, 0)) RPM, 最高 $($fanBase.Max) RPM"
Write-Host "实验: 平均 $([math]::Round($fanExp.Avg, 0)) RPM, 最高 $($fanExp.Max) RPM"
Write-Host "变化: 平均 $([math]::Round($fanExp.Avg - $fanBase.Avg, 0)) RPM"
```

### 评估标准

#### 可接受范围
- **温度**: 平均升高 < 3°C，峰值升高 < 5°C
- **转速**: 平均降低 > 100 RPM 视为降噪有效
- **噪音**: 主观评分改善 ≥ 1 分

#### 优秀范围
- **温度**: 无明显升高（< 1°C）
- **转速**: 平均降低 > 200 RPM
- **噪音**: 主观评分改善 ≥ 2 分

---

## 第四步：决策与合并

### 决策矩阵

| 温度变化 | 转速变化 | 噪音改善 | 决策 |
|---------|---------|---------|------|
| < +3°C | -100~200 RPM | 有改善 | ✅ 接受 |
| < +1°C | > -200 RPM | 明显改善 | ✅ 优秀，接受 |
| > +5°C | < -100 RPM | 无改善 | ❌ 拒绝 |
| > +3°C | < -50 RPM | 有改善 | ⚠️ 需权衡 |

### 合并流程
```powershell
# 接受实验配置
Copy-Item .\configs\Game_v3.3_quiet-test.json .\configs\Game.json -Force
Copy-Item .\configs\Game.json "D:\Program Files (x86)\FanControl\Configurations\Game.json" -Force
Write-Log "配置升级: v3.2 → v3.3 (降噪优化)"

# Git 提交
git add .\configs\Game.json
git commit -m "config: upgrade to v3.3 (quiet optimization)

- IdleTemperature: 35 → 40
- MinFanSpeed: 30 → 25
- Test result: avg temp +0.8°C, avg RPM -180, noise improved by 2/10"
```

### 拒绝处理
```powershell
# 回滚到原始配置
FanControl.exe -c "D:\Program Files (x86)\FanControl\Configurations\Game.json"

# 归档实验配置（供参考）
New-Item -ItemType Directory -Force .\archive\failed_experiments | Out-Null
Move-Item .\configs\Game_v3.3_quiet-test.json .\archive\failed_experiments\
Add-Content .\archive\failed_experiments\README.md "实验失败原因: 温度升高超过阈值"
```

---

## 高级技巧

### 1. 多参数正交实验
当需要同时调整多个参数时，使用正交设计减少测试次数

**示例**: 调整 IdleTemperature 和 MinFanSpeed
```
实验1: IdleTemperature=40, MinFanSpeed=25
实验2: IdleTemperature=40, MinFanSpeed=30
实验3: IdleTemperature=45, MinFanSpeed=25
实验4: IdleTemperature=45, MinFanSpeed=30
```
分析哪个组合效果最好

### 2. 负载场景测试
在不同负载条件下测试配置:

```powershell
# 空载测试
monitor_simple.ps1 -IntervalSeconds 5 -SummaryMinutes 5
# (不运行任何程序)

# 游戏负载测试
start_game.exe  # 启动游戏
monitor_simple.ps1 -IntervalSeconds 5 -SummaryMinutes 15
# (运行游戏 15 分钟)

# 压力测试
stress_cpu.exe  # CPU 压力测试工具
monitor_simple.ps1 -IntervalSeconds 2 -SummaryMinutes 5
```

### 3. 长期稳定性测试
```powershell
# 24小时稳定性测试
monitor_simple.ps1 -IntervalSeconds 30 -SummaryMinutes 1440
# 每 30 秒采样，持续 24 小时
```

---

## 配置版本管理最佳实践

### Git 工作流
```powershell
# 创建配置优化分支
git checkout -b config/optimize-quiet-v3.3

# 创建实验配置
Copy-Item .\configs\Game.json .\configs\Game_v3.3_test.json

# 修改配置...

# 提交实验配置
git add .\configs\Game_v3.3_test.json
git commit -m "WIP: quiet optimization v3.3"

# 测试完成后
# 如果满意，合并到主配置
Copy-Item .\configs\Game_v3.3_test.json .\configs\Game.json -Force
git add .\configs\Game.json
git commit -m "config: upgrade to v3.3 (quiet optimization)"

# 推送到远程
git push origin main

# 打标签
git tag -a v3.3 -m "配置版本 3.3 - 降噪优化"
git push origin v3.3
```

### 配置回滚
```powershell
# 如果新配置有问题，快速回滚
git checkout v3.2 -- .\configs\Game.json
git commit -m "rollback: revert to v3.2 due to thermal issues"
```

---

## 配置优化清单模板

### 实验记录表
```markdown
## 实验: Game_v3.3_quiet-test

**开始时间**: 2026-04-13 10:00
**结束时间**: 2026-04-13 10:10

**修改参数**:
- IdleTemperature: 35 → 40 (+14%)
- MinFanSpeed: 30 → 25 (-17%)

**测试条件**:
- 负载: 空载 + 10 分钟 Cinebench
- 环境温度: 25°C

**测试结果**:
| 指标 | 基准 | 实验 | 变化 |
|------|------|------|------|
| 平均温度 | 52.3°C | 53.1°C | +0.8°C |
| 峰值温度 | 78.5°C | 81.2°C | +2.7°C |
| 平均转速 | 1120 RPM | 940 RPM | -180 RPM |
| 噪音评分 | 6/10 | 4/10 | -2 (改善) |

**决策**: ✅ 接受
**理由**: 温度升高在可接受范围内，噪音明显改善

**合并时间**: 2026-04-13 11:00
```

---

## 常见问题处理

### Q1: 修改后温度明显升高怎么办？
**解决**:
1. 检查 MinFanSpeed 是否过低
2. 降低 IdleTemperature 提高启动温度阈值
3. 增加 MaxFanSpeed 允许更高转速

### Q2: 风扇频繁启停怎么办？
**解决**:
1. 增加 Deadband 参数（从 3 → 5）
2. 增加 SelectedResponseTime（从 2 → 4 秒）
3. 降低 Step 参数减少敏感度

### Q3: 不同风扇转速差异大怎么办？
**解决**:
1. 检查 Calibration 校准表是否正确
2. 统一相同位置风扇的风扇曲线
3. 考虑使用相同型号风扇

---

## 自动化工具（未来扩展）

### Python 配置生成器
```python
# generate_config.py (示例)
import json

def create_quiet_config(base_config, reduction_percent):
    with open(base_config) as f:
        config = json.load(f)

    for curve in config['FanControl']['FanCurves']:
        curve['MinFanSpeed'] *= (1 - reduction_percent / 100)
        curve['IdleTemperature'] += 5

    return config
```

### PowerShell 验证脚本
```powershell
# validate_config.ps1
param($configPath)

$config = Get-Content $configPath | ConvertFrom-Json

# 检查必需字段
$requiredFields = @('__VERSION__', 'FanControl', 'Sensors')
foreach ($field in $requiredFields) {
    if (-not $config.$field) {
        throw "缺少字段: $field"
    }
}

# 检查风扇曲线引用
foreach ($control in $config.FanControl.Controls) {
    if ($control.Enable -and $control.SelectedFanCurve) {
        $curveExists = $config.FanControl.FanCurves |
            Where-Object { $_.Name -eq $control.SelectedFanCurve.Name }
        if (-not $curveExists) {
            throw "无效的风扇曲线引用: $($control.SelectedFanCurve.Name)"
        }
    }
}

Write-Host "✅ 配置验证通过"
```

---

## 总结

### 核心原则
1. **小步迭代**: 每次只改一个参数
2. **数据驱动**: 用 monitor_simple.ps1 采集客观数据
3. **版本管理**: Git 跟踪每次修改
4. **快速回滚**: 保留历史配置备份

### 下一步行动
1. 选择一个优化目标（建议从降噪开始）
2. 按照本指南创建实验配置
3. 采集对比数据并评估
4. 根据结果决定是否合并

---

**维护者**: 请将每次成功/失败的实验记录保存到 `docs/experiments/` 目录
