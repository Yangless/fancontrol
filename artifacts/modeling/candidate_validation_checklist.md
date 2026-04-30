# Candidate Validation Pack

- Validation ID: `2026-04-30_candidate-validation`
- Validation date: `2026-04-30`
- Seed config: `Game_vNext_stage1_low-rpm.json`
- Baseline config: `Game.json`
- Candidate count: `3`

## Candidate Order

| Rank | File | Predicted score | Delta vs seed | Delta vs baseline |
|---|---|---:|---:|---:|
| 1 | candidate_rank01_score80.984.json | 80.984478 | 0.704391 | 3.19048 |
| 2 | candidate_rank02_score80.950.json | 80.949949 | 0.669862 | 3.155951 |
| 3 | candidate_rank03_score80.933.json | 80.932684 | 0.652597 | 3.138686 |

## Run Order

1. 先跑 rank 1。
2. 如果 rank 1 已明显更差或触发停止条件，立即停止，不要继续把更低排名候选写进 live 配置。
3. 只有 rank 1 和 baseline 差异不清楚时，再跑 rank 2 / rank 3。

## Common Checklist

- [ ] 保留 `configs/Game.json` 作为对照，不直接覆盖。
- [ ] 将待测 candidate JSON 复制到 FanControl live config 目录。
- [ ] 手动切到该 candidate，并确认 `EffectiveConfig` 与目标文件名一致。
- [ ] 每个场景采样完成后，把 JSON 放到 manifest 指定的目录。
- [ ] 每轮记录主观噪音备注，尤其是 `Auto 2` 介入的突兀程度。
- [ ] 若触发任一停止条件，立即结束该候选的后续场景。

## Suggested Commands

```powershell
# 1. 复制候选配置到 FanControl live 目录
Copy-Item .\artifacts\modeling\candidates\<candidate_file>.json "D:\Program Files (x86)\FanControl\Configurations\<candidate_file>.json" -Force

# 2. 让 override 直接指向这个 json 文件名
Set-Content -Path "C:\FanControl_Auto\state\override.flag" -Value "<candidate_file>.json"

# 3. 开始采样，按场景分别指定输出目录
pwsh -NoProfile -File .\scripts\current\monitor_simple.ps1 -Mode Sample -IntervalSeconds 5 -MaxSamples 180 -OutputDir .\docs\experiments\data\<sample_dir>
```

## Scenarios

### GPU-biased-real-game

- Duration: `15 min`
- Sample interval: `5 s`
- Goal: 确认 Auto 2 在真实 GPU 升温下是否介入及时且不过吵
- Watch metrics: `GpuTemp`, `Gpu3DUtil`, `SystemTemp`, `SystemFan3Rpm`, `SystemFan4Rpm`, `TotalTrackedFanRpm`
- Stop conditions: `GpuTemp >= 83C`, `CpuPackage >= 88C`, `MinDistanceToTjMax <= 12C`

### CPU-plus-GPU-transition

- Duration: `10 min`
- Sample interval: `2 s`
- Goal: 观察切场景、加载、回桌面等过渡段时风扇响应是否平滑
- Watch metrics: `CpuPackage`, `CoreAverage`, `MinDistanceToTjMax`, `GpuTemp`, `TotalTrackedFanRpm`, `SystemFan3Rpm`, `SystemFan4Rpm`
- Stop conditions: `CpuPackage >= 88C`, `MinDistanceToTjMax <= 12C`

### Quiet-recovery-idle

- Duration: `10 min`
- Sample interval: `5 s`
- Goal: 确认高负载结束回到桌面后，温度恢复和总转速回落是否稳定
- Watch metrics: `CpuPackage`, `GpuTemp`, `CpuFanRpm`, `SystemFan2Rpm`, `SystemFan3Rpm`, `SystemFan4Rpm`, `TotalTrackedFanRpm`

## Candidate Notes

### Rank 1: `candidate_rank01_score80.984.json`

- Predicted score: `80.984478`
- Delta vs seed: `0.704391`
- Delta vs baseline: `3.19048`
- Parameter changes:
  - `Auto.IdleTemperature = 42`
  - `Auto.MinFanSpeed = 20`
  - `Auto.LoadTemperature = 80`
  - `Auto 1.IdleTemperature = 50`
  - `Auto 1.MinFanSpeed = 10`
  - `Auto 2.IdleTemperature = 64`
  - `Auto 2.MinFanSpeed = 0`
  - `Auto 2.LoadTemperature = 72`
- Sample directories:
  - `GPU-biased-real-game` -> `docs/experiments/data/2026-04-30_candidate-rank01_GPU-biased-real-game`
  - `CPU-plus-GPU-transition` -> `docs/experiments/data/2026-04-30_candidate-rank01_CPU-plus-GPU-transition`
  - `Quiet-recovery-idle` -> `docs/experiments/data/2026-04-30_candidate-rank01_Quiet-recovery-idle`

### Rank 2: `candidate_rank02_score80.950.json`

- Predicted score: `80.949949`
- Delta vs seed: `0.669862`
- Delta vs baseline: `3.155951`
- Parameter changes:
  - `Auto.IdleTemperature = 42`
  - `Auto.MinFanSpeed = 20`
  - `Auto.LoadTemperature = 80`
  - `Auto 1.IdleTemperature = 50`
  - `Auto 1.MinFanSpeed = 10`
  - `Auto 2.IdleTemperature = 62`
  - `Auto 2.MinFanSpeed = 0`
  - `Auto 2.LoadTemperature = 72`
- Sample directories:
  - `GPU-biased-real-game` -> `docs/experiments/data/2026-04-30_candidate-rank02_GPU-biased-real-game`
  - `CPU-plus-GPU-transition` -> `docs/experiments/data/2026-04-30_candidate-rank02_CPU-plus-GPU-transition`
  - `Quiet-recovery-idle` -> `docs/experiments/data/2026-04-30_candidate-rank02_Quiet-recovery-idle`

### Rank 3: `candidate_rank03_score80.933.json`

- Predicted score: `80.932684`
- Delta vs seed: `0.652597`
- Delta vs baseline: `3.138686`
- Parameter changes:
  - `Auto.IdleTemperature = 42`
  - `Auto.MinFanSpeed = 20`
  - `Auto.LoadTemperature = 78`
  - `Auto 1.IdleTemperature = 50`
  - `Auto 1.MinFanSpeed = 10`
  - `Auto 2.IdleTemperature = 64`
  - `Auto 2.MinFanSpeed = 0`
  - `Auto 2.LoadTemperature = 72`
- Sample directories:
  - `GPU-biased-real-game` -> `docs/experiments/data/2026-04-30_candidate-rank03_GPU-biased-real-game`
  - `CPU-plus-GPU-transition` -> `docs/experiments/data/2026-04-30_candidate-rank03_CPU-plus-GPU-transition`
  - `Quiet-recovery-idle` -> `docs/experiments/data/2026-04-30_candidate-rank03_Quiet-recovery-idle`

