# FanControl 训练数据 Schema

## 目标

本 schema 用于把 `docs/experiments/data/` 里的原始采样结果统一整理成“可训练”的行级样本，供后续：

- 风扇曲线评分模型
- 配置参数建议模型
- 受约束的曲线搜索器

共同复用。

当前第一版不是直接训练“在线控风扇”的模型，而是先训练一个 **baseline 评分模型**，判断某一组配置在某类负载下更偏向：

- 更安全
- 更安静
- 更值得作为下一轮候选方案

## 行格式

当前训练集按 **一条采样点 = 一行** 展开，但每行会额外带上轻量级时序窗口特征。

主输出文件：

- `training_rows.jsonl`
- `training_rows.csv`

每一行都是扁平结构，方便 Python / PowerShell / 表格工具直接读取。

## 字段分组

### 1. 元数据字段

| 字段 | 类型 | 含义 |
|---|---|---|
| `schema_version` | string | 当前 schema 版本 |
| `source_file` | string | 原始 JSON 文件相对路径 |
| `source_kind` | string | 原始文件结构类型：`array` / `wrapped-samples` / `single-object` |
| `sample_index` | int | 样本在原文件内的顺序 |
| `scenario_name` | string | 场景名，优先取样本内 `Scenario`，否则退回文件名 |
| `workload_class` | string | 规则推断出的负载类别，例如 `idle` / `cpu-biased` / `gpu-biased` / `mixed` |
| `sample_timestamp` | string | 原始采样时间戳 |
| `desired_config` | string | 期望配置名 |
| `effective_config` | string | 实际生效配置名 |
| `override_mode` | string | override 标记内容 |
| `config_profile_name` | string | 用于附加配置特征的配置文件名 |
| `config_custom_status` | string | 配置里的 `__CUSTOM__.status`，如果存在 |
| `config_base_config` | string | 配置里的 `__CUSTOM__.base_config`，如果存在 |

### 2. 原始硬件特征

| 字段 | 类型 | 含义 |
|---|---|---|
| `cpu_package_c` | number/null | CPU Package 温度 |
| `core_average_c` | number/null | Core Average |
| `min_distance_to_tjmax_c` | number/null | 距离热墙的最小余量 |
| `cpu_total_load_pct` | number/null | CPU 总负载 |
| `cpu_core_max_load_pct` | number/null | 单核最大负载 |
| `cpu_clock_avg_mhz` | number/null | CPU 平均频率 |
| `pcore_clock_avg_mhz` | number/null | P-Core 平均频率 |
| `ecore_clock_avg_mhz` | number/null | E-Core 平均频率 |
| `cpu_package_power_w` | number/null | CPU Package 功耗 |
| `system_temp_c` | number/null | 主板 System 温度 |
| `vrm_mos_temp_c` | number/null | VRM MOS 温度 |
| `pch_temp_c` | number/null | PCH 温度 |
| `gpu_temp_c` | number/null | GPU 温度 |
| `gpu_3d_util_pct` | number/null | GPU 3D 利用率 |
| `cpu_fan_rpm` | number/null | CPU 风扇转速 |
| `system_fan2_rpm` | number/null | System Fan #2 转速 |
| `system_fan3_rpm` | number/null | System Fan #3 转速 |
| `system_fan4_rpm` | number/null | System Fan #4 转速 |
| `gpu_fan1_rpm` | number/null | GPU Fan 1 转速 |
| `gpu_fan2_rpm` | number/null | GPU Fan 2 转速 |
| `total_case_fan_rpm` | number/null | 机箱风扇总转速 |
| `total_tracked_fan_rpm` | number/null | 当前建模口径下总转速 |

### 3. 配置曲线特征

这部分特征来自 `configs/*.json`，不是运行期采样本身。

