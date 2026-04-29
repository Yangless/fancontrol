# 2026-04-29 Stage 1 Low-RPM 实验

## 配置文件

- 仓库快照: `configs/Game_vNext_stage1_low-rpm.json`
- Live 副本: `D:\Program Files (x86)\FanControl\Configurations\Game_vNext_stage1_low-rpm.json`
- 基础配置: `configs/Game.json`

## 本轮目标

- 保留现有三层风扇结构，不改控制对象分工
- 优先降低轻载和中低游戏负载下的总风扇转速
- 让 CPU 风扇承担第一响应，机箱风扇延后介入
- 为下一轮基于温度/频率的回调保留空间

## 曲线调整

| Curve | Temp Source | Before | After | 意图 |
|---|---|---:|---:|---|
| Auto | CPU Package | 35 / 30 / 80 / 70 | 40 / 25 / 85 / 78 | CPU 风扇更晚起步，但保留更高上限 |
| Auto 1 | CPU Package | 40 / 20 / 80 / 70 | 48 / 15 / 72 / 78 | 第二层机箱风扇明显延后、下限更低 |
| Auto 2 | Core Average | 50 / 0 / 80 / 80 | 58 / 0 / 65 / 86 | 第三层机箱风扇更晚介入，并降低高温段总参与度 |

说明:

- 表中四个数值依次为 `IdleTemperature / MinFanSpeed / MaxFanSpeed / LoadTemperature`
- `System Fan #3/#4` 仍保留原有 `Start/Stop` 逻辑，不改启停百分比

## 估算转速

| Fan | Curve | Min RPM | Max RPM |
|---|---|---:|---:|
| CPU Fan | Auto | ~454 | ~1332 |
| System Fan #2 | Auto 1 | ~390 | ~1363 |
| System Fan #3 | Auto 2 | 0 | ~1109 |
| System Fan #4 | Auto 2 | 0 | ~1147 |

## 下一轮观察重点

- `CPU Package` 是否长期高于 `85°C`
- `Core Average` 是否长期高于 `80°C`
- `MinDistanceToTjMax` 是否逼近 `15°C`
- `EffectiveClockMHz` 是否出现持续性回落
- `TotalFanRpm` 是否明显低于当前 `Game.json`

## 调整判据

- 如果 `CPU Package` 持续高于 `85°C`，先把 `Auto.IdleTemperature` 降回 `38` 或把 `Auto.LoadTemperature` 降到 `75`
- 如果频率稳定、温度安全，但总转速仍偏高，优先继续降低 `Auto 1.MinFanSpeed` 或继续抬高 `Auto 2.IdleTemperature`
- 如果 `System Fan #3/#4` 介入过晚导致机箱热积累，优先把 `Auto 2.IdleTemperature` 从 `58` 回调到 `55`

## 2026-04-29 Idle A/B 实测

- 数据目录: `docs/experiments/data/2026-04-29_stage1_idle/`
- 实验配置样本:
  - `idle_batch1.json`
  - `idle_batch2.json`
- 对照配置样本:
  - `idle_game_baseline.json`
- 采样口径:
  - 实验配置采样 `12` 个点，取后 `6` 个点作为稳定 idle
  - `Game.json` 对照采样 `6` 个点
  - 间隔均为 `5s`

| 指标 | Stage1 stable | Game baseline | 变化 |
|---|---:|---:|---:|
| CPU Package | `53.3°C` | `48.7°C` | `+4.6°C` |
| Core Average | `48.4°C` | `45.4°C` | `+3.0°C` |
| Min Distance to TjMax | `46.5°C` | `52.0°C` | `-5.5°C` |
| CPU Package Power | `46.5W` | `46.5W` | `0W` |
| CPU Fan RPM | `782.8` | `1012.0` | `-229.2` |
| System Fan #2 RPM | `472.5` | `1059.7` | `-587.2` |
| Total Case Fan RPM | `472.5` | `1173.8` | `-701.3` |
| Total Tracked Fan RPM | `1255.3` | `2185.8` | `-930.5` |

补充观察:

- `P-Core` / `E-Core` 平均时钟保持不变，未看到掉频迹象
- `System` / `VRM MOS` / `PCH` 没有变差，反而略低
- `System Fan #3/#4` 在稳定 idle 阶段保持 `0 RPM`
- `Game.json` 对照样本中出现过 `System Fan #3/#4` 短暂参与

当前结论:

- Stage 1 在 idle/轻桌面口径下已经明显达成“更低总转速”的目标
- 温度代价存在，但仍远离 `100°C TjMax`，当前看不到对 CPU 不友好的迹象
- 这组结果足够支持继续做下一轮负载场景测试，不建议仅凭 idle 数据继续激进下压

