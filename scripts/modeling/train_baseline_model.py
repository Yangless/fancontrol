#!/usr/bin/env python
import argparse
import json
import math
import os
from collections import OrderedDict
from datetime import datetime


MODEL_VERSION = "fancontrol.baseline-model.v1"

DEFAULT_FEATURES = [
    "cpu_package_c",
    "core_average_c",
    "min_distance_to_tjmax_c",
    "cpu_total_load_pct",
    "cpu_core_max_load_pct",
    "cpu_clock_avg_mhz",
    "pcore_clock_avg_mhz",
    "ecore_clock_avg_mhz",
    "cpu_package_power_w",
    "system_temp_c",
    "vrm_mos_temp_c",
    "pch_temp_c",
    "gpu_temp_c",
    "gpu_3d_util_pct",
    "cpu_fan_rpm",
    "system_fan2_rpm",
    "system_fan3_rpm",
    "system_fan4_rpm",
    "total_case_fan_rpm",
    "total_tracked_fan_rpm",
    "cpu_soft_margin_c",
    "gpu_soft_margin_c",
    "tjmax_soft_margin_c",
    "case_fan_share",
    "gpu_assist_share",
    "fan_per_cpu_w",
    "source_sample_count",
    "sample_progress_pct",
    "elapsed_seconds",
    "delta_seconds",
    "cpu_package_delta_1",
    "gpu_temp_delta_1",
    "total_tracked_fan_rpm_delta_1",
    "cpu_total_load_delta_1",
    "rolling_cpu_package_avg_3",
    "rolling_cpu_package_max_3",
    "rolling_gpu_temp_avg_3",
    "rolling_gpu_temp_max_3",
    "rolling_total_tracked_fan_rpm_avg_3",
    "rolling_total_tracked_fan_rpm_max_3",
    "rolling_cpu_total_load_avg_3",
    "rolling_cpu_total_load_max_3",
    "cfg_auto_idle_temp_c",
    "cfg_auto_min_speed_pct",
    "cfg_auto_max_speed_pct",
    "cfg_auto_load_temp_c",
    "cfg_auto_uses_gpu_temp",
    "cfg_auto1_idle_temp_c",
    "cfg_auto1_min_speed_pct",
    "cfg_auto1_max_speed_pct",
    "cfg_auto1_load_temp_c",
    "cfg_auto1_uses_gpu_temp",
    "cfg_auto2_idle_temp_c",
    "cfg_auto2_min_speed_pct",
    "cfg_auto2_max_speed_pct",
    "cfg_auto2_load_temp_c",
    "cfg_auto2_uses_gpu_temp",
    "cfg_system_fan3_start_pct",
    "cfg_system_fan3_stop_pct",
    "cfg_system_fan4_start_pct",
    "cfg_system_fan4_stop_pct",
]


