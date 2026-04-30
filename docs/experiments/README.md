# 实验与采样目录

本目录现在同时承担两类内容：

- `*.md`：人工整理的实验记录、结论和决策
- `data/`：供后续建模复用的原始采样 JSON

也就是说，这里不再只是“写实验报告”，而是当前整条调优链路的数据入口。

## 当前目录结构

```text
experiments/
├── README.md
├── data/
│   └── 2026-04-29_stage1_idle\
├── 2026-04-29_stage1-low-rpm.md
├── 2026-04-30_candidate-validation-runbook.md
├── 2026-04-30_candidate-rank01-validation.md
├── 2026-04-29_stage1-test-matrix.md
└── ...
```

## 采样数据约定

原始采样建议使用 `scripts/current/monitor_simple.ps1` 生成，并保留统一字段结构。当前脚本已经整合：

- 运行期状态
- 实际生效配置
- CPU / GPU 温度
- CPU 负载、频率、功耗
- 主板温度
- 风扇转速

建议命名方式：

- 目录：`YYYY-MM-DD_<stage>_<theme>`
- 文件：`<scenario>.json`

例如：

- `docs/experiments/data/2026-04-29_stage1_idle/idle_batch1.json`
- `docs/experiments/data/2026-04-29_stage1_idle/mixed_cpu_gpu_proxy.json`

## 推荐实验记录结构

每次形成阶段性结论时，仍然建议补一份 `md` 记录，不要求逐采样点都单独写报告，但至少应说明：

```markdown
# 实验: <阶段名称>

## 目标

- 本轮想解决什么问题

## 配置变更

| 参数 | 原值 | 新值 | 说明 |
|---|---|---|---|
| Auto.MinFanSpeed | 30 | 25 | 降低 idle 噪音 |

## 采样范围

- 使用的配置文件
- 采样目录
- 典型场景
- 关键观察指标

## 结果摘要

- 温度变化
- 风扇转速变化
- 是否出现 `warn` / `unsafe`
- 主观噪音变化

## 决策

- `accepted-baseline`
- `rejected`
- `needs-more-data`

## 下一步

- 下一轮重点观察什么
```

## 与建模流程的关系

当前 `docs/experiments/data/` 是以下脚本的输入：

- `scripts/modeling/build_training_dataset.py`
- `scripts/modeling/train_baseline_model.py`
- `scripts/modeling/score_candidate_config.py`
- `scripts/modeling/search_candidate_configs.py`
- `scripts/modeling/prepare_candidate_validation.py`

如果已经有搜索结果，建议再生成一份实机验证包：

```powershell
python .\scripts\modeling\prepare_candidate_validation.py `
  --search-summary .\artifacts\modeling\candidate_search_summary.json `
  --output-dir .\artifacts\modeling `
  --top-n 3 `
  --validation-date 2026-04-30
```

它会输出：

- `artifacts/modeling/candidate_validation_manifest.json`
- `artifacts/modeling/candidate_validation_checklist.md`

其中 manifest 负责给脚本和后续会话读，checklist 负责给人工按顺序执行验证。

训练集字段定义见：

- [`../modeling/TRAINING_DATA_SCHEMA.md`](../modeling/TRAINING_DATA_SCHEMA.md)

新会话交接和待做见：

- [`../modeling/NEXT_SESSION_HANDOFF_2026-04-29.md`](../modeling/NEXT_SESSION_HANDOFF_2026-04-29.md)

当前 candidate 实机验证执行稿见：

- [`2026-04-30_candidate-validation-runbook.md`](./2026-04-30_candidate-validation-runbook.md)

rank 1 实测结果记录页见：

- [`2026-04-30_candidate-rank01-validation.md`](./2026-04-30_candidate-rank01-validation.md)
