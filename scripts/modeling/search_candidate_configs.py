#!/usr/bin/env python
import argparse
import copy
import itertools
import json
import os
from collections import OrderedDict
from datetime import datetime

import build_training_dataset as dataset_builder
import score_candidate_config as candidate_score
import train_baseline_model as baseline_model


REPORT_VERSION = "fancontrol.candidate-search.v1"

SEARCH_SPECS = [
    {
        "path": "Auto.IdleTemperature",
        "curve_name": "Auto",
        "field_name": "IdleTemperature",
        "offsets": [-2, 0, 2],
        "min": 34,
        "max": 46,
    },
    {
        "path": "Auto.MinFanSpeed",
        "curve_name": "Auto",
        "field_name": "MinFanSpeed",
        "offsets": [-5, 0, 5],
        "min": 15,
        "max": 35,
    },
    {
        "path": "Auto.LoadTemperature",
        "curve_name": "Auto",
        "field_name": "LoadTemperature",
        "offsets": [-2, 0, 2],
        "min": 72,
        "max": 82,
    },
    {
        "path": "Auto 1.IdleTemperature",
        "curve_name": "Auto 1",
        "field_name": "IdleTemperature",
        "offsets": [-2, 0, 2],
        "min": 42,
        "max": 54,
    },
    {
        "path": "Auto 1.MinFanSpeed",
        "curve_name": "Auto 1",
        "field_name": "MinFanSpeed",
        "offsets": [-5, 0, 5],
        "min": 5,
        "max": 25,
    },
    {
        "path": "Auto 2.IdleTemperature",
        "curve_name": "Auto 2",
        "field_name": "IdleTemperature",
        "offsets": [-2, 0, 2],
        "min": 58,
        "max": 68,
    },
    {
        "path": "Auto 2.MinFanSpeed",
        "curve_name": "Auto 2",
        "field_name": "MinFanSpeed",
        "offsets": [0, 5, 10],
        "min": 0,
        "max": 15,
    },
    {
        "path": "Auto 2.LoadTemperature",
        "curve_name": "Auto 2",
        "field_name": "LoadTemperature",
        "offsets": [-2, 0, 2],
        "min": 70,
        "max": 78,
    },
]


def parse_args():
    parser = argparse.ArgumentParser(description="Search a constrained grid of candidate FanControl configs around a seed config.")
    parser.add_argument("--dataset", default=os.path.join("artifacts", "modeling", "training_rows.jsonl"))
    parser.add_argument("--model", default=os.path.join("artifacts", "modeling", "baseline_model.json"))
    parser.add_argument("--seed-config", required=True)
    parser.add_argument("--baseline-config", default="")
    parser.add_argument("--output-dir", default=os.path.join("artifacts", "modeling"))
    parser.add_argument("--top-k", type=int, default=12)
    parser.add_argument("--score-dedup-decimals", type=int, default=6)
    return parser.parse_args()


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def clear_candidate_dir(path):
    if not os.path.isdir(path):
        return
    for name in os.listdir(path):
        file_path = os.path.join(path, name)
        if os.path.isfile(file_path) and name.lower().endswith(".json"):
            os.remove(file_path)


