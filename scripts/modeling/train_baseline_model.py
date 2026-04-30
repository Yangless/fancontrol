#!/usr/bin/env python
import argparse
import json
import math
import os
import random
from collections import OrderedDict
from datetime import datetime


MODEL_VERSION = "fancontrol.baseline-model.v2"

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

DEFAULT_RIDGE_CV_ALPHAS = [0.01, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0]


def parse_args():
    parser = argparse.ArgumentParser(description="Train comparable baseline models for FanControl tuning.")
    parser.add_argument("--dataset", default=os.path.join("artifacts", "modeling", "training_rows.jsonl"))
    parser.add_argument("--output-dir", default=os.path.join("artifacts", "modeling"))
    parser.add_argument("--target-key", default="target_score")
    parser.add_argument("--ridge-alpha", type=float, default=1.0)
    parser.add_argument("--preferred-model", choices=["ridge", "ridge_cv", "random_forest"], default="ridge_cv")
    parser.add_argument("--ridge-cv-alphas", default=",".join(str(value) for value in DEFAULT_RIDGE_CV_ALPHAS))
    parser.add_argument("--rf-tree-count", type=int, default=12)
    parser.add_argument("--rf-max-depth", type=int, default=5)
    parser.add_argument("--rf-min-leaf-size", type=int, default=4)
    parser.add_argument("--rf-feature-fraction", type=float, default=0.35)
    parser.add_argument("--rf-row-fraction", type=float, default=0.8)
    parser.add_argument("--rf-random-seed", type=int, default=42)
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
        filled = []
        for row in rows:
            value = safe_float(row.get(feature))
            if value is None:
                value = medians[feature]
            filled.append(value)
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


def dense_vector_row(row, feature_names, medians):
    vector = []
    for feature in feature_names:
        value = safe_float(row.get(feature))
        if value is None:
            value = medians[feature]
        vector.append(value)
    return vector


def solve_linear_system(matrix, vector):
    size = len(vector)
    augmented = [list(matrix[index]) + [vector[index]] for index in range(size)]

    for column in range(size):
        pivot_row = max(range(column, size), key=lambda row_index: abs(augmented[row_index][column]))
        pivot_value = augmented[pivot_row][column]
        if abs(pivot_value) < 1e-10:
            raise ValueError("Singular matrix while fitting ridge model.")
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


def fit_ridge_coefficients(rows, feature_names, target_key, alpha):
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
        "feature_names": feature_names,
        "intercept": intercept,
        "weights": OrderedDict((feature_names[index], weights[index]) for index in range(len(feature_names))),
        "medians": medians,
        "means": means,
        "stds": stds,
        "alpha": alpha,
    }


def predict_ridge_row(model_payload, row):
    vector = vectorize_row(
        row,
        model_payload["feature_names"],
        model_payload["imputation_medians"],
        model_payload["scaler_means"],
        model_payload["scaler_stds"],
    )
    prediction = model_payload["intercept"]
    weights = [model_payload["weights"][feature] for feature in model_payload["feature_names"]]
    for index in range(len(weights)):
        prediction += weights[index] * vector[index + 1]
    return prediction


def average(values):
    if not values:
        return None
    return sum(values) / float(len(values))


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


def group_rows(rows):
    groups = OrderedDict()
    for row in rows:
        group_key = row.get("source_file") or row.get("scenario_name") or "unknown"
        groups.setdefault(group_key, []).append(row)
    return groups


def get_group_splits(rows):
    groups = group_rows(rows)
    if len(groups) < 2:
        return []

    items = list(groups.items())
    splits = []
    for holdout_key, holdout_rows in items:
        train_rows = []
        for candidate_key, candidate_rows in items:
            if candidate_key == holdout_key:
                continue
            train_rows.extend(candidate_rows)
        if len(train_rows) < 3:
            continue
        splits.append({
            "holdout_key": holdout_key,
            "train_rows": train_rows,
            "holdout_rows": holdout_rows,
        })
    return splits


