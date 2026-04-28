# FanControl 硬件采样与调参监控设计

## 目标

为当前仓库增加一层可复用的硬件采样能力，使后续 `Game.json` 的风扇分级调参可以基于实际运行数据，而不是只看配置切换状态或主观体感。

本次设计的直接目标不是立刻自动调参，而是先建立一条可靠的观测链路，能够持续记录：

- CPU 温度
- CPU 频率
- CPU 负载
- 各风扇 RPM
- 总风扇 RPM
- 当前运行配置状态

## 背景

当前仓库中的 `scripts/current/monitor_simple.ps1` 只记录运行状态层信息，例如：

- 当前目标配置
- 当前实际配置
- 进程是否运行
- 配置验证置信度

它可以证明“配置有没有切过去”，但不能回答下面这些调参核心问题：

- 轻载时总风扇 RPM 是否过高
- 某一级风扇是否介入过早
- 温度升高时是否已经接近热上限
- CPU 是否因为温度或相关限制开始掉频

因此，需要把“运行状态采样”和“硬件指标采样”拆开建模，再由监控脚本统一输出。

## 设计原则

### 1. 分层，而不是堆叠

不要把所有硬件采集逻辑直接塞进 `monitor_simple.ps1`。应把职责拆成：

- `runtime_state.ps1`
  - 回答“当前配置状态是什么”
- `hardware_metrics.ps1`
  - 回答“当前硬件指标是多少”
- `monitor_simple.ps1`
  - 回答“按什么模式采样、怎么输出、怎么落盘”

### 2. 复用 FanControl 现有依赖

优先复用 FanControl 安装目录自带的 `LibreHardwareMonitorLib.dll`，避免依赖额外常驻工具或手工导出日志。

目标库路径：

- `D:\Program Files (x86)\FanControl\LibreHardwareMonitorLib.dll`

### 3. 第一版先保证可观测，再考虑高级分析

首版不追求复杂统计报表，只要求：

- 样本结构稳定
- 关键字段足够判断风扇分级是否合理
- 采样失败时能降级，不轻易中断整轮记录

### 4. 调参闭环必须明确

采样不是为了“多记录一点数据”，而是为了支持后续判断：

- 是否推迟某一级风扇介入
- 是否降低某一级最低转速
- 是否需要让某一级更早接力

## 架构设计

### 新增脚本

- `scripts/current/hardware_metrics.ps1`

公开入口：

```powershell
function Get-FanControlHardwareMetrics { }
```

### 现有脚本调整

- `scripts/current/monitor_simple.ps1`
  - 加载 `hardware_metrics.ps1`
  - 调用 `Get-FanControlRuntimeState`
  - 调用 `Get-FanControlHardwareMetrics`
  - 合并后输出统一样本

### 现有运行状态层保持不变

- `scripts/current/runtime_state.ps1`
  - 继续只负责配置与进程状态
  - 不混入温度、频率、RPM 采集逻辑

## 数据来源设计

### 主数据源

优先使用 `LibreHardwareMonitorLib.dll` 读取：

- CPU 温度
- Core Average
- Distance to TjMax
- 各风扇 RPM
- CPU 相关频率或时钟指标
- CPU Load 指标

### 回退数据源

如果 `LibreHardwareMonitorLib` 无法稳定返回 CPU 频率或负载，则允许回退到 `Get-Counter`：

- `\Processor Information(_Total)\% Processor Utility`
- `\Processor Information(_Total)\Processor Frequency`

### 数据来源选择规则

- 温度和 RPM：优先 `LibreHardwareMonitorLib`
- 频率和负载：优先 `LibreHardwareMonitorLib`，失败时回退 `Get-Counter`

## 首版采样字段

`Get-FanControlHardwareMetrics` 首版至少返回以下字段：

- `CpuPackage`
- `CoreAverage`
- `MinDistanceToTjMax`
- `CpuLoadPercent`
- `EffectiveClockMHz`
- `CpuFanRpm`
- `SystemFan2Rpm`
- `SystemFan3Rpm`
- `SystemFan4Rpm`
- `TotalFanRpm`
- `DataConfidence`

### 字段语义

- `CpuPackage`
  - CPU 主安全指标
- `CoreAverage`
  - 机箱风扇分级更适合参考的 CPU 热积累指标
- `MinDistanceToTjMax`
  - 当前距离热墙的最小余量
- `CpuLoadPercent`
  - 用于比较不同测试窗口时的负载一致性
- `EffectiveClockMHz`
  - 用于判断是否出现掉频或频率回落
- `TotalFanRpm`
  - 本次调参最关键的总量指标

### `TotalFanRpm` 计算规则

```text
CpuFanRpm + SystemFan2Rpm + SystemFan3Rpm + SystemFan4Rpm
```

如果某一项缺失：

- 缺失字段保留为 `null`
- `TotalFanRpm` 按可用项求和
- 置信度降级

## 采样结果结构

每个样本应由两层组成：

- `Runtime`
- `Hardware`

示例：

