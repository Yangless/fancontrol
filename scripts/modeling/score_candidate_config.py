#!/usr/bin/env python
import argparse
import json
import os
from collections import Counter, OrderedDict
from datetime import datetime

import build_training_dataset as dataset_builder
import train_baseline_model as baseline_model


REPORT_VERSION = "fancontrol.candidate-score.v1"


def parse_args():
    parser = argparse.ArgumentParser(description="Score a candidate FanControl config against the baseline model.")
    parser.add_argument("--dataset", default=os.path.join("artifacts", "modeling", "training_rows.jsonl"))
    parser.add_argument("--model", default=os.path.join("artifacts", "modeling", "baseline_model.json"))
    parser.add_argument("--candidate-config", required=True)
    parser.add_argument("--baseline-config", default="")
    parser.add_argument("--output-dir", default=os.path.join("artifacts", "modeling"))
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


def load_model(path):
    payload = read_json(path)
    return payload


def load_rows(path):
    return baseline_model.load_jsonl(path)


def apply_config_features(row, config_features):
    updated = OrderedDict(row)
    for key, value in config_features.items():
        updated[key] = value
    return updated


def average(values):
    values = [value for value in values if value is not None]
    if not values:
        return None
    return sum(values) / float(len(values))


def summarize_rows(rows, scores):
    summary = OrderedDict()
    summary["row_count"] = len(scores)
    summary["avg_predicted_score"] = round(average(scores), 6) if scores else None
    summary["avg_cpu_package_c"] = round(average([dataset_builder.safe_float(row.get("cpu_package_c")) for row in rows]), 6) if rows else None
    summary["avg_gpu_temp_c"] = round(average([dataset_builder.safe_float(row.get("gpu_temp_c")) for row in rows]), 6) if rows else None
    summary["avg_total_tracked_fan_rpm"] = round(average([dataset_builder.safe_float(row.get("total_tracked_fan_rpm")) for row in rows]), 6) if rows else None
    summary["safety_label_counts"] = dict(Counter(row.get("safety_label") for row in rows))
    return summary


def summarize_by_key(scored_rows, key_name):
    grouped = OrderedDict()
    for item in scored_rows:
        key_value = item["row"].get(key_name) or "unknown"
        grouped.setdefault(key_value, []).append(item)

    result = []
    for key_value, items in grouped.items():
        rows = [item["row"] for item in items]
        scores = [item["score"] for item in items]
        record = OrderedDict()
        record[key_name] = key_value
        record.update(summarize_rows(rows, scores))
        result.append(record)

    result.sort(key=lambda item: item["avg_predicted_score"] if item["avg_predicted_score"] is not None else -9999, reverse=True)
    return result


def build_report_text(summary):
    lines = []
    lines.append("# FanControl Candidate Config Score Report")
    lines.append("")
    lines.append("- Report version: `{0}`".format(summary["report_version"]))
    lines.append("- Candidate config: `{0}`".format(summary["candidate_config"]))
    lines.append("- Model: `{0}`".format(summary["model_path"]))
    lines.append("- Model name: `{0}`".format(summary["model_name"]))
    lines.append("- Model type: `{0}`".format(summary["model_type"]))
    lines.append("- Dataset: `{0}`".format(summary["dataset_path"]))
    if summary.get("baseline_config"):
        lines.append("- Baseline config: `{0}`".format(summary["baseline_config"]))
    lines.append("")
    lines.append("## Overall")
    lines.append("")
    lines.append("| Metric | Candidate | Baseline | Delta |")
    lines.append("|---|---:|---:|---:|")

    candidate = summary["candidate_summary"]
    baseline = summary.get("baseline_summary")
    baseline_score = baseline["avg_predicted_score"] if baseline else None
    delta = None
    if baseline_score is not None and candidate["avg_predicted_score"] is not None:
        delta = round(candidate["avg_predicted_score"] - baseline_score, 6)

    lines.append("| Avg predicted score | {0} | {1} | {2} |".format(
        candidate["avg_predicted_score"],
        baseline_score,
        delta,
    ))
    lines.append("| Avg CPU package (from dataset rows) | {0} | {1} | - |".format(
        candidate["avg_cpu_package_c"],
        baseline["avg_cpu_package_c"] if baseline else None,
    ))
    lines.append("| Avg GPU temp (from dataset rows) | {0} | {1} | - |".format(
        candidate["avg_gpu_temp_c"],
        baseline["avg_gpu_temp_c"] if baseline else None,
    ))
    lines.append("| Avg total tracked RPM (from dataset rows) | {0} | {1} | - |".format(
        candidate["avg_total_tracked_fan_rpm"],
        baseline["avg_total_tracked_fan_rpm"] if baseline else None,
    ))
    lines.append("")
    lines.append("## By Workload Class")
    lines.append("")
    lines.append("| Workload | Rows | Candidate score | Baseline score | Delta |")
    lines.append("|---|---:|---:|---:|---:|")

    baseline_by_workload = OrderedDict()
    for item in summary.get("baseline_by_workload_class", []):
        baseline_by_workload[item["workload_class"]] = item

    for item in summary["candidate_by_workload_class"]:
        baseline_item = baseline_by_workload.get(item["workload_class"])
        baseline_value = baseline_item["avg_predicted_score"] if baseline_item else None
        workload_delta = None
        if baseline_value is not None and item["avg_predicted_score"] is not None:
            workload_delta = round(item["avg_predicted_score"] - baseline_value, 6)
        lines.append("| {0} | {1} | {2} | {3} | {4} |".format(
            item["workload_class"],
            item["row_count"],
            item["avg_predicted_score"],
            baseline_value,
            workload_delta,
        ))

    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- This score is a model estimate, not a live thermal validation.")
    lines.append("- The candidate config is replayed across historical hardware states from the dataset.")
    lines.append("- Use this as a ranking tool before real-world verification.")
    return "\n".join(lines) + "\n"