def build_ridge_payload(rows, feature_names, target_key, alpha, model_name, compute_cv=True):
    fitted = fit_ridge_coefficients(rows, feature_names, target_key, alpha)
    predictions = [predict_ridge_row({
        "feature_names": feature_names,
        "intercept": fitted["intercept"],
        "weights": fitted["weights"],
        "imputation_medians": fitted["medians"],
        "scaler_means": fitted["means"],
        "scaler_stds": fitted["stds"],
    }, row) for row in rows]
    actuals = [safe_float(row.get(target_key)) for row in rows]

    payload = OrderedDict()
    payload["name"] = model_name
    payload["model_type"] = "ridge"
    payload["target_key"] = target_key
    payload["feature_names"] = feature_names
    payload["intercept"] = round(fitted["intercept"], 6)
    payload["weights"] = OrderedDict((name, round(weight, 6)) for name, weight in fitted["weights"].items())
    payload["imputation_medians"] = OrderedDict((name, round(value, 6)) for name, value in fitted["medians"].items())
    payload["scaler_means"] = OrderedDict((name, round(value, 6)) for name, value in fitted["means"].items())
    payload["scaler_stds"] = OrderedDict((name, round(value, 6)) for name, value in fitted["stds"].items())
    payload["hyperparameters"] = OrderedDict([("alpha", alpha)])
    payload["metrics"] = OrderedDict()
    payload["metrics"]["training"] = compute_metrics(actuals, predictions)
    if compute_cv:
        payload["metrics"]["leave_one_source_out"] = compute_leave_one_group_out_metrics(
            rows,
            target_key,
            lambda train_rows: build_ridge_payload(train_rows, feature_names, target_key, alpha, model_name, False),
        )
    else:
        payload["metrics"]["leave_one_source_out"] = {
            "fold_count": 0,
            "row_count": 0,
            "mae": None,
            "rmse": None,
            "r2": None,
        }
    payload["top_features"] = top_features(payload["weights"], 12)
    return payload


def parse_alphas(text):
    values = []
    for part in text.split(","):
        stripped = part.strip()
        if not stripped:
            continue
        values.append(float(stripped))
    return values or list(DEFAULT_RIDGE_CV_ALPHAS)


def build_ridge_cv_payload(rows, feature_names, target_key, alpha_candidates):
    splits = get_group_splits(rows)
    if not splits:
        selected_alpha = alpha_candidates[0]
    else:
        scored = []
        for alpha in alpha_candidates:
            actuals = []
            predictions = []
            for split in splits:
                fold_model = build_ridge_payload(split["train_rows"], feature_names, target_key, alpha, "ridge_cv_fold", False)
                for row in split["holdout_rows"]:
                    actuals.append(safe_float(row.get(target_key)))
                    predictions.append(predict_model(fold_model, row))
            metrics = compute_metrics(actuals, predictions)
            mae = metrics["mae"] if metrics["mae"] is not None else 999999.0
            scored.append((mae, alpha))
        scored.sort(key=lambda item: (item[0], item[1]))
        selected_alpha = scored[0][1]

    payload = build_ridge_payload(rows, feature_names, target_key, selected_alpha, "ridge_cv")
    payload["name"] = "ridge_cv"
    payload["model_type"] = "ridge"
    payload["hyperparameters"] = OrderedDict([
        ("alpha", selected_alpha),
        ("alpha_candidates", alpha_candidates),
    ])
    return payload


def choose_feature_subset(feature_names, feature_fraction, rng):
    subset_size = max(1, int(math.ceil(len(feature_names) * feature_fraction)))
    indices = list(range(len(feature_names)))
    rng.shuffle(indices)
    chosen = sorted(indices[:subset_size])
    return chosen


def compute_sse(targets):
    if not targets:
        return 0.0
    mean_value = sum(targets) / float(len(targets))
    return sum((value - mean_value) ** 2 for value in targets)


def make_leaf(node_targets):
    return {"type": "leaf", "value": average(node_targets)}


