# 2026-04-30 Rank 1 Candidate Validation

## 当前状态

- 状态：`pending-real-run`
- candidate：`candidate_rank01_score80.984.json`
- 目标：验证搜索器 rank 1 候选是否优于当前 seed config
- 参考执行稿：[`2026-04-30_candidate-validation-runbook.md`](./2026-04-30_candidate-validation-runbook.md)

当前仓库内还没有以下实测采样目录，因此本文先作为结果记录页骨架保留：

- `docs/experiments/data/2026-04-30_candidate-rank01_GPU-biased-real-game`
- `docs/experiments/data/2026-04-30_candidate-rank01_CPU-plus-GPU-transition`
- `docs/experiments/data/2026-04-30_candidate-rank01_Quiet-recovery-idle`

## 候选摘要

| Item | Value |
|---|---|
| Predicted score | `80.984478` |
| Delta vs seed | `+0.704391` |
| Delta vs baseline | `+3.190480` |
| Seed config | `configs/Game_vNext_stage1_low-rpm.json` |
| Baseline config | `configs/Game.json` |

参数变化：

- `Auto.IdleTemperature = 42`
- `Auto.MinFanSpeed = 20`
- `Auto.LoadTemperature = 80`
- `Auto 1.IdleTemperature = 50`
- `Auto 1.MinFanSpeed = 10`
- `Auto 2.IdleTemperature = 64`
- `Auto 2.MinFanSpeed = 0`
- `Auto 2.LoadTemperature = 72`

## 待采样目录

### Baseline / Seed 对照

- `docs/experiments/data/2026-04-30_seed_GPU-biased-real-game`
- `docs/experiments/data/2026-04-30_seed_CPU-plus-GPU-transition`
- `docs/experiments/data/2026-04-30_seed_Quiet-recovery-idle`

### Rank 1

- `docs/experiments/data/2026-04-30_candidate-rank01_GPU-biased-real-game`
- `docs/experiments/data/2026-04-30_candidate-rank01_CPU-plus-GPU-transition`
- `docs/experiments/data/2026-04-30_candidate-rank01_Quiet-recovery-idle`

## 执行前检查

- [ ] `candidate_rank01_score80.984.json` 已复制到 FanControl live config 目录
- [ ] `override.flag` 已指向 `candidate_rank01_score80.984.json`
- [ ] `check_status.ps1` 确认 `EffectiveConfig` 与目标文件名一致
- [ ] baseline / seed 对照样本已先采集
- [ ] 停止条件已确认：`GpuTemp >= 83C`、`CpuPackage >= 88C`、`MinDistanceToTjMax <= 12C`

## 结果回填

### Baseline / Seed

- config：
- 采样目录：
- 主观噪音备注：
- 结论：

| 场景 | Avg CPU Package | Max CPU Package | Avg GPU Temp | Max GPU Temp | Avg TotalTrackedFanRpm | Auto 2 体感 |
|---|---:|---:|---:|---:|---:|---|
| GPU-biased-real-game |  |  |  |  |  |  |
| CPU-plus-GPU-transition |  |  |  |  |  |  |
| Quiet-recovery-idle |  |  |  |  |  |  |

### Rank 1 实测

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

## 判定

- [ ] 接受为下一轮候选
- [ ] 保持 seed 不变
- [ ] 淘汰并转向 rank 2
- [ ] 先补采样再重训

### 判定理由

- 热安全：
- 主观噪音：
- `Auto 2` 介入平滑度：
- 与模型排序是否一致：

## 下一步

- 如果 rank 1 明显更差，停止后续 rank 2 / rank 3 的 live 验证。
- 如果 rank 1 与 seed 差异不明显，继续按 runbook 验证 rank 2。
- 如果模型判断和实测明显不一致，优先补对应场景采样，再重训 `ridge_cv` 并复搜。
