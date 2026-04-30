#!/usr/bin/env python
import argparse
import json
import os
from collections import OrderedDict
from datetime import datetime


REPORT_VERSION = "fancontrol.candidate-validation-pack.v1"

DEFAULT_SCENARIOS = [
    OrderedDict([
        ("name", "GPU-biased-real-game"),
        ("duration_minutes", 15),
        ("sample_interval_seconds", 5),
        ("goal", "确认 Auto 2 在真实 GPU 升温下是否介入及时且不过吵"),
        ("watch_metrics", [
            "GpuTemp",
            "Gpu3DUtil",
            "SystemTemp",
            "SystemFan3Rpm",
            "SystemFan4Rpm",
            "TotalTrackedFanRpm",
        ]),
        ("stop_conditions", [
            "GpuTemp >= 83C",
            "CpuPackage >= 88C",
            "MinDistanceToTjMax <= 12C",
        ]),
    ]),
    OrderedDict([
        ("name", "CPU-plus-GPU-transition"),
        ("duration_minutes", 10),
        ("sample_interval_seconds", 2),
        ("goal", "观察切场景、加载、回桌面等过渡段时风扇响应是否平滑"),
        ("watch_metrics", [
            "CpuPackage",
            "CoreAverage",
            "MinDistanceToTjMax",
            "GpuTemp",
            "TotalTrackedFanRpm",
            "SystemFan3Rpm",
            "SystemFan4Rpm",
        ]),
        ("stop_conditions", [
            "CpuPackage >= 88C",
            "MinDistanceToTjMax <= 12C",
        ]),
    ]),
    OrderedDict([
        ("name", "Quiet-recovery-idle"),
        ("duration_minutes", 10),
        ("sample_interval_seconds", 5),
        ("goal", "确认高负载结束回到桌面后，温度恢复和总转速回落是否稳定"),
        ("watch_metrics", [
            "CpuPackage",
            "GpuTemp",
            "CpuFanRpm",
            "SystemFan2Rpm",
            "SystemFan3Rpm",
            "SystemFan4Rpm",
            "TotalTrackedFanRpm",
        ]),
        ("stop_conditions", []),
    ]),
]