def best_split_for_node(feature_matrix, targets, feature_indices, min_leaf_size):
    row_count = len(targets)
    if row_count < (min_leaf_size * 2):
        return None

    best = None
    parent_sse = compute_sse(targets)

    for feature_index in feature_indices:
        values = [feature_matrix[row_index][feature_index] for row_index in range(row_count)]
        unique_values = sorted(set(values))
        if len(unique_values) < 2:
            continue

        thresholds = []
        for index in range(len(unique_values) - 1):
            thresholds.append((unique_values[index] + unique_values[index + 1]) / 2.0)
        if len(thresholds) > 8:
            sampled_thresholds = []
            last_index = len(thresholds) - 1
            for bucket_index in range(8):
                chosen_index = int(round((float(bucket_index) / 7.0) * last_index))
                threshold = thresholds[chosen_index]
                if threshold not in sampled_thresholds:
                    sampled_thresholds.append(threshold)
            thresholds = sampled_thresholds

        for threshold in thresholds:
            left_targets = []
            right_targets = []
            left_rows = []
            right_rows = []
            for row_index in range(row_count):
                value = feature_matrix[row_index][feature_index]
                if value <= threshold:
                    left_rows.append(row_index)
                    left_targets.append(targets[row_index])
                else:
                    right_rows.append(row_index)
                    right_targets.append(targets[row_index])

            if len(left_rows) < min_leaf_size or len(right_rows) < min_leaf_size:
                continue

            loss = compute_sse(left_targets) + compute_sse(right_targets)
            gain = parent_sse - loss
            if gain <= 1e-9:
                continue

            candidate = {
                "feature_index": feature_index,
                "threshold": threshold,
                "left_rows": left_rows,
                "right_rows": right_rows,
                "gain": gain,
            }
            if best is None or candidate["gain"] > best["gain"]:
                best = candidate

    return best


def build_tree(feature_matrix, targets, feature_names, max_depth, min_leaf_size, feature_fraction, rng, depth):
    if not targets:
        return {"type": "leaf", "value": 0.0}
    if depth >= max_depth or len(targets) <= (min_leaf_size * 2):
        return make_leaf(targets)

    feature_indices = choose_feature_subset(feature_names, feature_fraction, rng)
    split = best_split_for_node(feature_matrix, targets, feature_indices, min_leaf_size)
    if split is None:
        return make_leaf(targets)

    left_matrix = [feature_matrix[index] for index in split["left_rows"]]
    left_targets = [targets[index] for index in split["left_rows"]]
    right_matrix = [feature_matrix[index] for index in split["right_rows"]]
    right_targets = [targets[index] for index in split["right_rows"]]

    return {
        "type": "node",
        "feature_index": split["feature_index"],
        "feature_name": feature_names[split["feature_index"]],
        "threshold": split["threshold"],
        "left": build_tree(left_matrix, left_targets, feature_names, max_depth, min_leaf_size, feature_fraction, rng, depth + 1),
        "right": build_tree(right_matrix, right_targets, feature_names, max_depth, min_leaf_size, feature_fraction, rng, depth + 1),
    }


def predict_tree(tree, vector):
    node = tree
    while node["type"] != "leaf":
        if vector[node["feature_index"]] <= node["threshold"]:
            node = node["left"]
        else:
            node = node["right"]
    return node["value"]


