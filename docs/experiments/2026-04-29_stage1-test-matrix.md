# 2026-04-29 Stage 1 测试矩阵

## 目标

- 不只看温度
- 用同一组核心指标比较不同负载场景下的风扇分级行为
- 为后续回调 `IdleTemperature / MinFanSpeed / LoadTemperature` 提供统一依据

## 核心指标

### 一级指标

- `CPU Package`
- `Core Average`
- `MinDistanceToTjMax`
- `EffectiveClockMHz`
- `CpuLoadPercent`
- `CpuFanRpm`
- `SystemFan2Rpm`
- `SystemFan3Rpm`
- `SystemFan4Rpm`
- `TotalFanRpm`

### 二级指标

- `GPU Temperature`
- `GPU Load`
- `GPU Fan RPM`
- `CPU Package Power`
- `System`
- `VRM MOS`
- `PCH`

### 场景标签

- 前台任务名称
- 分辨率 / 帧率限制
- 内存占用
- 测试时长

说明:

- 内存占用是场景标签，不直接作为风扇曲线调参依据
- 如果一级指标缺失，本轮测试不作为正式调参结论

## 采样规则

- 过渡阶段: `2s` 间隔
- 稳态阶段: `5s` 间隔
- 每轮至少记录:
  - 平均值
  - 峰值
  - 持续时间
  - 是否出现掉频

## 场景矩阵

### 1. 空闲基线

- 时长: `10 min`
- 目标:
  - 找最低可接受总转速
  - 看风扇是否频繁启停
- 重点观察:
  - `TotalFanRpm`
  - `CPU Package`
  - `Core Average`

### 2. 轻度游戏

- 时长: `15 min`
- 目标:
  - 判断 `System Fan #2` 是否介入过早
  - 判断 CPU 风扇是否已经足够兜底
- 重点观察:
  - `CPU Package`
  - `Clock`
  - `SystemFan2Rpm`
  - `TotalFanRpm`

### 3. CPU 偏重负载

- 时长: `10 min`
- 目标:
  - 判断 CPU 风扇曲线是否偏软
  - 判断是否出现频率持续回落
- 重点观察:
  - `CPU Package`
  - `MinDistanceToTjMax`
  - `EffectiveClockMHz`
  - `CpuFanRpm`

### 4. GPU 偏重游戏

- 时长: `15 min`
- 目标:
  - 判断机箱风扇是否介入过晚
  - 避免把 GPU 热积累误判成 CPU 曲线问题
- 重点观察:
  - `GPU Temperature`
  - `GPU Load`
  - `System`
  - `SystemFan3Rpm`
  - `SystemFan4Rpm`

### 5. CPU + GPU 混合高负载

- 时长: `10 min`
- 目标:
  - 判断 `Auto 2` 两路的上限和介入点是否足够
  - 判断总转速换来的温度收益是否值得
- 重点观察:
  - `CPU Package`
  - `Core Average`
  - `MinDistanceToTjMax`
  - `EffectiveClockMHz`
  - `TotalFanRpm`

## Stage 1 通过线

- `CPU Package` 持续游戏负载不长期高于 `85C`
- `Core Average` 不长期高于 `80C`
- `MinDistanceToTjMax` 不长期低于 `15C`
- `EffectiveClockMHz` 不出现持续性回落
- 与旧 `Game.json` 对比，`TotalFanRpm` 有可感知下降

## 回调规则

- 如果 `CPU Package` 过高:
  - 先回调 `Auto`
- 如果 CPU 正常但机箱积热:
  - 优先回调 `Auto 2`
- 如果温度安全但总转速仍高:
  - 优先继续压 `Auto 1`
- 如果只在瞬时尖峰高温:
  - 不立刻改曲线，先看持续时间

## 当前状态

- `2026-04-29 08:49` 起，监控链路已恢复完整共享快照
- 当前可稳定获取:
  - `CPU Package`
  - `Core Average`
  - `Distance to TjMax`
  - `P-Core / E-Core Clock`
  - `CPU Package Power`
  - `System / VRM MOS / PCH`
  - `CPU Fan / System Fan RPM`
  - `GPU Temperature / GPU Fan RPM`
- `idle` 基线已完成:
  - 实验配置: `Game_vNext_stage1_low-rpm.json`
  - 对照配置: `Game.json`
- 已完成的代理负载:
  - `LightGraphicsProxy-WinSAT-DWM`
  - `CpuHeavy-PowerShell`
  - `MixedCpuGpuProxy`
- 当前缺口:
  - 还没有真实应用口径的 `轻度游戏`
  - 还没有更纯粹的 `GPU 偏重`
  - `GPU Load` 当前快照里未见稳定暴露，后续 GPU 场景需要用前台任务和 GPU 温度/风扇行为联合判读