def parse_args():
    parser = argparse.ArgumentParser(description="Prepare a real-world validation pack for top-ranked candidate configs.")
    parser.add_argument("--search-summary", default=os.path.join("artifacts", "modeling", "candidate_search_summary.json"))
    parser.add_argument("--output-dir", default=os.path.join("artifacts", "modeling"))
    parser.add_argument("--top-n", type=int, default=3)
    parser.add_argument("--validation-date", default=datetime.utcnow().strftime("%Y-%m-%d"))
    return parser.parse_args()


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def write_text(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def build_validation_id(validation_date):
    return "{0}_candidate-validation".format(validation_date)


def build_sample_dir_name(validation_date, candidate_rank, scenario_name):
    safe_scenario = scenario_name.replace(" ", "-")
    return "{0}_candidate-rank{1:02d}_{2}".format(validation_date, candidate_rank, safe_scenario)


def build_validation_manifest(summary, search_summary_path, top_n, validation_date):
    selected = summary.get("top_candidates", [])[:max(top_n, 0)]
    validation_id = build_validation_id(validation_date)

    manifest = OrderedDict()
    manifest["report_version"] = REPORT_VERSION
    manifest["created_at"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest["validation_id"] = validation_id
    manifest["validation_date"] = validation_date
    manifest["seed_config"] = summary.get("seed_config")
    manifest["baseline_config"] = summary.get("baseline_config")
    manifest["source_search_summary"] = search_summary_path.replace("\\", "/")
    manifest["candidate_count"] = len(selected)
    manifest["scenarios"] = DEFAULT_SCENARIOS

    candidates = []
    for candidate in selected:
        rank = int(candidate["rank"])
        record = OrderedDict()
        record["rank"] = rank
        record["file_name"] = candidate["file_name"]
        record["file_path"] = candidate["file_path"]
        record["avg_predicted_score"] = candidate["avg_predicted_score"]
        record["delta_vs_seed"] = candidate["delta_vs_seed"]
        record["delta_vs_baseline"] = candidate["delta_vs_baseline"]
        record["parameter_values"] = candidate["parameter_values"]
        record["sample_directories"] = [
            OrderedDict([
                ("scenario", scenario["name"]),
                ("path", os.path.join("docs", "experiments", "data", build_sample_dir_name(validation_date, rank, scenario["name"])).replace("\\", "/")),
            ])
            for scenario in DEFAULT_SCENARIOS
        ]
        candidates.append(record)

    manifest["candidates"] = candidates
    return manifest


def build_markdown(manifest):
    lines = []
    lines.append("# Candidate Validation Pack")
    lines.append("")
    lines.append("- Validation ID: `{0}`".format(manifest["validation_id"]))
    lines.append("- Validation date: `{0}`".format(manifest["validation_date"]))
    lines.append("- Seed config: `{0}`".format(manifest["seed_config"]))
    lines.append("- Baseline config: `{0}`".format(manifest["baseline_config"]))
    lines.append("- Candidate count: `{0}`".format(manifest["candidate_count"]))
    lines.append("")
    lines.append("## Candidate Order")
    lines.append("")
    lines.append("| Rank | File | Predicted score | Delta vs seed | Delta vs baseline |")
    lines.append("|---|---|---:|---:|---:|")
    for candidate in manifest["candidates"]:
        lines.append("| {0} | {1} | {2} | {3} | {4} |".format(
            candidate["rank"],
            candidate["file_name"],
            candidate["avg_predicted_score"],
            candidate["delta_vs_seed"],
            candidate["delta_vs_baseline"],
        ))

    lines.append("")
    lines.append("## Run Order")
    lines.append("")
    lines.append("1. 先跑 rank 1。")
    lines.append("2. 如果 rank 1 已明显更差或触发停止条件，立即停止，不要继续把更低排名候选写进 live 配置。")
    lines.append("3. 只有 rank 1 和 baseline 差异不清楚时，再跑 rank 2 / rank 3。")
    lines.append("")
    lines.append("## Common Checklist")
    lines.append("")
    lines.append("- [ ] 保留 `configs/Game.json` 作为对照，不直接覆盖。")
    lines.append("- [ ] 将待测 candidate JSON 复制到 FanControl live config 目录。")
    lines.append("- [ ] 手动切到该 candidate，并确认 `EffectiveConfig` 与目标文件名一致。")
    lines.append("- [ ] 每个场景采样完成后，把 JSON 放到 manifest 指定的目录。")
    lines.append("- [ ] 每轮记录主观噪音备注，尤其是 `Auto 2` 介入的突兀程度。")
    lines.append("- [ ] 若触发任一停止条件，立即结束该候选的后续场景。")

    lines.append("")
    lines.append("## Suggested Commands")
    lines.append("")
    lines.append("```powershell")
    lines.append("# 1. 复制候选配置到 FanControl live 目录")
    lines.append("Copy-Item .\\artifacts\\modeling\\candidates\\<candidate_file>.json \"D:\\Program Files (x86)\\FanControl\\Configurations\\<candidate_file>.json\" -Force")
    lines.append("")
    lines.append("# 2. 让 override 直接指向这个 json 文件名")
    lines.append("Set-Content -Path \"C:\\FanControl_Auto\\state\\override.flag\" -Value \"<candidate_file>.json\"")
    lines.append("")
    lines.append("# 3. 开始采样，按场景分别指定输出目录")
    lines.append("pwsh -NoProfile -File .\\scripts\\current\\monitor_simple.ps1 -Mode Sample -IntervalSeconds 5 -MaxSamples 180 -OutputDir .\\docs\\experiments\\data\\<sample_dir>")
    lines.append("```")

    lines.append("")
    lines.append("## Scenarios")
    lines.append("")
    for scenario in manifest["scenarios"]:
        lines.append("### {0}".format(scenario["name"]))
        lines.append("")
        lines.append("- Duration: `{0} min`".format(scenario["duration_minutes"]))
        lines.append("- Sample interval: `{0} s`".format(scenario["sample_interval_seconds"]))
        lines.append("- Goal: {0}".format(scenario["goal"]))
        lines.append("- Watch metrics: `{0}`".format("`, `".join(scenario["watch_metrics"])))
        if scenario["stop_conditions"]:
            lines.append("- Stop conditions: `{0}`".format("`, `".join(scenario["stop_conditions"])))
        lines.append("")

    lines.append("## Candidate Notes")
    lines.append("")
    for candidate in manifest["candidates"]:
        lines.append("### Rank {0}: `{1}`".format(candidate["rank"], candidate["file_name"]))
        lines.append("")
        lines.append("- Predicted score: `{0}`".format(candidate["avg_predicted_score"]))
        lines.append("- Delta vs seed: `{0}`".format(candidate["delta_vs_seed"]))
        lines.append("- Delta vs baseline: `{0}`".format(candidate["delta_vs_baseline"]))
        lines.append("- Parameter changes:")
        for key, value in candidate["parameter_values"].items():
            lines.append("  - `{0} = {1}`".format(key, value))
        lines.append("- Sample directories:")
        for item in candidate["sample_directories"]:
            lines.append("  - `{0}` -> `{1}`".format(item["scenario"], item["path"]))
        lines.append("")

    return "\n".join(lines) + "\n"


def main():
    args = parse_args()
    ensure_dir(args.output_dir)

    summary = read_json(args.search_summary)
    manifest = build_validation_manifest(summary, args.search_summary, args.top_n, args.validation_date)

    manifest_path = os.path.join(args.output_dir, "candidate_validation_manifest.json")
    checklist_path = os.path.join(args.output_dir, "candidate_validation_checklist.md")

    write_json(manifest_path, manifest)
    write_text(checklist_path, build_markdown(manifest))

    print("Prepared validation pack for {0} candidates.".format(manifest["candidate_count"]))
    print("Manifest:  {0}".format(manifest_path))
    print("Checklist: {0}".format(checklist_path))


if __name__ == "__main__":
    main()