def fit_random_forest_payload(rows, feature_names, target_key, tree_count, max_depth, min_leaf_size, feature_fraction, row_fraction, random_seed, compute_cv=True):
    medians, _, _ = build_feature_statistics(rows, feature_names)
    matrix = [dense_vector_row(row, feature_names, medians) for row in rows]
    targets = [safe_float(row.get(target_key)) for row in rows]

    rng = random.Random(random_seed)
    trees = []
    sample_size = max(2, int(math.ceil(len(rows) * row_fraction)))
    for tree_index in range(tree_count):
        sampled_indices = [rng.randrange(len(rows)) for _ in range(sample_size)]
        sampled_matrix = [matrix[index] for index in sampled_indices]
        sampled_targets = [targets[index] for index in sampled_indices]
        tree_rng = random.Random(random_seed + tree_index + 1)
        tree = build_tree(
            sampled_matrix,
            sampled_targets,
            feature_names,
            max_depth,
            min_leaf_size,
            feature_fraction,
            tree_rng,
            0,
        )
        trees.append(tree)

    payload = OrderedDict()
    payload["name"] = "random_forest"
    payload["model_type"] = "random_forest"
    payload["target_key"] = target_key
    payload["feature_names"] = feature_names
    payload["imputation_medians"] = OrderedDict((name, round(value, 6)) for name, value in medians.items())
    payload["trees"] = trees
    payload["hyperparameters"] = OrderedDict([
        ("tree_count", tree_count),
        ("max_depth", max_depth),
        ("min_leaf_size", min_leaf_size),
        ("feature_fraction", feature_fraction),
        ("row_fraction", row_fraction),
        ("random_seed", random_seed),
    ])

    predictions = [predict_model(payload, row) for row in rows]
    payload["metrics"] = OrderedDict()
    payload["metrics"]["training"] = compute_metrics(targets, predictions)
    if compute_cv:
        payload["metrics"]["leave_one_source_out"] = compute_leave_one_group_out_metrics(
            rows,
            target_key,
            lambda train_rows: fit_random_forest_payload(
                train_rows,
                feature_names,
                target_key,
                min(tree_count, 6),
                min(max_depth, 4),
                min_leaf_size,
                feature_fraction,
                row_fraction,
                random_seed,
                False,
            ),
        )
    else:
        payload["metrics"]["leave_one_source_out"] = {
            "fold_count": 0,
            "row_count": 0,
            "mae": None,
            "rmse": None,
            "r2": None,
        }
    payload["top_features"] = top_random_forest_features(payload, 12)
    return payload


def predict_model(model_payload, row):
    model_type = model_payload["model_type"]
    if model_type == "ridge":
        return predict_ridge_row(model_payload, row)
    if model_type == "random_forest":
        medians = model_payload["imputation_medians"]
        vector = dense_vector_row(row, model_payload["feature_names"], medians)
        values = [predict_tree(tree, vector) for tree in model_payload["trees"]]
        return average(values)
    raise ValueError("Unsupported model_type: {0}".format(model_type))


def compute_leave_one_group_out_metrics(rows, target_key, fit_model_callback):
    splits = get_group_splits(rows)
    if not splits:
        return {
            "fold_count": 0,
            "row_count": 0,
            "mae": None,
            "rmse": None,
            "r2": None,
        }

    actuals = []
    predictions = []
    fold_count = 0

    for split in splits:
        model_payload = fit_model_callback(split["train_rows"])
        for row in split["holdout_rows"]:
            actuals.append(safe_float(row.get(target_key)))
            predictions.append(predict_model(model_payload, row))
        fold_count += 1

    metrics = compute_metrics(actuals, predictions)
    metrics["fold_count"] = fold_count
    return metrics


def top_features(weights, limit):
    ranked = sorted(weights.items(), key=lambda item: abs(item[1]), reverse=True)
    return [{"feature": feature, "weight": round(weight, 6)} for feature, weight in ranked[:limit]]


def accumulate_tree_feature_usage(tree, counts):
    if tree["type"] == "leaf":
        return
    feature_name = tree["feature_name"]
    counts[feature_name] = counts.get(feature_name, 0) + 1
    accumulate_tree_feature_usage(tree["left"], counts)
    accumulate_tree_feature_usage(tree["right"], counts)


def top_random_forest_features(model_payload, limit):
    counts = {}
    for tree in model_payload["trees"]:
        accumulate_tree_feature_usage(tree, counts)
    ranked = sorted(counts.items(), key=lambda item: item[1], reverse=True)
    return [{"feature": feature, "weight": count} for feature, count in ranked[:limit]]


