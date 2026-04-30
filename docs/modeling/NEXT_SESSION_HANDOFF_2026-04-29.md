# 建模阶段交接与待做

> 更新日期：2026-04-30
>
> 这份文档用于给下一次会话直接续接当前进度，避免重新梳理上下文。

## 当前状态

当前仓库已经完成第一版“采样 -> 数据集 -> baseline 评分 -> 候选配置打分 -> 受约束候选搜索”的基础链路。

最近两次本地提交：

- `1be15fa` `feat: add hardware metrics and baseline modeling pipeline`
- `a8c4f35` `chore: ignore python cache artifacts`

工作区状态不要在本文里静态记录，请以实际执行时的 `git status` 为准。

## 已完成内容

### 1. 统一硬件采样

已接入：

- `scripts/current/hardware_metrics.ps1`
- `scripts/current/monitor_simple.ps1`

当前采样已覆盖：

- CPU Package / Core Average / TjMax 余量
- CPU 总负载 / 单核最大负载
- CPU 平均频率 / P-Core / E-Core 频率
- CPU Package 功耗
- 主板 System / VRM MOS / PCH 温度
- GPU 温度 / 3D 利用率
- CPU / 机箱 / GPU 风扇转速
- 当前期望配置 / 实际生效配置 / override 状态

### 2. 第一版建模脚本

已完成脚本：

- `scripts/modeling/build_training_dataset.py`
- `scripts/modeling/train_baseline_model.py`
- `scripts/modeling/score_candidate_config.py`
- `scripts/modeling/search_candidate_configs.py`
- `scripts/modeling/prepare_candidate_validation.py`

已完成文档：

- `docs/modeling/TRAINING_DATA_SCHEMA.md`

### 3. 当前已知验证结果

最近验证时的数据点：

- 原始样本总行数：`143`
- 来源文件数：`11`
- baseline 可用特征数：`61`

当前模型比较结果：

- 默认模型：`ridge_cv`
- `ridge` leave-one-source-out：`MAE 4.005690 / RMSE 6.808604 / R2 0.557187`
- `ridge_cv` leave-one-source-out：`MAE 3.403217 / RMSE 6.105942 / R2 0.643869`
- `random_forest` leave-one-source-out：`MAE 2.761453 / RMSE 6.453033 / R2 0.602230`
- 当前判断：`ridge_cv` 泛化最稳，`random_forest` 可作非线性对照，但还不应替代默认评分器

候选配置对比示例：

- candidate：`configs/Game_vNext_stage1_low-rpm.json`
- baseline：`configs/Game.json`
- candidate 平均预测分：`80.280087`
- baseline 平均预测分：`77.793998`
- 近似提升：`+2.486089`

候选配置分类摘要示例：

- `safe: 136`
- `warn: 7`

搜索器验证结果：

- seed：`configs/Game_vNext_stage1_low-rpm.json`
- 搜索参数维度：`8`
- 有效候选总数：`6561`
- 最优候选平均预测分：`80.984478`
- 相对 seed 提升：`+0.704391`
- 相对 `configs/Game.json` 提升：`+3.190480`
- 最优候选参数示例：
  - `Auto.IdleTemperature = 42`
  - `Auto.MinFanSpeed = 20`
  - `Auto.LoadTemperature = 80`
  - `Auto 1.IdleTemperature = 50`
  - `Auto 1.MinFanSpeed = 10`
  - `Auto 2.IdleTemperature = 64`
  - `Auto 2.MinFanSpeed = 0`
  - `Auto 2.LoadTemperature = 72`

验证包结果：

- 已生成 `candidate_validation_manifest.json`
- 已生成 `candidate_validation_checklist.md`
- 当前默认先验证 top 3 candidates，不直接覆盖 `configs/Game.json`

## 当前建议的下一步

下一步不要直接上深度学习，也不要立刻扩大搜索空间，先把搜索器筛出的前几名候选带回真实负载验证。

原因：

- 当前样本量还不够支撑更重的模型
- 当前标签仍以规则生成标签为主，不是高质量主观标签
- 当前已经有可复用搜索器，下一步价值在于验证它筛出来的候选是否真能在实机上成立