| 字段 | 类型 | 含义 |
|---|---|---|
| `cfg_auto_idle_temp_c` | number/null | `Auto.IdleTemperature` |
| `cfg_auto_min_speed_pct` | number/null | `Auto.MinFanSpeed` |
| `cfg_auto_max_speed_pct` | number/null | `Auto.MaxFanSpeed` |
| `cfg_auto_load_temp_c` | number/null | `Auto.LoadTemperature` |
| `cfg_auto_temp_source` | string/null | `Auto.SelectedTempSource.Identifier` |
| `cfg_auto_uses_gpu_temp` | number | 是否使用 GPU 温度源 |
| `cfg_auto1_idle_temp_c` | number/null | `Auto 1.IdleTemperature` |
| `cfg_auto1_min_speed_pct` | number/null | `Auto 1.MinFanSpeed` |
| `cfg_auto1_max_speed_pct` | number/null | `Auto 1.MaxFanSpeed` |
| `cfg_auto1_load_temp_c` | number/null | `Auto 1.LoadTemperature` |
| `cfg_auto1_temp_source` | string/null | `Auto 1` 温度源 |
| `cfg_auto1_uses_gpu_temp` | number | `Auto 1` 是否用 GPU 温度源 |
| `cfg_auto2_idle_temp_c` | number/null | `Auto 2.IdleTemperature` |
| `cfg_auto2_min_speed_pct` | number/null | `Auto 2.MinFanSpeed` |
| `cfg_auto2_max_speed_pct` | number/null | `Auto 2.MaxFanSpeed` |
| `cfg_auto2_load_temp_c` | number/null | `Auto 2.LoadTemperature` |
| `cfg_auto2_temp_source` | string/null | `Auto 2` 温度源 |
| `cfg_auto2_uses_gpu_temp` | number | `Auto 2` 是否用 GPU 温度源 |
| `cfg_cpu_fan_start_pct` | number/null | CPU Fan `SelectedStart` |
| `cfg_cpu_fan_stop_pct` | number/null | CPU Fan `SelectedStop` |
| `cfg_system_fan2_start_pct` | number/null | System Fan #2 `SelectedStart` |
| `cfg_system_fan2_stop_pct` | number/null | System Fan #2 `SelectedStop` |
| `cfg_system_fan3_start_pct` | number/null | System Fan #3 `SelectedStart` |
| `cfg_system_fan3_stop_pct` | number/null | System Fan #3 `SelectedStop` |
| `cfg_system_fan4_start_pct` | number/null | System Fan #4 `SelectedStart` |
| `cfg_system_fan4_stop_pct` | number/null | System Fan #4 `SelectedStop` |

### 4. 派生特征

| 字段 | 类型 | 含义 |
|---|---|---|
| `cpu_soft_margin_c` | number/null | `85 - cpu_package_c` |
| `gpu_soft_margin_c` | number/null | `78 - gpu_temp_c` |
| `tjmax_soft_margin_c` | number/null | `min_distance_to_tjmax_c - 15` |
| `case_fan_share` | number/null | `total_case_fan_rpm / total_tracked_fan_rpm` |
| `gpu_assist_share` | number/null | `(system_fan3_rpm + system_fan4_rpm) / total_case_fan_rpm` |
| `fan_per_cpu_w` | number/null | `total_tracked_fan_rpm / cpu_package_power_w` |

### 5. 时序窗口特征

当前第一版时序特征使用“同一 source file 内按采样顺序滚动”的轻量窗口，不需要神经网络也能利用负载变化趋势。

| 字段 | 类型 | 含义 |
|---|---|---|
| `source_sample_count` | int | 当前 source file 的样本总数 |
| `sample_progress_pct` | number | 当前样本在 source file 中的归一化进度 |
| `elapsed_seconds` | int/null | 相对首样本的累计秒数 |
| `delta_seconds` | int/null | 与上一采样点的秒差 |
| `cpu_package_delta_1` | number/null | CPU Package 相对上一点的变化 |
| `gpu_temp_delta_1` | number/null | GPU 温度相对上一点的变化 |
| `total_tracked_fan_rpm_delta_1` | number/null | 总跟踪转速相对上一点的变化 |
| `cpu_total_load_delta_1` | number/null | CPU 总负载相对上一点的变化 |
| `rolling_cpu_package_avg_3` | number/null | 最近 3 点 CPU Package 均值 |
| `rolling_cpu_package_max_3` | number/null | 最近 3 点 CPU Package 最大值 |
| `rolling_gpu_temp_avg_3` | number/null | 最近 3 点 GPU 温度均值 |
| `rolling_gpu_temp_max_3` | number/null | 最近 3 点 GPU 温度最大值 |
| `rolling_total_tracked_fan_rpm_avg_3` | number/null | 最近 3 点总转速均值 |
| `rolling_total_tracked_fan_rpm_max_3` | number/null | 最近 3 点总转速最大值 |
| `rolling_cpu_total_load_avg_3` | number/null | 最近 3 点 CPU 总负载均值 |
| `rolling_cpu_total_load_max_3` | number/null | 最近 3 点 CPU 总负载最大值 |

### 6. 标签字段