def write_json(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def format_metric(value):
    if value is None:
        return "None"
    return value


def write_report(path, dataset_path, bundle_payload):
    lines = []
    lines.append("# FanControl Baseline Model Comparison Report")
    lines.append("")
    lines.append("- Model version: `{0}`".format(bundle_payload["model_version"]))
    lines.append("- Dataset: `{0}`".format(dataset_path.replace("\\", "/")))
    lines.append("- Target: `{0}`".format(bundle_payload["target_key"]))
    lines.append("- Training rows: `{0}`".format(bundle_payload["row_count"]))
    lines.append("- Preferred model: `{0}`".format(bundle_payload["preferred_model"]))
    lines.append("")
    lines.append("## Model Comparison")
    lines.append("")
    lines.append("| Model | Train MAE | Train RMSE | Train R2 | CV folds | CV MAE | CV RMSE | CV R2 |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")

    for model_name, model_payload in bundle_payload["models"].items():
        training = model_payload["metrics"]["training"]
        cv = model_payload["metrics"]["leave_one_source_out"]
        lines.append("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |".format(
            model_name,
            format_metric(training["mae"]),
            format_metric(training["rmse"]),
            format_metric(training["r2"]),
            format_metric(cv["fold_count"]),
            format_metric(cv["mae"]),
            format_metric(cv["rmse"]),
            format_metric(cv["r2"]),
        ))

    lines.append("")
    lines.append("## Preferred Model Details")
    lines.append("")
    preferred = bundle_payload["models"][bundle_payload["preferred_model"]]
    lines.append("- Name: `{0}`".format(preferred["name"]))
    lines.append("- Type: `{0}`".format(preferred["model_type"]))
    lines.append("- Hyperparameters: `{0}`".format(json.dumps(preferred["hyperparameters"], ensure_ascii=False)))
    lines.append("")
    lines.append("## Preferred Model Top Features")
    lines.append("")
    lines.append("| Feature | Weight / Usage |")
    lines.append("|---|---:|")
    for item in preferred["top_features"]:
        lines.append("| {0} | {1} |".format(item["feature"], item["weight"]))
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- `ridge` is the fixed-alpha linear baseline.")
    lines.append("- `ridge_cv` selects alpha with leave-one-source-out style validation and is the default preferred model.")
    lines.append("- `random_forest` is a lightweight pure-Python non-linear comparison model for interaction effects.")
    lines.append("- Use model outputs to rank candidate configs before real-world validation, not to write directly into live configs.")

    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
        handle.write("\n")


def build_model_bundle(args, training_rows, feature_names):
    alpha_candidates = parse_alphas(args.ridge_cv_alphas)
    ridge_payload = build_ridge_payload(training_rows, feature_names, args.target_key, args.ridge_alpha, "ridge")
    ridge_cv_payload = build_ridge_cv_payload(training_rows, feature_names, args.target_key, alpha_candidates)
    random_forest_payload = fit_random_forest_payload(
        training_rows,
        feature_names,
        args.target_key,
        args.rf_tree_count,
        args.rf_max_depth,
        args.rf_min_leaf_size,
        args.rf_feature_fraction,
        args.rf_row_fraction,
        args.rf_random_seed,
    )

    bundle = OrderedDict()
    bundle["model_version"] = MODEL_VERSION
    bundle["created_at"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    bundle["dataset_path"] = args.dataset.replace("\\", "/")
    bundle["target_key"] = args.target_key
    bundle["row_count"] = len(training_rows)
    bundle["preferred_model"] = args.preferred_model
    bundle["feature_names"] = feature_names
    bundle["models"] = OrderedDict([
        ("ridge", ridge_payload),
        ("ridge_cv", ridge_cv_payload),
        ("random_forest", random_forest_payload),
    ])
    bundle["selected_model"] = bundle["models"][args.preferred_model]
    return bundle


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

    bundle = build_model_bundle(args, training_rows, feature_names)

    bundle_path = os.path.join(args.output_dir, "baseline_model_bundle.json")
    model_path = os.path.join(args.output_dir, "baseline_model.json")
    report_path = os.path.join(args.output_dir, "baseline_model_report.md")

    write_json(bundle_path, bundle)
    write_json(model_path, bundle["selected_model"])
    write_report(report_path, args.dataset, bundle)

    preferred = bundle["selected_model"]
    print("Trained {0} comparable models on {1} rows with {2} features.".format(
        len(bundle["models"]),
        bundle["row_count"],
        len(feature_names),
    ))
    print("Preferred model: {0}".format(bundle["preferred_model"]))
    print("Model:   {0}".format(model_path))
    print("Bundle:  {0}".format(bundle_path))
    print("Report:  {0}".format(report_path))


if __name__ == "__main__":
    main()