def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def write_text(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def clamp(value, lower, upper):
    return max(lower, min(upper, value))


def find_curve(payload, curve_name):
    curves = payload.get("FanControl", {}).get("FanCurves", []) or []
    for curve in curves:
        if curve.get("Name") == curve_name:
            return curve
    return None


def get_curve_value(payload, curve_name, field_name):
    curve = find_curve(payload, curve_name)
    if not curve:
        return None
    return dataset_builder.safe_float(curve.get(field_name))


def set_curve_value(payload, curve_name, field_name, value):
    curve = find_curve(payload, curve_name)
    if not curve:
        raise KeyError("Curve not found: {0}".format(curve_name))
    curve[field_name] = int(value)


def materialize_search_dimensions(seed_payload):
    dimensions = []
    for spec in SEARCH_SPECS:
        seed_value = get_curve_value(seed_payload, spec["curve_name"], spec["field_name"])
        if seed_value is None:
            raise SystemExit("Seed config is missing {0}".format(spec["path"]))

        values = []
        for offset in spec["offsets"]:
            candidate_value = int(round(clamp(seed_value + offset, spec["min"], spec["max"])))
            if candidate_value not in values:
                values.append(candidate_value)

        dimensions.append(OrderedDict([
            ("path", spec["path"]),
            ("curve_name", spec["curve_name"]),
            ("field_name", spec["field_name"]),
            ("seed_value", int(round(seed_value))),
            ("values", values),
        ]))

    return dimensions


def apply_parameter_values(payload, parameter_values):
    updated = copy.deepcopy(payload)
    for parameter_path, value in parameter_values.items():
        curve_name, field_name = parameter_path.rsplit(".", 1)
        set_curve_value(updated, curve_name, field_name, value)
    return updated


def validate_candidate(payload):
    auto_idle = get_curve_value(payload, "Auto", "IdleTemperature")
    auto_min = get_curve_value(payload, "Auto", "MinFanSpeed")
    auto_load = get_curve_value(payload, "Auto", "LoadTemperature")
    auto_max = get_curve_value(payload, "Auto", "MaxFanSpeed")

    auto1_idle = get_curve_value(payload, "Auto 1", "IdleTemperature")
    auto1_min = get_curve_value(payload, "Auto 1", "MinFanSpeed")
    auto1_load = get_curve_value(payload, "Auto 1", "LoadTemperature")
    auto1_max = get_curve_value(payload, "Auto 1", "MaxFanSpeed")

    auto2_idle = get_curve_value(payload, "Auto 2", "IdleTemperature")
    auto2_min = get_curve_value(payload, "Auto 2", "MinFanSpeed")
    auto2_load = get_curve_value(payload, "Auto 2", "LoadTemperature")
    auto2_max = get_curve_value(payload, "Auto 2", "MaxFanSpeed")

    required_values = [
        auto_idle, auto_min, auto_load, auto_max,
        auto1_idle, auto1_min, auto1_load, auto1_max,
        auto2_idle, auto2_min, auto2_load, auto2_max,
    ]
    if any(value is None for value in required_values):
        return False

    if not (auto_idle <= auto1_idle <= auto2_idle):
        return False

    if not (auto_min >= auto1_min >= auto2_min):
        return False

    for idle, minimum, maximum, load, min_gap in [
        (auto_idle, auto_min, auto_max, auto_load, 18),
        (auto1_idle, auto1_min, auto1_max, auto1_load, 16),
        (auto2_idle, auto2_min, auto2_max, auto2_load, 8),
    ]:
        if minimum < 0 or minimum > maximum or maximum > 100:
            return False
        if load <= idle or (load - idle) < min_gap:
            return False

    return True


def score_config(model, rows, config_payload, config_label):
    config_features = dataset_builder.extract_config_features_from_payload(config_payload, config_label)
    scored_rows = []
    for row in rows:
        scored_row = candidate_score.apply_config_features(row, config_features)
        score = baseline_model.predict_model(model, scored_row)
        scored_rows.append({"row": scored_row, "score": score})
    return scored_rows


def average_score(summary):
    return summary["avg_predicted_score"] if summary else None


def round_delta(left, right):
    if left is None or right is None:
        return None
    return round(left - right, 6)


def count_changed_parameters(search_dimensions, parameter_values):
    changed = 0
    distance = 0.0
    for item in search_dimensions:
        seed_value = item["seed_value"]
        current_value = parameter_values[item["path"]]
        if current_value != seed_value:
            changed += 1
            distance += abs(current_value - seed_value)
    return changed, distance


def build_candidate_custom_metadata(seed_payload, rank, score_summary, parameter_values, seed_name):
    custom = OrderedDict()
    seed_custom = seed_payload.get("__CUSTOM__", {})
    for key, value in seed_custom.items():
        custom[key] = value

    custom["status"] = "model-ranked-candidate"
    custom["base_config"] = seed_name
    custom["generated_by"] = "scripts/modeling/search_candidate_configs.py"
    custom["generated_at"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    custom["candidate_rank"] = rank
    custom["predicted_score"] = score_summary["avg_predicted_score"]
    custom["search_parameters"] = parameter_values
    return custom


def write_candidate_payload(path, payload, custom_metadata):
    candidate_payload = copy.deepcopy(payload)
    candidate_payload["__CUSTOM__"] = custom_metadata
    write_json(path, candidate_payload)


def build_params_text(parameter_values):
    ordered_keys = [
        "Auto.IdleTemperature",
        "Auto.MinFanSpeed",
        "Auto.LoadTemperature",
        "Auto 1.IdleTemperature",
        "Auto 1.MinFanSpeed",
        "Auto 2.IdleTemperature",
        "Auto 2.MinFanSpeed",
        "Auto 2.LoadTemperature",
    ]
    parts = []
    for key in ordered_keys:
        parts.append("{0}={1}".format(key, parameter_values[key]))
    return ", ".join(parts)


def distinct_top_candidates(sorted_candidates, top_k, score_dedup_decimals):
    selected = []
    seen_score_buckets = set()

    for item in sorted_candidates:
        score_value = item["avg_predicted_score"]
        if score_value is None:
            continue

        bucket = round(score_value, score_dedup_decimals)
        if bucket in seen_score_buckets:
            continue

        seen_score_buckets.add(bucket)
        selected.append(item)
        if len(selected) >= top_k:
            break

    return selected


def build_report_text(summary):
    lines = []
    lines.append("# FanControl Candidate Search Report")
    lines.append("")
    lines.append("- Report version: `{0}`".format(summary["report_version"]))
    lines.append("- Model: `{0}`".format(summary["model_path"]))
    lines.append("- Model name: `{0}`".format(summary["model_name"]))
    lines.append("- Model type: `{0}`".format(summary["model_type"]))
    lines.append("- Dataset: `{0}`".format(summary["dataset_path"]))
    lines.append("- Seed config: `{0}`".format(summary["seed_config"]))
    if summary.get("baseline_config"):
        lines.append("- Baseline config: `{0}`".format(summary["baseline_config"]))
    lines.append("- Evaluated candidates: `{0}`".format(summary["evaluated_candidate_count"]))
    lines.append("- Invalid candidates skipped: `{0}`".format(summary["invalid_candidate_count"]))
    lines.append("")
    lines.append("## Search Dimensions")
    lines.append("")
    lines.append("| Parameter | Seed | Candidate values |")
    lines.append("|---|---:|---|")
    for item in summary["search_dimensions"]:
        values_text = ", ".join(str(value) for value in item["values"])
        lines.append("| {0} | {1} | {2} |".format(item["path"], item["seed_value"], values_text))
    lines.append("")
    lines.append("## Reference Scores")
    lines.append("")
    lines.append("| Config | Avg predicted score |")
    lines.append("|---|---:|")
    lines.append("| Seed | {0} |".format(summary["seed_summary"]["avg_predicted_score"]))
    if summary.get("baseline_summary"):
        lines.append("| Baseline | {0} |".format(summary["baseline_summary"]["avg_predicted_score"]))
    lines.append("")
    lines.append("## Top Distinct Candidates")
    lines.append("")
    lines.append("| Rank | File | Avg score | Delta vs seed | Delta vs baseline | Parameters |")
    lines.append("|---|---|---:|---:|---:|---|")
    for item in summary["top_candidates"]:
        lines.append("| {0} | {1} | {2} | {3} | {4} | {5} |".format(
            item["rank"],
            item["file_name"],
            item["avg_predicted_score"],
            item["delta_vs_seed"],
            item["delta_vs_baseline"],
            build_params_text(item["parameter_values"]),
        ))
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- This search only changes a constrained set of curve fields around the accepted seed config.")
    lines.append("- The ranked output keeps one representative candidate per rounded score bucket to avoid repeated ties crowding out review bandwidth.")
    lines.append("- Candidate configs are written to `artifacts/modeling/candidates/` style outputs for review and manual validation.")
    lines.append("- Scores come from the baseline model and historical replay, so live thermal verification is still required.")
    return "\n".join(lines) + "\n"


def main():
    args = parse_args()
    ensure_dir(args.output_dir)

    candidate_dir = os.path.join(args.output_dir, "candidates")
    ensure_dir(candidate_dir)
    clear_candidate_dir(candidate_dir)

    model = candidate_score.load_model(args.model)
    rows = candidate_score.load_rows(args.dataset)
    seed_payload = read_json(args.seed_config)
    search_dimensions = materialize_search_dimensions(seed_payload)

    baseline_payload = None
    if args.baseline_config:
        baseline_payload = read_json(args.baseline_config)

    seed_scored_rows = score_config(model, rows, seed_payload, os.path.basename(args.seed_config))
    seed_summary = candidate_score.summarize_rows(
        [item["row"] for item in seed_scored_rows],
        [item["score"] for item in seed_scored_rows],
    )

    baseline_summary = None
    if baseline_payload is not None:
        baseline_scored_rows = score_config(model, rows, baseline_payload, os.path.basename(args.baseline_config))
        baseline_summary = candidate_score.summarize_rows(
            [item["row"] for item in baseline_scored_rows],
            [item["score"] for item in baseline_scored_rows],
        )

    parameter_names = [item["path"] for item in search_dimensions]
    parameter_values_list = [item["values"] for item in search_dimensions]

    all_candidates = []
    invalid_candidate_count = 0
    evaluated_candidate_count = 0

    for combination in itertools.product(*parameter_values_list):
        parameter_values = OrderedDict((parameter_names[index], combination[index]) for index in range(len(parameter_names)))
        candidate_payload = apply_parameter_values(seed_payload, parameter_values)
        if not validate_candidate(candidate_payload):
            invalid_candidate_count += 1
            continue

        scored_rows = score_config(model, rows, candidate_payload, os.path.basename(args.seed_config))
        candidate_summary = candidate_score.summarize_rows(
            [item["row"] for item in scored_rows],
            [item["score"] for item in scored_rows],
        )
        candidate_record = OrderedDict()
        candidate_record["parameter_values"] = parameter_values
        candidate_record["avg_predicted_score"] = candidate_summary["avg_predicted_score"]
        candidate_record["delta_vs_seed"] = round_delta(
            average_score(candidate_summary),
            average_score(seed_summary),
        )
        candidate_record["delta_vs_baseline"] = round_delta(
            average_score(candidate_summary),
            average_score(baseline_summary),
        )
        changed_parameter_count, distance_from_seed = count_changed_parameters(search_dimensions, parameter_values)
        candidate_record["changed_parameter_count"] = changed_parameter_count
        candidate_record["distance_from_seed"] = distance_from_seed
        candidate_record["summary"] = candidate_summary
        candidate_record["payload"] = candidate_payload
        all_candidates.append(candidate_record)
        evaluated_candidate_count += 1

    all_candidates.sort(
        key=lambda item: (
            item["avg_predicted_score"] if item["avg_predicted_score"] is not None else -999999.0,
            -item["changed_parameter_count"],
            -item["distance_from_seed"],
        ),
        reverse=True,
    )

    selected_candidates = distinct_top_candidates(all_candidates, max(args.top_k, 0), args.score_dedup_decimals)

    top_candidates = []
    seed_name = os.path.basename(args.seed_config)
    for index, item in enumerate(selected_candidates):
        rank = index + 1
        file_name = "candidate_rank{0:02d}_score{1:.3f}.json".format(rank, item["avg_predicted_score"])
        file_path = os.path.join(candidate_dir, file_name)
        custom_metadata = build_candidate_custom_metadata(seed_payload, rank, item["summary"], item["parameter_values"], seed_name)
        write_candidate_payload(file_path, item["payload"], custom_metadata)

        top_record = OrderedDict()
        top_record["rank"] = rank
        top_record["file_name"] = file_name
        top_record["file_path"] = file_path.replace("\\", "/")
        top_record["avg_predicted_score"] = item["avg_predicted_score"]
        top_record["delta_vs_seed"] = item["delta_vs_seed"]
        top_record["delta_vs_baseline"] = item["delta_vs_baseline"]
        top_record["parameter_values"] = item["parameter_values"]
        top_record["summary"] = item["summary"]
        top_candidates.append(top_record)

    summary = OrderedDict()
    summary["report_version"] = REPORT_VERSION
    summary["created_at"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    summary["dataset_path"] = args.dataset.replace("\\", "/")
    summary["model_path"] = args.model.replace("\\", "/")
    summary["model_name"] = model.get("name")
    summary["model_type"] = model.get("model_type")
    summary["seed_config"] = seed_name
    summary["baseline_config"] = os.path.basename(args.baseline_config) if args.baseline_config else None
    summary["search_dimensions"] = search_dimensions
    summary["evaluated_candidate_count"] = evaluated_candidate_count
    summary["invalid_candidate_count"] = invalid_candidate_count
    summary["top_k"] = args.top_k
    summary["score_dedup_decimals"] = args.score_dedup_decimals
    summary["selected_candidate_count"] = len(top_candidates)
    summary["seed_summary"] = seed_summary
    summary["baseline_summary"] = baseline_summary
    summary["top_candidates"] = top_candidates

    summary_path = os.path.join(args.output_dir, "candidate_search_summary.json")
    report_path = os.path.join(args.output_dir, "candidate_search_report.md")
    write_json(summary_path, summary)
    write_text(report_path, build_report_text(summary))

    print("Evaluated {0} valid candidates ({1} invalid skipped).".format(
        evaluated_candidate_count,
        invalid_candidate_count,
    ))
    print("Summary: {0}".format(summary_path))
    print("Report:  {0}".format(report_path))
    print("Files:   {0}".format(candidate_dir))


if __name__ == "__main__":
    main()