def parse_args():
    parser = argparse.ArgumentParser(description="Train a simple ridge-regression baseline model for FanControl tuning.")
    parser.add_argument("--dataset", default=os.path.join("artifacts", "modeling", "training_rows.jsonl"))
    parser.add_argument("--output-dir", default=os.path.join("artifacts", "modeling"))
    parser.add_argument("--target-key", default="target_score")
    parser.add_argument("--ridge-alpha", type=float, default=1.0)
    return parser.parse_args()


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def safe_float(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    if isinstance(value, (int, float)):
        value = float(value)
        if math.isfinite(value):
            return value
        return None
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        try:
            parsed = float(stripped)
        except ValueError:
            return None
        if math.isfinite(parsed):
            return parsed
    return None


def median(values):
    ordered = sorted(values)
    size = len(ordered)
    if size == 0:
        return 0.0
    midpoint = size // 2
    if size % 2:
        return ordered[midpoint]
    return (ordered[midpoint - 1] + ordered[midpoint]) / 2.0


def load_jsonl(path):
    rows = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            rows.append(json.loads(stripped))
    return rows


def select_training_rows(rows, target_key):
    selected = []
    for row in rows:
        target_value = safe_float(row.get(target_key))
        if target_value is None:
            continue
        selected.append(row)
    return selected


def build_feature_statistics(rows, feature_names):
    medians = OrderedDict()
    means = OrderedDict()
    stds = OrderedDict()

    for feature in feature_names:
        values = [safe_float(row.get(feature)) for row in rows]
        values = [value for value in values if value is not None]
        medians[feature] = median(values)

    for feature in feature_names:
        filled = [safe_float(row.get(feature)) if safe_float(row.get(feature)) is not None else medians[feature] for row in rows]
        mean_value = sum(filled) / float(len(filled))
        variance = sum((value - mean_value) ** 2 for value in filled) / float(len(filled))
        std_value = math.sqrt(variance)
        means[feature] = mean_value
        stds[feature] = std_value if std_value > 1e-9 else 1.0

    return medians, means, stds


def vectorize_row(row, feature_names, medians, means, stds):
    vector = [1.0]
    for feature in feature_names:
        value = safe_float(row.get(feature))
        if value is None:
            value = medians[feature]
        centered = (value - means[feature]) / stds[feature]
        vector.append(centered)
    return vector


def solve_linear_system(matrix, vector):
    size = len(vector)
    augmented = [list(matrix[index]) + [vector[index]] for index in range(size)]

    for column in range(size):
        pivot_row = max(range(column, size), key=lambda row_index: abs(augmented[row_index][column]))
        pivot_value = augmented[pivot_row][column]
        if abs(pivot_value) < 1e-10:
            raise ValueError("Singular matrix while fitting baseline model.")
        if pivot_row != column:
            augmented[column], augmented[pivot_row] = augmented[pivot_row], augmented[column]

        divisor = augmented[column][column]
        augmented[column] = [value / divisor for value in augmented[column]]

        for row_index in range(size):
            if row_index == column:
                continue
            factor = augmented[row_index][column]
            if abs(factor) < 1e-12:
                continue
            augmented[row_index] = [
                augmented[row_index][cell_index] - factor * augmented[column][cell_index]
                for cell_index in range(size + 1)
            ]

    return [augmented[row_index][-1] for row_index in range(size)]


def fit_ridge_model(rows, feature_names, target_key, alpha):
    medians, means, stds = build_feature_statistics(rows, feature_names)
    design_matrix = [vectorize_row(row, feature_names, medians, means, stds) for row in rows]
    targets = [safe_float(row.get(target_key)) for row in rows]

    column_count = len(feature_names) + 1
    xtx = [[0.0 for _ in range(column_count)] for _ in range(column_count)]
    xty = [0.0 for _ in range(column_count)]

    for row_index, vector in enumerate(design_matrix):
        target = targets[row_index]
        for left in range(column_count):
            xty[left] += vector[left] * target
            for right in range(column_count):
                xtx[left][right] += vector[left] * vector[right]

    for diagonal in range(1, column_count):
        xtx[diagonal][diagonal] += alpha

    coefficients = solve_linear_system(xtx, xty)
    intercept = coefficients[0]
    weights = coefficients[1:]

    return {
        "intercept": intercept,
        "weights": OrderedDict((feature_names[index], weights[index]) for index in range(len(feature_names))),
        "medians": medians,
        "means": means,
        "stds": stds,
    }


def predict_row(model, row, feature_names):
    vector = vectorize_row(row, feature_names, model["medians"], model["means"], model["stds"])
    prediction = model["intercept"]
    weights = list(model["weights"].values())
    for index in range(len(weights)):
        prediction += weights[index] * vector[index + 1]
    return prediction


def compute_metrics(actuals, predictions):
    count = len(actuals)
    if count == 0:
        return {
            "row_count": 0,
            "mae": None,
            "rmse": None,
            "r2": None,
        }

    absolute_errors = [abs(actuals[index] - predictions[index]) for index in range(count)]
    squared_errors = [(actuals[index] - predictions[index]) ** 2 for index in range(count)]
    mae = sum(absolute_errors) / float(count)
    rmse = math.sqrt(sum(squared_errors) / float(count))
    mean_actual = sum(actuals) / float(count)
    total_variance = sum((value - mean_actual) ** 2 for value in actuals)
    residual_variance = sum(squared_errors)
    r2 = None if total_variance <= 1e-9 else 1.0 - (residual_variance / total_variance)

    return {
        "row_count": count,
        "mae": round(mae, 6),
        "rmse": round(rmse, 6),
        "r2": None if r2 is None else round(r2, 6),
    }


def leave_one_group_out_metrics(rows, feature_names, target_key, alpha):
    groups = OrderedDict()
    for row in rows:
        group_key = row.get("source_file") or row.get("scenario_name") or "unknown"
        groups.setdefault(group_key, []).append(row)

    if len(groups) < 2:
        return {
            "fold_count": 0,
            "mae": None,
            "rmse": None,
            "r2": None,
        }

    actuals = []
    predictions = []
    fold_count = 0

    group_items = list(groups.items())
    for holdout_key, holdout_rows in group_items:
        train_rows = []
        for candidate_key, candidate_rows in group_items:
            if candidate_key == holdout_key:
                continue
            train_rows.extend(candidate_rows)

        if len(train_rows) < 3:
            continue

        model = fit_ridge_model(train_rows, feature_names, target_key, alpha)
        for row in holdout_rows:
            actuals.append(safe_float(row.get(target_key)))
            predictions.append(predict_row(model, row, feature_names))
        fold_count += 1

    metrics = compute_metrics(actuals, predictions)
    metrics["fold_count"] = fold_count
    return metrics


def top_features(weights, limit):
    ranked = sorted(weights.items(), key=lambda item: abs(item[1]), reverse=True)
    return [{"feature": feature, "weight": round(weight, 6)} for feature, weight in ranked[:limit]]


def write_json(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def write_report(path, dataset_path, model_payload):
    lines = []
    lines.append("# FanControl Baseline Model Report")
    lines.append("")
    lines.append("- Model version: `{0}`".format(model_payload["model_version"]))
    lines.append("- Dataset: `{0}`".format(dataset_path.replace("\\", "/")))
    lines.append("- Target: `{0}`".format(model_payload["target_key"]))
    lines.append("- Training rows: `{0}`".format(model_payload["metrics"]["training"]["row_count"]))
    lines.append("")
    lines.append("## Metrics")
    lines.append("")
    lines.append("| Split | Rows | MAE | RMSE | R2 |")
    lines.append("|---|---:|---:|---:|---:|")

    training = model_payload["metrics"]["training"]
    cv = model_payload["metrics"]["leave_one_source_out"]
    lines.append("| Training | {0} | {1} | {2} | {3} |".format(
        training["row_count"],
        training["mae"],
        training["rmse"],
        training["r2"],
    ))
    lines.append("| Leave-one-source-out | {0} | {1} | {2} | {3} |".format(
        cv["fold_count"],
        cv["mae"],
        cv["rmse"],
        cv["r2"],
    ))
    lines.append("")
    lines.append("## Top Features")
    lines.append("")
    lines.append("| Feature | Weight |")
    lines.append("|---|---:|")
    for item in model_payload["top_features"]:
        lines.append("| {0} | {1} |".format(item["feature"], item["weight"]))
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- This is a ridge-regression baseline, not the final tuning model.")
    lines.append("- The model predicts `target_score`, which is a rule-derived composite label.")
    lines.append("- Use it to rank candidate curve settings, not to write directly into live configs.")

    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
        handle.write("\n")


def main():
    args = parse_args()
    ensure_dir(args.output_dir)

    rows = load_jsonl(args.dataset)
    training_rows = select_training_rows(rows, args.target_key)
    if len(training_rows) < 3:
        raise SystemExit("Not enough training rows after filtering target values.")

    feature_names = [feature for feature in DEFAULT_FEATURES if any(safe_float(row.get(feature)) is not None for row in training_rows)]
    if not feature_names:
        raise SystemExit("No usable numeric features found in dataset.")

    model = fit_ridge_model(training_rows, feature_names, args.target_key, args.ridge_alpha)
    predictions = [predict_row(model, row, feature_names) for row in training_rows]
    actuals = [safe_float(row.get(args.target_key)) for row in training_rows]

    payload = OrderedDict()
    payload["model_version"] = MODEL_VERSION
    payload["created_at"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    payload["dataset_path"] = args.dataset.replace("\\", "/")
    payload["target_key"] = args.target_key
    payload["ridge_alpha"] = args.ridge_alpha
    payload["feature_names"] = feature_names
    payload["intercept"] = round(model["intercept"], 6)
    payload["weights"] = OrderedDict((name, round(weight, 6)) for name, weight in model["weights"].items())
    payload["imputation_medians"] = OrderedDict((name, round(value, 6)) for name, value in model["medians"].items())
    payload["scaler_means"] = OrderedDict((name, round(value, 6)) for name, value in model["means"].items())
    payload["scaler_stds"] = OrderedDict((name, round(value, 6)) for name, value in model["stds"].items())
    payload["metrics"] = {
        "training": compute_metrics(actuals, predictions),
        "leave_one_source_out": leave_one_group_out_metrics(training_rows, feature_names, args.target_key, args.ridge_alpha),
    }
    payload["top_features"] = top_features(payload["weights"], 12)

    model_path = os.path.join(args.output_dir, "baseline_model.json")
    report_path = os.path.join(args.output_dir, "baseline_model_report.md")

    write_json(model_path, payload)
    write_report(report_path, args.dataset, payload)

    print("Trained baseline model on {0} rows with {1} features.".format(
        payload["metrics"]["training"]["row_count"],
        len(feature_names),
    ))
    print("Model:  {0}".format(model_path))
    print("Report: {0}".format(report_path))


if __name__ == "__main__":
    main()