def main():
    args = parse_args()
    ensure_dir(args.output_dir)

    model = load_model(args.model)
    rows = load_rows(args.dataset)
    candidate_features = dataset_builder.load_config_features_from_path(args.candidate_config)
    if not candidate_features:
        raise SystemExit("Candidate config could not be parsed: {0}".format(args.candidate_config))

    baseline_features = None
    if args.baseline_config:
        baseline_features = dataset_builder.load_config_features_from_path(args.baseline_config)
        if not baseline_features:
            raise SystemExit("Baseline config could not be parsed: {0}".format(args.baseline_config))

    scored_candidate = []
    for row in rows:
        scored_row = apply_config_features(row, candidate_features)
        score = baseline_model.predict_model(model, scored_row)
        scored_candidate.append({"row": scored_row, "score": score})

    scored_baseline = []
    if baseline_features:
        for row in rows:
            scored_row = apply_config_features(row, baseline_features)
            score = baseline_model.predict_model(model, scored_row)
            scored_baseline.append({"row": scored_row, "score": score})

    summary = OrderedDict()
    summary["report_version"] = REPORT_VERSION
    summary["created_at"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    summary["dataset_path"] = args.dataset.replace("\\", "/")
    summary["model_path"] = args.model.replace("\\", "/")
    summary["model_name"] = model.get("name")
    summary["model_type"] = model.get("model_type")
    summary["candidate_config"] = os.path.basename(args.candidate_config)
    summary["baseline_config"] = os.path.basename(args.baseline_config) if args.baseline_config else None
    summary["candidate_summary"] = summarize_rows([item["row"] for item in scored_candidate], [item["score"] for item in scored_candidate])
    summary["candidate_by_workload_class"] = summarize_by_key(scored_candidate, "workload_class")
    summary["candidate_by_source_file"] = summarize_by_key(scored_candidate, "source_file")

    if scored_baseline:
        summary["baseline_summary"] = summarize_rows([item["row"] for item in scored_baseline], [item["score"] for item in scored_baseline])
        summary["baseline_by_workload_class"] = summarize_by_key(scored_baseline, "workload_class")
        summary["baseline_by_source_file"] = summarize_by_key(scored_baseline, "source_file")

    summary_path = os.path.join(args.output_dir, "candidate_score_summary.json")
    report_path = os.path.join(args.output_dir, "candidate_score_report.md")
    write_json(summary_path, summary)
    with open(report_path, "w", encoding="utf-8") as handle:
        handle.write(build_report_text(summary))

    print("Scored candidate config across {0} dataset rows.".format(summary["candidate_summary"]["row_count"]))
    print("Summary: {0}".format(summary_path))
    print("Report:  {0}".format(report_path))


if __name__ == "__main__":
    main()