## 已完成的 P0

1. 已新增 `scripts/modeling/search_candidate_configs.py`
2. 已新增 `scripts/modeling/prepare_candidate_validation.py`
3. 已以 `configs/Game_vNext_stage1_low-rpm.json` 作为 seed config
4. 已对有限参数做小范围、可审查的网格搜索
5. 已输出候选配置文件，不直接覆盖 live config
6. 已生成排序摘要和 Markdown 报告
7. 已生成 candidate validation manifest 和 checklist
8. 已为搜索器和验证包补测试
9. 已跑完整 Pester 测试

## 新的优先级 P1

1. 先对 `candidate_search_report.md` 前几名做真实负载验证，不直接写回 `configs/Game.json`
2. 重点观察 `Auto 2` 在 GPU 升温和场景切换时的介入是否更平滑
3. 如果实测结果和模型排序不一致，优先补对应场景采样，再重新训练和复搜
4. 在搜索器基础上继续维持“小范围、可审查、可回滚”的调整节奏

### 第一版搜索器当前参数范围

优先只动以下字段：

- `Auto.IdleTemperature`
- `Auto.MinFanSpeed`
- `Auto.LoadTemperature`
- `Auto 1.IdleTemperature`
- `Auto 1.MinFanSpeed`
- `Auto 2.IdleTemperature`
- `Auto 2.MinFanSpeed`
- `Auto 2.LoadTemperature`

暂缓：

- `System Fan #3/#4` 的 `SelectedStart` / `SelectedStop`
- 更大范围的多参数联动
- 直接写回 `configs/Game.json`

### 第一版搜索器当前输出

- `artifacts/modeling/candidates/*.json`
- `artifacts/modeling/candidate_search_summary.json`
- `artifacts/modeling/candidate_search_report.md`
- `artifacts/modeling/candidate_validation_manifest.json`
- `artifacts/modeling/candidate_validation_checklist.md`

## 后续数据补采建议

虽然当前默认 `ridge_cv` baseline 已经够支持第一版搜索器，但下一轮建议继续补样本，尤其是以下场景：

- 长时间 CPU-only 持续负载
- 长时间 GPU-only 持续负载
- CPU + GPU 混合负载
- 大内存占用但 CPU 不满载的真实使用场景
- 游戏切场景、加载、回桌面这类有突变的过渡段

重点不是只看温度，而是一起保留：

- 温度
- 频率
- 功耗
- 负载
- 风扇响应速度
- 配置切换后的稳定时间

## 已验证命令

构建训练集：

```powershell
python .\scripts\modeling\build_training_dataset.py `
  --input-root .\docs\experiments\data `
  --config-root .\configs `
  --output-dir .\artifacts\modeling
```

训练 baseline：

```powershell
python .\scripts\modeling\train_baseline_model.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --output-dir .\artifacts\modeling
```

候选配置评分：

```powershell
python .\scripts\modeling\score_candidate_config.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --model .\artifacts\modeling\baseline_model.json `
  --candidate-config .\configs\Game_vNext_stage1_low-rpm.json `
  --baseline-config .\configs\Game.json `
  --output-dir .\artifacts\modeling
```

候选配置搜索：

```powershell
python .\scripts\modeling\search_candidate_configs.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --model .\artifacts\modeling\baseline_model.json `
  --seed-config .\configs\Game_vNext_stage1_low-rpm.json `
  --baseline-config .\configs\Game.json `
  --output-dir .\artifacts\modeling
```

准备实机验证包：

```powershell
python .\scripts\modeling\prepare_candidate_validation.py `
  --search-summary .\artifacts\modeling\candidate_search_summary.json `
  --output-dir .\artifacts\modeling `
  --top-n 3 `
  --validation-date 2026-04-30
```

完整测试：

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

## 注意事项

- 保留 `scripts/current/runtime_state.ps1` 对任意 `.json` 文件名 override 的支持，不要回归。
- 不要把 `artifacts/modeling/` 产物误当成仓库源码权威输入。
- 当前 Python 环境按已有实现假设为标准库可用，不依赖第三方包。
- `.gitignore` 已处理 `__pycache__/` 和 `*.pyc`。