```json
{
  "Timestamp": "2026-04-28 16:20:00",
  "Runtime": {
    "DesiredConfig": "Game.json",
    "EffectiveConfig": "Game.json",
    "ProcessRunning": true,
    "VerificationConfidence": "High",
    "StateConfidence": "High"
  },
  "Hardware": {
    "CpuPackage": 58.2,
    "CoreAverage": 54.8,
    "MinDistanceToTjMax": 41,
    "CpuLoadPercent": 27.4,
    "EffectiveClockMHz": 4780,
    "CpuFanRpm": 620,
    "SystemFan2Rpm": 0,
    "SystemFan3Rpm": 0,
    "SystemFan4Rpm": 0,
    "TotalFanRpm": 620,
    "DataConfidence": "High"
  }
}
```

## `monitor_simple.ps1` 行为设计

### 模式保留

继续保留当前三种模式：

- `Snapshot`
- `Watch`
- `Sample`

### 调用顺序

每轮采样固定为：

1. `Get-FanControlRuntimeState`
2. `Get-FanControlHardwareMetrics`
3. 合并样本
4. 输出摘要
5. 按模式决定是否写文件

### 控制台摘要

建议输出格式：

```text
[2026-04-28 16:20:00] Config:Game.json CPU:58.2C CoreAvg:54.8C Dist:41C Load:27.4% Clock:4780MHz Fans:620/0/0/0 Total:620
```

### 落盘格式

`Sample` 模式继续保留批量样本外层包装：

```json
{
  "Mode": "Sample",
  "StartedAt": "...",
  "EndedAt": "...",
  "SampleCount": 120,
  "Samples": [ ... ]
}
```

首版不额外生成复杂统计摘要，避免在采样层过早耦合分析逻辑。

## 错误处理设计

### 总体策略

尽量采样，尽量落盘，不因单个字段失败中断整轮监控。

### 具体规则

- 单个温度字段读取失败：字段写 `null`
- 单个 RPM 字段读取失败：字段写 `null`
- 频率或负载主路径失败但回退成功：继续输出，置信度降为 `Medium`
- 关键 CPU 温度字段缺失：继续输出，置信度降为 `Low`
- 只有在 helper 初始化失败时才中止脚本

### `DataConfidence` 规则

- `High`
  - 温度、频率、负载、RPM 主字段均可用
- `Medium`
  - 温度和 RPM 可用，但频率或负载依赖回退路径，或部分非关键字段缺失
- `Low`
  - 关键温度字段缺失，或硬件采样严重不完整

## 测试设计

新增测试文件：

- `tests/FanControl.HardwareMetrics.Tests.ps1`

首版至少覆盖：

- 能返回统一硬件对象
- 频率读取失败时可回退到 `Get-Counter`
- 单个风扇 RPM 缺失时 `TotalFanRpm` 仍可计算
- 关键温度缺失时 `DataConfidence` 正确降级
- `monitor_simple.ps1` 每条样本同时包含 `Runtime` 和 `Hardware`

## 如何用这些数据回调风扇分级

后续调 `Game.json` 时，按以下顺序判断：

### 1. 先看 `TotalFanRpm`

如果总 RPM 偏高，但：

- `CpuPackage` 很低
- `MinDistanceToTjMax` 余量很大
- `EffectiveClockMHz` 稳定

则说明后级风扇介入过早，应优先推迟：

- `System Fan #2`
- `System Fan #4`
- `System Fan #3`

### 2. 再看温度与热余量

如果：

- `CpuPackage` 长时间逼近 `85~90°C`
- `MinDistanceToTjMax` 经常接近 `10°C`

则说明分级过于保守，需要让中后级更早介入。

### 3. 再看 `EffectiveClockMHz`

如果频率明显回落，则需要判断：

- 是否温度导致
- 是否功耗/电流/主板策略限制导致

不能只因为频率下降就简单提高风扇。

### 4. 最后看 `CpuLoadPercent`

调参比较必须尽量在相近负载窗口下进行，否则不同轮次的 RPM/温度对比会失真。

## 调参顺序建议

每次只改一层，或一组强相关参数。

优先顺序：

1. `IdleTemperature`
2. `MinFanSpeed`
3. `LoadTemperature`
4. `Deadband`
5. `ResponseTime`

具体建议：

- 想压低轻载总 RPM：先推迟 `System Fan #2`
- 想压低中载总 RPM：再推迟 `System Fan #4`
- 想守住高负载温度：最后调整 `System Fan #3`
- `CPU Fan` 只做小改，尽量保持为最稳定的一层

## 非目标

本次设计不包含：

- 自动修改 `Game.json`
- 自动寻找最优曲线
- 引入外部常驻监控工具
- 在第一版中生成复杂统计报表

## 成功标准

完成后，应满足：

- 仓库内可以独立采集 `温度 / 频率 / 负载 / 风扇 RPM / 总 RPM`
- `monitor_simple.ps1` 的样本可同时反映运行状态和硬件状态
- 数据缺失时脚本可以降级而不是直接失效
- 后续调 `Game.json` 时有明确的数据闭环，而不是只靠主观体感
