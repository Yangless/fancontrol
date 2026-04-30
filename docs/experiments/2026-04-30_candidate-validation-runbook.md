# 2026-04-30 Candidate Validation Runbook

## 目标

把搜索器筛出的 top-3 candidates 带回真实负载验证，并以统一格式回填结果，避免只留下零散采样 JSON 而没有结论。

当前这轮不是继续扩大搜索空间，而是验证以下问题：

- `ridge_cv` 排名靠前的候选，实机上是否真的优于当前 seed config
- `Auto 2` 在真实 GPU 升温和场景切换时，是否比当前 seed 更平滑
- 若模型排序和实测不一致，应优先补哪些场景数据

## 输入材料

- 搜索摘要：[`../../artifacts/modeling/candidate_search_summary.json`](../../artifacts/modeling/candidate_search_summary.json)
- 验证清单：[`../../artifacts/modeling/candidate_validation_checklist.md`](../../artifacts/modeling/candidate_validation_checklist.md)
- 验证 manifest：[`../../artifacts/modeling/candidate_validation_manifest.json`](../../artifacts/modeling/candidate_validation_manifest.json)
- 当前 seed config：[`../../configs/Game_vNext_stage1_low-rpm.json`](../../configs/Game_vNext_stage1_low-rpm.json)
- 基线 config：[`../../configs/Game.json`](../../configs/Game.json)

## 执行顺序

1. 先保留 `Game.json` 作为对照，不要直接覆盖。
2. 先验证 `candidate_rank01_score80.984.json`。
3. 如果 rank 1 已明显更差，立即停止，不继续写入 rank 2 / rank 3。
4. 只有 rank 1 和 seed / baseline 差异不清楚时，再继续验证 rank 2 / rank 3。
5. 每个候选完成后，立刻把结论和采样目录回填到本文。

## 候选摘要

| Rank | File | Predicted score | Delta vs seed | Delta vs baseline | 主要差异 |
|---|---|---:|---:|---:|---|
| 1 | `candidate_rank01_score80.984.json` | `80.984478` | `+0.704391` | `+3.190480` | `Auto.LoadTemperature=80`, `Auto 1.IdleTemperature=50`, `Auto 1.MinFanSpeed=10`, `Auto 2.IdleTemperature=64`, `Auto 2.LoadTemperature=72` |
| 2 | `candidate_rank02_score80.950.json` | `80.949949` | `+0.669862` | `+3.155951` | 相比 rank 1，`Auto 2.IdleTemperature=62` |
| 3 | `candidate_rank03_score80.933.json` | `80.932684` | `+0.652597` | `+3.138686` | 相比 rank 1，`Auto.LoadTemperature=78` |

## 推荐命令

复制候选配置：

```powershell
Copy-Item .\artifacts\modeling\candidates\candidate_rank01_score80.984.json "D:\Program Files (x86)\FanControl\Configurations\candidate_rank01_score80.984.json" -Force
Copy-Item .\artifacts\modeling\candidates\candidate_rank02_score80.950.json "D:\Program Files (x86)\FanControl\Configurations\candidate_rank02_score80.950.json" -Force
Copy-Item .\artifacts\modeling\candidates\candidate_rank03_score80.933.json "D:\Program Files (x86)\FanControl\Configurations\candidate_rank03_score80.933.json" -Force
```

切到待测候选：

```powershell
Set-Content -Path "C:\FanControl_Auto\state\override.flag" -Value "candidate_rank01_score80.984.json"
pwsh -NoProfile -File .\scripts\current\check_status.ps1
```

示例采样命令：

```powershell
pwsh -NoProfile -File .\scripts\current\monitor_simple.ps1 `
  -Mode Sample `
  -IntervalSeconds 5 `
  -MaxSamples 180 `
  -OutputDir .\docs\experiments\data\2026-04-30_candidate-rank01_GPU-biased-real-game
```

## 场景设计

### 1. GPU-biased-real-game

- 时长：`15 min`
- 间隔：`5 s`
- 目标：确认 `Auto 2` 在真实 GPU 升温时是否介入及时且不过吵
- 重点指标：`GpuTemp`、`Gpu3DUtil`、`SystemFan3Rpm`、`SystemFan4Rpm`、`TotalTrackedFanRpm`
- 停止条件：`GpuTemp >= 83C`、`CpuPackage >= 88C`、`MinDistanceToTjMax <= 12C`

建议采样目录：