## 2026-04-29 负载代理场景

### Light graphics proxy

- 数据文件: `light_graphics_proxy_winsat_dwm.json`
- 方法: 循环运行 `winsat dwm`
- 判定: 这是“轻图形/轻游戏代理”，不是纯 GPU 压力

| 指标 | 数值 |
|---|---:|
| CPU Package | `avg 69.7°C / max 76°C` |
| Core Average | `avg 58.8°C / max 61.9°C` |
| Min Distance to TjMax | `min 19°C` |
| CPU Total Load | `avg 24.8% / max 32.9%` |
| CPU Package Power | `avg 83.0W / max 104.1W` |
| GPU Temp | `avg 52.3°C / max 56°C` |
| GPU 3D Util | `avg 69.7% / max 88.4%` |
| Total Tracked Fan RPM | `avg 2571.6 / max 2835` |

观察:

- `P-Core / E-Core` 平均时钟保持稳定，没有掉频
- `System Fan #3/#4` 基本未参与
- 对 Stage 1 来说，这一档主要还是 `CPU Fan + System Fan #2` 在兜底

### CPU-biased proxy

- 数据文件: `cpu_heavy_powershell.json`
- 方法: `12` 个 PowerShell 算术环
- 判定: 更接近“中度 CPU 偏重”，不是绝对满载烤机

| 指标 | 数值 |
|---|---:|
| CPU Package | `avg 63.0°C / max 81°C` |
| Core Average | `avg 55.3°C / max 66.2°C` |
| Min Distance to TjMax | `min 22°C` |
| CPU Total Load | `avg 21.8% / max 38.4%` |
| CPU Package Power | `avg 72.0W / max 86.5W` |
| GPU Temp | `avg 41.2°C / max 42°C` |
| GPU 3D Util | `avg 14.6% / max 15.7%` |
| Total Tracked Fan RPM | `avg 2501.6 / max 2683` |

观察:

- CPU 偏重时温度和功耗明显上升，但仍未触碰当前安全线
- GPU 侧基本平稳，说明这组数据可以主要用于判断 `Auto` 是否偏软

### Mixed CPU + GPU proxy

- 数据文件: `mixed_cpu_gpu_proxy.json`
- 方法: `10` 个 PowerShell 算术环 + 循环 `winsat dwm`
- 保护线: `CPU Package >= 88°C` 或 `Distance to TjMax <= 12°C` 立刻停
- 结果: 未触发中止

| 指标 | 数值 |
|---|---:|
| CPU Package | `avg 70.9°C / max 79°C` |
| Core Average | `avg 61.2°C / max 65.1°C` |
| Min Distance to TjMax | `min 24°C` |
| CPU Total Load | `avg 31.8% / max 39.7%` |
| CPU Package Power | `avg 95.3W / max 118.1W` |
| GPU Temp | `avg 48.4°C / max 53°C` |
| GPU 3D Util | `avg 64.5% / max 87.6%` |
| Total Tracked Fan RPM | `avg 2633.9 / max 2828` |

观察:

- 即便叠加 CPU + 图形代理，当前 Stage 1 仍未出现掉频
- `System Fan #3` 仍未参与，`System Fan #4` 只出现过一次短暂介入
- 这说明 Stage 1 的三层分级目前偏保守地依赖 `CPU Fan + System Fan #2`

阶段性结论:

- Stage 1 的核心方向是对的: 低负载显著降总转速，高于 idle 的场景也没有立即撞上热墙
- 当前最值得继续验证的，不是再压低 idle，而是确认真实 GPU 偏重游戏时 `Auto 2` 是否介入过晚

## 2026-04-29 前台浏览器 3D 场景补充

### WebGL Aquarium

- 已验证:
  - 页面前台渲染正常
  - 可切换 `500 / 1000 / 5000 / 10000 / 30000` fish
- 结果:
  - 这个场景更偏 `CPU + JS + 一定比例的 WebGL`
  - 在 `30000 fish` 下，`CPU Package` 峰值能到 `83°C`
  - 但 `GPU Temp` 仍基本停留在 `38°C`
  - `System Fan #3/#4` 仍几乎不参与
- 结论:
  - 它不适合被当作“GPU 偏重游戏”代理
  - 更适合作为“前台 3D + CPU 参与较多”的混合浏览器负载

### Volume Shader BM

- 数据文件: `front_volume_shader_default.json`
- 页面状态:
  - 真实前台 WebGL benchmark 已确认在跑
  - 实时面板截图显示 `FPS` 大约在 `112 ~ 144`
- 正式样本汇总:

| 指标 | 数值 |
|---|---:|
| CPU Package | `avg 67.3°C / max 71°C` |
| Core Average | `avg 58.1°C / max 60.9°C` |
| Min Distance to TjMax | `min 24°C` |
| CPU Total Load | `avg 28.5% / max 34.9%` |
| CPU Package Power | `avg 84.8W / max 102.7W` |
| GPU Temp | `avg 37°C / max 37°C` |
| GPU 3D Util | `avg 17.3% / max 19.2%` |
| Total Tracked Fan RPM | `avg 2286.6 / max 2424` |

观察:

- 这组是真实前台浏览器 3D 场景，不是脚本代理
- 但它对当前这台机器的 GPU 压力依然不够大，`GPU Temp` 几乎不抬升
- `System Fan #3/#4` 仍未介入
- `CPU Fan + System Fan #2` 继续承担主要响应

补充说明:

- 初次测试时 `WebGL Aquarium` 旧 tab 未关闭，污染了浏览器场景数据
- 后续 `Volume Shader BM` 样本已在关闭 Aquarium 干扰后重新采集

现阶段判断:

- Stage 1 在真实前台浏览器 3D 场景下仍然安全
- 但现有浏览器场景还不足以对 `Auto 2` 的介入时机给出强结论
- 如果要正式判断 `System Fan #3/#4` 是否介入过晚，仍然需要真实 GPU 偏重游戏或原生 3D benchmark

## 2026-04-29 真实 GPU 烤鸡回调

- 数据文件: `user_stress_session_1.json`
- 关键信号:
  - `GPU Temp` 从 `37°C` 升到 `74°C`
  - `CPU Package` 峰值仅 `75°C`
  - `Core Average` 峰值仅 `57.9°C`
  - `System Fan #3/#4` 全程基本未参与

判断:

- 这轮已经足够说明当前 `Auto 2` 的问题不在 CPU 温度阈值高低，而在温度源选错
- 真实 GPU 偏重场景下，第三层机箱风扇不应该继续只看 `Core Average`

因此做出的小回调:

| Curve | Temp Source | Before | After | 意图 |
|---|---|---:|---:|---|
| Auto 2 | Core Average | `58 / 0 / 65 / 86` | `62 / 0 / 55 / 74` | 改为跟随 `GPU`，只在 GPU 明显升温后让第三层轻量介入 |

补充说明:

- 这次没有动 `Auto` 和 `Auto 1`
- 这次也没有改 `System Fan #3/#4` 的 `Start/Stop` 逻辑
- 目标不是让第三层更吵，而是让它终于在正确场景下开始工作

为什么这时不补单独 CPU 烤鸡:

- 现有 CPU 数据已经足够判断当前不是 `Auto` 主曲线失守
- 如果后面要收敛 `CPU Fan` 曲线本身，再补一次纯 CPU 满载更有意义
- 但对这一步 `Auto 2` 的 GPU-aware 回调来说，CPU 数据已经够用

## 2026-04-29 GPU-aware 回调复测

- 数据文件: `user_stress_session_2_gpuaware.json`
- 场景: 与上一轮保持同一套 GPU 烤鸡模式
- 目标: 验证 `Auto 2` 改为跟随 `GPU` 之后，第三层风扇是否终于开始工作

| 指标 | 数值 |
|---|---:|
| CPU Package | `avg 75.7°C / max 86°C` |
| Core Average | `avg 64.4°C / max 67.8°C` |
| Min Distance to TjMax | `min 16°C` |
| CPU Package Power | `avg 74.8W / max 99.6W` |
| GPU Temp | `avg 77.5°C / max 78°C` |
| GPU 3D Util | `avg 51.6% / max 54.2%` |
| CPU Fan RPM | `avg 1331 / max 1410` |
| System Fan #2 RPM | `avg 1393.2 / max 1447` |
| System Fan #3 RPM | `avg 49.4 / max 400` |
| System Fan #4 RPM | `avg 76.4 / max 438` |
| Total Tracked Fan RPM | `avg 2850 / max 3686` |

关键观察:

- `System Fan #3/#4` 已经在真实 GPU 烤鸡中开始介入
- 介入方式符合预期:
  - 不是全程高转
  - 而是在 GPU 高温段短时补风
- 本轮没有触发保护线
- `CPU Package` 最高 `86°C`，仍在当前接受范围内
- `MinDistanceToTjMax` 最低 `16°C`，贴近但没有越过当前红线

当前结论:

- 这次 GPU-aware 回调是有效的
- 当前版本可以作为“现阶段接受版”
- 后续如果再微调，优先顺序应为:
  - 先看 `Auto 2` 是否需要更平滑
  - 再看 `Auto` / `Auto 1` 是否值得继续压噪