第一版标签是 **规则生成标签**，不是人工主观标签。

| 字段 | 类型 | 含义 |
|---|---|---|
| `safety_label` | string | `safe` / `warn` / `unsafe` |
| `thermal_score` | number | 热安全分数，`0-100` |
| `noise_efficiency_score` | number/null | 基于总转速在当前数据集内的相对安静程度 |
| `target_score` | number/null | 第一版训练目标分数 |

## 标签规则

### `safety_label`

- `unsafe`
  - `cpu_package_c >= 90`
  - 或 `gpu_temp_c >= 83`
  - 或 `min_distance_to_tjmax_c <= 10`
- `warn`
  - `cpu_package_c >= 85`
  - 或 `gpu_temp_c >= 78`
  - 或 `min_distance_to_tjmax_c <= 15`
- 其他情况记为 `safe`

### `target_score`

第一版目标不是追求理论最优，而是给后续迭代一个稳定可解释的 baseline：

```text
target_score = (0.65 * thermal_score + 0.35 * noise_efficiency_score) * safety_multiplier
```

其中：

- `safe` -> `1.00`
- `warn` -> `0.75`
- `unsafe` -> `0.40`

## 第一版训练脚本输出

训练脚本当前会输出：

- `baseline_model.json`
- `baseline_model_bundle.json`
- `baseline_model_report.md`

候选配置评分脚本当前会输出：

- `candidate_score_summary.json`
- `candidate_score_report.md`

当前训练流程会比较三类候选评分模型，目标都是预测 `target_score`：

- `ridge`：固定 alpha 的带 L2 正则线性回归 baseline
- `ridge_cv`：按 leave-one-source-out 风格验证挑选 alpha 的线性回归，当前默认模型
- `random_forest`：纯 Python 的轻量非线性对照模型，用来观察交互项收益

`baseline_model.json` 会写出当前首选模型；`baseline_model_bundle.json` 会保留全部模型及其验证结果，方便后续回看和比较。

这不是最终模型，只是：

- 验证 schema 是否足够支持训练
- 验证样本是否能稳定落到同一套特征空间
- 给后续更复杂模型一个可比较的起点

当前阶段交接与待做见：

- [`NEXT_SESSION_HANDOFF_2026-04-29.md`](./NEXT_SESSION_HANDOFF_2026-04-29.md)

## 使用方式

构建训练集：

```powershell
python .\scripts\modeling\build_training_dataset.py `
  --input-root .\docs\experiments\data `
  --config-root .\configs `
  --output-dir .\artifacts\modeling
```

训练并比较 baseline 模型：

```powershell
python .\scripts\modeling\train_baseline_model.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --output-dir .\artifacts\modeling
```

如需显式指定首选模型或 alpha 搜索范围，可追加：

```powershell
python .\scripts\modeling\train_baseline_model.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --output-dir .\artifacts\modeling `
  --preferred-model ridge_cv `
  --ridge-cv-alphas 0.1,0.3,1,3,10
```

给候选配置打分：

```powershell
python .\scripts\modeling\score_candidate_config.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --model .\artifacts\modeling\baseline_model.json `
  --candidate-config .\configs\Game_vNext_stage1_low-rpm.json `
  --baseline-config .\configs\Game.json `
  --output-dir .\artifacts\modeling
```

搜索受约束候选并生成验证清单：

```powershell
python .\scripts\modeling\search_candidate_configs.py `
  --dataset .\artifacts\modeling\training_rows.jsonl `
  --model .\artifacts\modeling\baseline_model.json `
  --seed-config .\configs\Game_vNext_stage1_low-rpm.json `
  --baseline-config .\configs\Game.json `
  --output-dir .\artifacts\modeling

python .\scripts\modeling\prepare_candidate_validation.py `
  --search-summary .\artifacts\modeling\candidate_search_summary.json `
  --output-dir .\artifacts\modeling `
  --top-n 3 `
  --validation-date 2026-04-30
```

## 当前边界

- 当前只包含轻量滚动窗口特征，不是完整序列模型。
- 第一版标签是规则生成，不是人工听感标签。
- 当前默认评分器是 `ridge_cv`，但仍然只用于“评分”和“建议”，不直接写回 live config。
- `random_forest` 目前只作离线对照，不能替代实机验证。

后续如果要进入更强的模型阶段，建议追加：

- 滚动窗口特征
- 场景持续时间特征
- 噪音主观评分标签
- 配置切换后的稳定时间标签
