# README 重构设计说明

## 目标

将仓库根目录 `README.md` 从“总手册式首页”重构为更符合高水平开源仓库的项目入口页，同时保留并强化项目当前最重要的演进方向：通过模型自动调整 `config` 中各项风扇曲线参数。

本次设计目标不是单纯美化文档，而是重新划分 README 与细节文档之间的职责边界，使首页优先服务于以下场景：

- 第一次访问仓库的读者快速理解项目价值
- 仓库维护者快速定位核心入口
- 访客清楚看到项目当前状态、正在进行的工作与下一步方向
- 详细实现说明、运维手册、配置分析通过链接进行分流，而不是继续堆叠在 README 首页

## 设计原则

### 1. 首页先讲价值，再讲实现

新的 README 应优先回答：

- 这是什么项目
- 它解决了什么问题
- 当前已经具备哪些稳定能力
- 项目下一步要往哪里演进

不再把大量执行流程、任务计划清单、脚本逐步说明直接堆放在首页。

### 2. README 是项目入口，不是全文手册

README 保留高层信息与常用入口，详细内容下沉到已有文档：

- `docs/PROJECT_STRUCTURE.md`
- `scripts/README.md`
- `docs/CONFIG_ANALYSIS.md`
- `docs/CONFIG_ITERATION_GUIDE.md`
- `docs/README_CONSOLIDATED.md`
- `archive/README.md`

### 3. 路线图必须显性化

README 需要明确区分：

- 当前状态
- 正在进行
- 下一步

其中“通过模型自动调整 config 中各项曲线参数”应作为仓库当前最值得强调的方向，出现在首页高可见度位置，而不是只放在末尾或隐含在其他文档中。

### 4. 展示优先，但不牺牲维护入口

虽然新 README 以展示型开源首页为主，但仍保留维护者真正高频使用的入口信息，例如：

- 测试入口
- 当前源码权威目录
- runtime mirror 位置
- 关键文档导航

因此最终风格应是“标准开源首页型”，但在实用性上保留最小必要运维信息。

### 5. 中文主文 + 英文切换入口

- `README.md` 作为中文主入口
- 新增 `README.en.md` 作为英文入口
- 两个文件顶部互相链接
- 当前详细 docs 仍以中文为主
- 英文 README 可以链接到中文 docs，并明确标注文档语言状态

## 信息分层方案

### README 首页保留内容

新的 `README.md` 应保留以下内容：

1. 项目名称、badge、英文切换入口
2. 一句话项目定位
3. 项目概述
4. 为什么存在这个仓库
5. 当前能力摘要
6. 架构概览
7. 快速开始
8. 仓库结构（简版）
9. 当前状态
10. 正在进行
11. 下一步
12. 文档导航
13. License

### 从 README 拆出的内容

以下内容不再在首页长篇展开，而通过文档链接访问：

- 任务计划完整清单
- 每个脚本的详细执行流程
- 故障排查长文
- 曲线参数逐项分析
- 历史演进时间线细节
- 文档治理说明与索引细节

## README 章节结构

建议新的中文 README 采用如下结构：

```md
# FanControl 自动化配置切换系统

[English](./README.en.md)

> 一句话项目描述

## 项目概述
## 为什么有这个仓库
## 当前能力
## 架构概览
## 快速开始
## 仓库结构
## 当前状态
## 正在进行
## 下一步
## 文档导航
## License
```

### 各章节职责

#### 项目概述

用简洁文本说明：这是一个用于 Windows + FanControl 的自动化配置切换仓库，支持定时切换、登录触发、手动覆盖、运行期验证，并持续向更智能的配置优化方向演进。

#### 为什么有这个仓库

解释项目存在价值：FanControl 本身不负责“按时段自动切换 + 手动覆盖 + 自动恢复 + 运行验证”的完整调度层，本仓库补齐的是这套自动化与可维护运行层。

#### 当前能力

使用精炼条目列出当前已经稳定具备的能力，例如：

- time-based profile switching
- logon-triggered startup and application
- manual override without permanently breaking automation
- forced recovery points
- runtime verification and status output
- repo/runtime separation for safer maintenance

#### 架构概览

保留高层架构信息：

- repo source of truth：`scripts/current/`
- runtime mirror：`C:\FanControl_Auto\`
- tracked config snapshots：`configs/`
- 自动调度与手动切换的关系

不展开脚本逐步执行细节。

#### 快速开始

只保留最小必要入口，例如：

- 测试命令
- 核心源码位置
- runtime mirror 位置
- 更完整部署/脚本说明去哪看

#### 仓库结构

给出简版目录结构，只覆盖：

- `scripts/current/`
- `configs/`
- `tests/`
- `docs/`
- `archive/`

详细结构继续交给 `docs/PROJECT_STRUCTURE.md`。

#### 当前状态

明确当前已经成立的稳定事实，例如：

- 自动切换链路已可生产运行
- 手动 override 与强制恢复机制已经形成闭环
- 验证与状态输出机制已建立
- source/runtime 边界已明确

#### 正在进行

这是 README 中最重要的路线图区块之一，应显著突出：

- 通过模型自动调整 `config` 中各项曲线参数
- 分析当前 `Game.json` 等配置在真实使用下的行为
- 建立更安全、可观察、可回退的参数调优流程

#### 下一步

用于写更具体的后续方向，例如：

- 定义更明确的噪音/散热调优指标
- 比较候选曲线方案与实际采样结果
- 从人工分析走向模型辅助参数建议
- 逐步形成半自动配置调优工作流

#### 文档导航

以链接列表或表格提供文档分流入口，推荐链接：

- `docs/PROJECT_STRUCTURE.md`
- `scripts/README.md`
- `docs/CONFIG_ANALYSIS.md`
- `docs/CONFIG_ITERATION_GUIDE.md`
- `docs/README_CONSOLIDATED.md`
- `archive/README.md`

## 顶部布局设计

README 顶部推荐结构：

1. 项目标题
2. 英文切换入口
3. badge
4. 一句话描述

这一布局的目标是让读者在一屏内理解：

- 仓库名称
- 仓库用途
- 当前质量/状态信号
- 可切换英文入口

## 文风策略

README 中文版应采用中文正文，但整体表达风格要更接近成熟开源仓库：

- 先讲结果，再讲实现
- 先讲能力，再讲细节
- 少写阶段性整理痕迹
- 少写流水账式过程说明
- 多用稳定、客观、结构化表达

避免让首页看起来像内部备忘录或长期追加说明的集合。

## 英文 README 策略

新增 `README.en.md`，结构与中文版保持一致，但允许适度精简。英文版至少应覆盖：

- What this project is
- Why it exists
- Current capabilities
- Architecture at a glance
- Current status
- In progress
- Next
- Documentation links

对当前仅提供中文的详细文档，可在英文版中明确标注 `(Chinese)`，避免误导读者。

## 实施建议

实施阶段应至少包含以下改动：

1. 重写 `README.md`
2. 新增 `README.en.md`
3. 将现有 README 中过深的执行细节下沉为链接引用
4. 保留并强化 “通过模型自动调整 config 中各项曲线参数” 的显性路线图区块
5. 保证 README 与现有 docs 链接一致、路径正确、导航清晰

## 成功标准

完成后，新的 README 应达到以下效果：

- 第一次访问仓库的读者能在 30 秒内理解项目用途与当前方向
- 首页不再承担“完整运维手册”的职责
- 详细内容通过链接访问，不造成信息丢失
- 项目当前正在做的“模型辅助调参”方向被明显看见
- 中英文入口清晰，公开展示感明显提升