- rank 1：`docs/experiments/data/2026-04-30_candidate-rank01_GPU-biased-real-game`
- rank 2：`docs/experiments/data/2026-04-30_candidate-rank02_GPU-biased-real-game`
- rank 3：`docs/experiments/data/2026-04-30_candidate-rank03_GPU-biased-real-game`

### 2. CPU-plus-GPU-transition

- 时长：`10 min`
- 间隔：`2 s`
- 目标：观察切场景、加载、回桌面时风扇响应是否平滑
- 重点指标：`CpuPackage`、`GpuTemp`、`SystemFan3Rpm`、`SystemFan4Rpm`、`TotalTrackedFanRpm`
- 停止条件：`CpuPackage >= 88C`、`MinDistanceToTjMax <= 12C`

建议采样目录：

- rank 1：`docs/experiments/data/2026-04-30_candidate-rank01_CPU-plus-GPU-transition`
- rank 2：`docs/experiments/data/2026-04-30_candidate-rank02_CPU-plus-GPU-transition`
- rank 3：`docs/experiments/data/2026-04-30_candidate-rank03_CPU-plus-GPU-transition`

### 3. Quiet-recovery-idle

- 时长：`10 min`
- 间隔：`5 s`
- 目标：确认高负载结束回桌面后温度恢复和转速回落是否稳定
- 重点指标：`CpuPackage`、`GpuTemp`、`CpuFanRpm`、`SystemFan2Rpm`、`SystemFan3Rpm`、`SystemFan4Rpm`、`TotalTrackedFanRpm`

建议采样目录：

- rank 1：`docs/experiments/data/2026-04-30_candidate-rank01_Quiet-recovery-idle`
- rank 2：`docs/experiments/data/2026-04-30_candidate-rank02_Quiet-recovery-idle`
- rank 3：`docs/experiments/data/2026-04-30_candidate-rank03_Quiet-recovery-idle`

## 回填模板

### 基线对照

- config：`Game.json`
- 采样目录：
- 主观噪音备注：
- 结论：

| 场景 | Avg CPU Package | Max CPU Package | Avg GPU Temp | Max GPU Temp | Avg TotalTrackedFanRpm | Auto 2 体感 |
|---|---:|---:|---:|---:|---:|---|
| GPU-biased-real-game |  |  |  |  |  |  |
| CPU-plus-GPU-transition |  |  |  |  |  |  |
| Quiet-recovery-idle |  |  |  |  |  |  |

### Rank 1

- config：`candidate_rank01_score80.984.json`
- 采样目录：
- 主观噪音备注：
- 是否触发停止条件：
- 结论：

| 场景 | Avg CPU Package | Max CPU Package | Avg GPU Temp | Max GPU Temp | Avg TotalTrackedFanRpm | Auto 2 体感 |
|---|---:|---:|---:|---:|---:|---|
| GPU-biased-real-game |  |  |  |  |  |  |
| CPU-plus-GPU-transition |  |  |  |  |  |  |
| Quiet-recovery-idle |  |  |  |  |  |  |

### Rank 2

- config：`candidate_rank02_score80.950.json`
- 采样目录：
- 主观噪音备注：
- 是否触发停止条件：
- 结论：

| 场景 | Avg CPU Package | Max CPU Package | Avg GPU Temp | Max GPU Temp | Avg TotalTrackedFanRpm | Auto 2 体感 |
|---|---:|---:|---:|---:|---:|---|
| GPU-biased-real-game |  |  |  |  |  |  |
| CPU-plus-GPU-transition |  |  |  |  |  |  |
| Quiet-recovery-idle |  |  |  |  |  |  |

### Rank 3

- config：`candidate_rank03_score80.933.json`
- 采样目录：
- 主观噪音备注：
- 是否触发停止条件：
- 结论：

| 场景 | Avg CPU Package | Max CPU Package | Avg GPU Temp | Max GPU Temp | Avg TotalTrackedFanRpm | Auto 2 体感 |
|---|---:|---:|---:|---:|---:|---|
| GPU-biased-real-game |  |  |  |  |  |  |
| CPU-plus-GPU-transition |  |  |  |  |  |  |
| Quiet-recovery-idle |  |  |  |  |  |  |

## 结果判定规则

- 如果某 candidate 在 GPU-biased 场景下明显更热，或更早触发停止条件，直接淘汰。
- 如果温度相近但 `Auto 2` 的体感突兀更强，也不应仅凭模型分数接受。
- 如果 rank 1 和 rank 2 都不成立，优先回到对应场景补采样，再重训与复搜。
- 只有当实测和主观噪音都不差于 seed / baseline 时，才考虑提升为下一轮 accepted candidate。
