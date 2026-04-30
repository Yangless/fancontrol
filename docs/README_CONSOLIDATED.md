# FanControl 文档导航与历史索引

> 更新日期：2026-04-29
>
> 本文档只做导航和历史索引。当前真实目录结构只以 [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) 为准。

## 1. 当前应优先阅读的文档

1. [README.md](../README.md)
2. [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)
3. [scripts/README.md](../scripts/README.md)
4. [SYNC_MEMO.md](../SYNC_MEMO.md)

如果需要理解配置文件和后续调优，再看：

- [CONFIG_ANALYSIS.md](./CONFIG_ANALYSIS.md)
- [CONFIG_ITERATION_GUIDE.md](./CONFIG_ITERATION_GUIDE.md)
- [experiments/README.md](./experiments/README.md)
- [experiments/2026-04-30_candidate-validation-runbook.md](./experiments/2026-04-30_candidate-validation-runbook.md)
- [experiments/2026-04-30_candidate-rank01-validation.md](./experiments/2026-04-30_candidate-rank01-validation.md)
- [modeling/TRAINING_DATA_SCHEMA.md](./modeling/TRAINING_DATA_SCHEMA.md)
- [modeling/NEXT_SESSION_HANDOFF_2026-04-29.md](./modeling/NEXT_SESSION_HANDOFF_2026-04-29.md)

如果需要回看历史问题与修复过程，再看：

- [archive/README.md](../archive/README.md)

## 2. 当前文档分工

| 文档 | 作用 | 是否定义当前结构 |
|------|------|----------------|
| `README.md` | 项目总览、使用说明、运维入口 | 否 |
| `docs/PROJECT_STRUCTURE.md` | 当前仓库结构权威说明 | 是 |
| `scripts/README.md` | 脚本目录职责与同步规则 | 否 |
| `SYNC_MEMO.md` | repo source / runtime mirror 同步备忘录 | 否 |
| `docs/experiments/README.md` | 采样数据与实验记录入口 | 否 |
| `docs/experiments/2026-04-30_candidate-validation-runbook.md` | top candidates 实机验证执行稿 | 否 |
| `docs/experiments/2026-04-30_candidate-rank01-validation.md` | rank 1 candidate 实测结果记录页 | 否 |
| `docs/modeling/TRAINING_DATA_SCHEMA.md` | 建模训练集字段约定 | 否 |
| `docs/modeling/NEXT_SESSION_HANDOFF_2026-04-29.md` | 建模阶段交接与待做清单 | 否 |
| `docs/README_CONSOLIDATED.md` | 文档导航、历史索引、时间线 | 否 |

## 3. 历史文档索引

| 文档 | 日期 | 关键内容 | 文件路径 |
|------|------|---------|---------|
| 测试报告 v1.0 | 2026-03-31 | 初始版本测试结果 | [archive/2026-03-31_测试报告_v1.0.md](../archive/2026-03-31_测试报告_v1.0.md) |
| 开发部署文档 v1.0 | 2026-04-02 | 首次部署指南、任务计划配置 | [archive/2026-04-02_开发部署文档_v1.0.md](../archive/2026-04-02_开发部署文档_v1.0.md) |
| 修复报告 v2.0 | 2026-04-11 | 静默失败问题、日志机制引入 | [archive/2026-04-11_修复报告_v2.0.md](../archive/2026-04-11_修复报告_v2.0.md) |
| 修复完成报告 v3.0 | 2026-04-11 | 配置路径统一、验证机制完善 | [archive/2026-04-11_修复完成报告_v3.0.md](../archive/2026-04-11_修复完成报告_v3.0.md) |
| 监控验证机制说明 v3.0 | 2026-04-11 | 验证流程、CACHE 文件检查 | [archive/2026-04-11_监控验证机制说明_v3.0.md](../archive/2026-04-11_监控验证机制说明_v3.0.md) |
| 开机状态分析报告 | 2026-04-12 | BootTrigger 问题诊断 | [archive/2026-04-12_开机状态分析报告.md](../archive/2026-04-12_开机状态分析报告.md) |
| 开机状态和监控总结 | 2026-04-12 | 根因分析与修复总结 | [archive/2026-04-12_开机状态和监控总结.md](../archive/2026-04-12_开机状态和监控总结.md) |
| 持续监控系统使用说明 v3.1 | 2026-04-12 | `monitor_simple.ps1` 使用方式 | [archive/2026-04-12_持续监控系统使用说明_v3.1.md](../archive/2026-04-12_持续监控系统使用说明_v3.1.md) |

## 4. 版本时间线

### v1.0 (2026-04-02)

- 完成基础时段切换与任务计划注册。
- 仍缺少日志、验证和稳定的启动流程。

### v2.0 (2026-04-11)

- 引入日志、`override.flag` 和手动切换入口。
- 开始把“个人脚本”推进到可维护状态。

### v3.0 (2026-04-11)

- 引入配置切换验证、状态文件和托盘通知。
- 解决了路径统一和基本验证闭环。

### v3.1 (2026-04-12)

- 增加 `check_status.ps1` 和 `monitor_simple.ps1` 两个观察工具。

### v3.2 (2026-04-12)

- 把开机启动从 `BootTrigger` 调整为 `LogonTrigger`，并增加延迟。

### v3.3 (2026-04-29)

- 接受一版低转速 GPU-aware 基线配置。
- `monitor_simple.ps1` 合并硬件指标采样输出。
- 引入第一版建模流水线：训练集构建、baseline 训练、候选配置评分、受约束候选搜索；当前默认评分模型为 `ridge_cv`，并保留 `random_forest` 对照。

## 5. 当前背景摘要

这个仓库当前处于“从个人自动化脚本向正式代码库治理过渡”的阶段，主要背景如下：

- 核心自动切换功能已经可用。
- 测试已经覆盖核心切换路径。
- 文档、结构治理、状态统一和 runtime 边界已经基本明确。
- 当前新重点是把真实负载采样沉淀成可复用建模数据，并把搜索器筛出的候选配置带回真实负载验证。

## 6. 使用本索引时的规则

- 想知道“仓库现在长什么样”，看 [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)。
- 想知道“现在怎么运行、怎么部署、怎么维护”，看 [README.md](../README.md)。
- 想知道“实验数据怎么组织、建模怎么接”，看 [experiments/README.md](./experiments/README.md) 和 [modeling/TRAINING_DATA_SCHEMA.md](./modeling/TRAINING_DATA_SCHEMA.md)。
- 想知道“下个会话应该先做什么”，看 [modeling/NEXT_SESSION_HANDOFF_2026-04-29.md](./modeling/NEXT_SESSION_HANDOFF_2026-04-29.md)。
- 想知道“为什么会演进成现在这样”，看 `archive/` 中的历史文档。
- 如果在仓库外看到旧同步报告或整理稿，不要把它们当作当前事实来源。
