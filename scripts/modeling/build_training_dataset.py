#!/usr/bin/env python
import argparse
import csv
import json
import math
import os
from collections import Counter, OrderedDict
from datetime import datetime


SCHEMA_VERSION = "fancontrol.training-row.v1"

RAW_SAMPLE_MAP = OrderedDict([
    ("CpuPackage", "cpu_package_c"),
    ("CoreAverage", "core_average_c"),
    ("MinDistanceToTjMax", "min_distance_to_tjmax_c"),
    ("CpuTotalLoad", "cpu_total_load_pct"),
    ("CpuCoreMaxLoad", "cpu_core_max_load_pct"),
    ("CpuClockAverageMHz", "cpu_clock_avg_mhz"),
    ("PCoreClockAverageMHz", "pcore_clock_avg_mhz"),
    ("ECoreClockAverageMHz", "ecore_clock_avg_mhz"),
    ("CpuPackagePowerW", "cpu_package_power_w"),
    ("SystemTemp", "system_temp_c"),
    ("VrmMosTemp", "vrm_mos_temp_c"),
    ("PchTemp", "pch_temp_c"),
    ("GpuTemp", "gpu_temp_c"),
    ("Gpu3DUtil", "gpu_3d_util_pct"),
    ("CpuFanRpm", "cpu_fan_rpm"),
    ("SystemFan2Rpm", "system_fan2_rpm"),
    ("SystemFan3Rpm", "system_fan3_rpm"),
    ("SystemFan4Rpm", "system_fan4_rpm"),
    ("GpuFan1Rpm", "gpu_fan1_rpm"),
    ("GpuFan2Rpm", "gpu_fan2_rpm"),
    ("TotalCaseFanRpm", "total_case_fan_rpm"),
    ("TotalTrackedFanRpm", "total_tracked_fan_rpm"),
    ("TotalFanRpm", "total_tracked_fan_rpm"),
])

CURVE_NAME_TO_PREFIX = OrderedDict([
    ("Auto", "auto"),
    ("Auto 1", "auto1"),
    ("Auto 2", "auto2"),
])

CONTROL_NICK_TO_PREFIX = OrderedDict([
    ("CPU Fan", "cpu_fan"),
    ("System Fan #2", "system_fan2"),
    ("System Fan #3", "system_fan3"),
    ("System Fan #4", "system_fan4"),
])


def parse_args():
    parser = argparse.ArgumentParser(description="Build a flattened training dataset from FanControl experiment samples.")
    parser.add_argument("--input-root", default=os.path.join("docs", "experiments", "data"))
    parser.add_argument("--config-root", default="configs")
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


def parse_timestamp(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def iter_json_files(root):
    for current_root, _, files in os.walk(root):
        for name in sorted(files):
            if name.lower().endswith(".json"):
                yield os.path.join(current_root, name)


def safe_float(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    if isinstance(value, (int, float)):
        if math.isfinite(float(value)):
            return float(value)
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


def clamp(value, lower, upper):
    return max(lower, min(upper, value))


def safe_div(numerator, denominator):
    numerator = safe_float(numerator)
    denominator = safe_float(denominator)
    if numerator is None or denominator is None or abs(denominator) < 1e-9:
        return None
    return numerator / denominator


def infer_workload_class(name):
    text = (name or "").lower()
    if "idle" in text:
        return "idle"
    if "mixed" in text or ("cpu" in text and "gpu" in text):
        return "mixed"
    if "gpu" in text or "webgl" in text or "graphics" in text or "shader" in text:
        return "gpu-biased"
    if "cpu" in text or "powershell" in text:
        return "cpu-biased"
    return "unknown"


def normalize_source_kind(payload):
    if isinstance(payload, list):
        return "array", payload
    if isinstance(payload, dict):
        if isinstance(payload.get("Samples"), list):
            return "wrapped-samples", payload.get("Samples")
        return "single-object", [payload]
    raise ValueError("Unsupported JSON payload type: {0}".format(type(payload).__name__))


def extract_config_features_from_payload(payload, config_profile_name):
    features = {}
    custom = payload.get("__CUSTOM__", {})
    features["config_profile_name"] = config_profile_name
    features["config_custom_status"] = custom.get("status")
    features["config_base_config"] = custom.get("base_config")

    fan_control = payload.get("FanControl", {})
    curves = fan_control.get("FanCurves", []) or []
    controls = fan_control.get("Controls", []) or []

    curves_by_name = {}
    for curve in curves:
        name = curve.get("Name")
        if name:
            curves_by_name[name] = curve

    controls_by_nick = {}
    for control in controls:
        nick = control.get("NickName")
        if nick:
            controls_by_nick[nick] = control

    for curve_name, prefix in CURVE_NAME_TO_PREFIX.items():
        curve = curves_by_name.get(curve_name, {})
        temp_source = None
        selected_temp = curve.get("SelectedTempSource")
        if isinstance(selected_temp, dict):
            temp_source = selected_temp.get("Identifier")

        features["cfg_{0}_idle_temp_c".format(prefix)] = safe_float(curve.get("IdleTemperature"))
        features["cfg_{0}_min_speed_pct".format(prefix)] = safe_float(curve.get("MinFanSpeed"))
        features["cfg_{0}_max_speed_pct".format(prefix)] = safe_float(curve.get("MaxFanSpeed"))
        features["cfg_{0}_load_temp_c".format(prefix)] = safe_float(curve.get("LoadTemperature"))
        features["cfg_{0}_temp_source".format(prefix)] = temp_source
        features["cfg_{0}_uses_gpu_temp".format(prefix)] = 1.0 if temp_source and ("gpu" in temp_source.lower() or "nvapi" in temp_source.lower()) else 0.0

    for nick_name, prefix in CONTROL_NICK_TO_PREFIX.items():
        control = controls_by_nick.get(nick_name, {})
        features["cfg_{0}_start_pct".format(prefix)] = safe_float(control.get("SelectedStart"))
        features["cfg_{0}_stop_pct".format(prefix)] = safe_float(control.get("SelectedStop"))
        features["cfg_{0}_minimum_pct".format(prefix)] = safe_float(control.get("MinimumPercent"))
        features["cfg_{0}_enabled".format(prefix)] = 1.0 if control.get("Enable") else 0.0

    return features


def load_config_features_from_path(config_path):
    if not config_path or not os.path.isfile(config_path):
        return {}
    payload = read_json(config_path)
    return extract_config_features_from_payload(payload, os.path.basename(config_path))


def load_config_features(config_root, config_name):
    if not config_name:
        return {}

    config_path = os.path.join(config_root, config_name)
    if not os.path.isfile(config_path):
        return {}

    return load_config_features_from_path(config_path)


def derive_safety_label(cpu_package, gpu_temp, min_distance):
    cpu_package = safe_float(cpu_package)
    gpu_temp = safe_float(gpu_temp)
    min_distance = safe_float(min_distance)

    if ((cpu_package is not None and cpu_package >= 90.0) or
            (gpu_temp is not None and gpu_temp >= 83.0) or
            (min_distance is not None and min_distance <= 10.0)):
        return "unsafe"

    if ((cpu_package is not None and cpu_package >= 85.0) or
            (gpu_temp is not None and gpu_temp >= 78.0) or
            (min_distance is not None and min_distance <= 15.0)):
        return "warn"

    return "safe"


def derive_thermal_score(cpu_package, gpu_temp, min_distance):
    score = 100.0

    cpu_package = safe_float(cpu_package)
    gpu_temp = safe_float(gpu_temp)
    min_distance = safe_float(min_distance)

    if cpu_package is not None:
        score -= max(cpu_package - 75.0, 0.0) * 1.8
    if gpu_temp is not None:
        score -= max(gpu_temp - 72.0, 0.0) * 1.2
    if min_distance is not None:
        score -= max(20.0 - min_distance, 0.0) * 2.5

    return round(clamp(score, 0.0, 100.0), 3)


def rolling_window(rows, current_index, key, window_size):
    start_index = max(0, current_index - window_size + 1)
    values = []
    for index in range(start_index, current_index + 1):
        value = safe_float(rows[index].get(key))
        if value is not None:
            values.append(value)
    return values


def add_temporal_features(rows):
    source_counts = Counter(row["source_file"] for row in rows)
    grouped = OrderedDict()
    for row in rows:
        grouped.setdefault(row["source_file"], []).append(row)

    for source_file, source_rows in grouped.items():
        total_rows = source_counts[source_file]
        first_timestamp = parse_timestamp(source_rows[0].get("sample_timestamp"))

        for index, row in enumerate(source_rows):
            row["source_sample_count"] = total_rows
            row["sample_progress_pct"] = 0.0 if total_rows <= 1 else round(float(index) / float(total_rows - 1), 6)

            current_timestamp = parse_timestamp(row.get("sample_timestamp"))
            if first_timestamp and current_timestamp:
                row["elapsed_seconds"] = int((current_timestamp - first_timestamp).total_seconds())
            else:
                row["elapsed_seconds"] = None

            if index == 0:
                row["delta_seconds"] = None
                row["cpu_package_delta_1"] = None
                row["gpu_temp_delta_1"] = None
                row["total_tracked_fan_rpm_delta_1"] = None
                row["cpu_total_load_delta_1"] = None
            else:
                previous_row = source_rows[index - 1]
                previous_timestamp = parse_timestamp(previous_row.get("sample_timestamp"))
                if previous_timestamp and current_timestamp:
                    row["delta_seconds"] = int((current_timestamp - previous_timestamp).total_seconds())
                else:
                    row["delta_seconds"] = None

                for source_key, target_key in [
                    ("cpu_package_c", "cpu_package_delta_1"),
                    ("gpu_temp_c", "gpu_temp_delta_1"),
                    ("total_tracked_fan_rpm", "total_tracked_fan_rpm_delta_1"),
                    ("cpu_total_load_pct", "cpu_total_load_delta_1"),
                ]:
                    current_value = safe_float(row.get(source_key))
                    previous_value = safe_float(previous_row.get(source_key))
                    if current_value is None or previous_value is None:
                        row[target_key] = None
                    else:
                        row[target_key] = round(current_value - previous_value, 6)

            for source_key, avg_key, max_key in [
                ("cpu_package_c", "rolling_cpu_package_avg_3", "rolling_cpu_package_max_3"),
                ("gpu_temp_c", "rolling_gpu_temp_avg_3", "rolling_gpu_temp_max_3"),
                ("total_tracked_fan_rpm", "rolling_total_tracked_fan_rpm_avg_3", "rolling_total_tracked_fan_rpm_max_3"),
                ("cpu_total_load_pct", "rolling_cpu_total_load_avg_3", "rolling_cpu_total_load_max_3"),
            ]:
                window_values = rolling_window(source_rows, index, source_key, 3)
                if window_values:
                    row[avg_key] = round(sum(window_values) / float(len(window_values)), 6)
                    row[max_key] = round(max(window_values), 6)
                else:
                    row[avg_key] = None
                    row[max_key] = None


def build_rows(input_root, config_root):
    rows = []
    config_cache = {}

    for path in iter_json_files(input_root):
        payload = read_json(path)
        source_kind, samples = normalize_source_kind(payload)
        relative_path = os.path.relpath(path, input_root).replace("\\", "/")
        file_stem = os.path.splitext(os.path.basename(path))[0]

        for index, sample in enumerate(samples):
            if not isinstance(sample, dict):
                continue

            scenario_name = sample.get("Scenario") or file_stem
            row = OrderedDict()
            row["schema_version"] = SCHEMA_VERSION
            row["source_file"] = relative_path
            row["source_kind"] = source_kind
            row["sample_index"] = index
            row["scenario_name"] = scenario_name
            row["workload_class"] = infer_workload_class(scenario_name + " " + file_stem)
            row["sample_timestamp"] = sample.get("Timestamp")
            row["desired_config"] = sample.get("DesiredConfig")
            row["effective_config"] = sample.get("EffectiveConfig")
            row["override_mode"] = sample.get("OverrideMode")

            config_profile_name = sample.get("EffectiveConfig") or sample.get("DesiredConfig")
            if config_profile_name not in config_cache:
                config_cache[config_profile_name] = load_config_features(config_root, config_profile_name)
            row.update(config_cache.get(config_profile_name, {}))
            if "config_profile_name" not in row:
                row["config_profile_name"] = config_profile_name
                row["config_custom_status"] = None
                row["config_base_config"] = None

            for source_key, target_key in RAW_SAMPLE_MAP.items():
                row[target_key] = safe_float(sample.get(source_key))

            if row.get("total_case_fan_rpm") is None:
                row["total_case_fan_rpm"] = sum(
                    value for value in [
                        row.get("system_fan2_rpm"),
                        row.get("system_fan3_rpm"),
                        row.get("system_fan4_rpm"),
                    ] if value is not None
                ) or None

            if row.get("total_tracked_fan_rpm") is None:
                tracked_sum = sum(
                    value for value in [
                        row.get("cpu_fan_rpm"),
                        row.get("system_fan2_rpm"),
                        row.get("system_fan3_rpm"),
                        row.get("system_fan4_rpm"),
                    ] if value is not None
                )
                row["total_tracked_fan_rpm"] = tracked_sum or None

            row["cpu_soft_margin_c"] = None if row.get("cpu_package_c") is None else round(85.0 - row["cpu_package_c"], 3)
            row["gpu_soft_margin_c"] = None if row.get("gpu_temp_c") is None else round(78.0 - row["gpu_temp_c"], 3)
            row["tjmax_soft_margin_c"] = None if row.get("min_distance_to_tjmax_c") is None else round(row["min_distance_to_tjmax_c"] - 15.0, 3)
            row["case_fan_share"] = None
            case_fan_share = safe_div(row.get("total_case_fan_rpm"), row.get("total_tracked_fan_rpm"))
            if case_fan_share is not None:
                row["case_fan_share"] = round(case_fan_share, 6)
            row["gpu_assist_share"] = None
            gpu_assist_share = safe_div(
                (row.get("system_fan3_rpm") or 0.0) + (row.get("system_fan4_rpm") or 0.0),
                row.get("total_case_fan_rpm")
            )
            if gpu_assist_share is not None:
                row["gpu_assist_share"] = round(gpu_assist_share, 6)
            row["fan_per_cpu_w"] = None
            fan_per_cpu_w = safe_div(row.get("total_tracked_fan_rpm"), row.get("cpu_package_power_w"))
            if fan_per_cpu_w is not None:
                row["fan_per_cpu_w"] = round(fan_per_cpu_w, 6)

            row["safety_label"] = derive_safety_label(
                row.get("cpu_package_c"),
                row.get("gpu_temp_c"),
                row.get("min_distance_to_tjmax_c")
            )
            row["thermal_score"] = derive_thermal_score(
                row.get("cpu_package_c"),
                row.get("gpu_temp_c"),
                row.get("min_distance_to_tjmax_c")
            )

            rows.append(row)

    add_temporal_features(rows)

    tracked_values = [row["total_tracked_fan_rpm"] for row in rows if row.get("total_tracked_fan_rpm") is not None]
    if tracked_values:
        min_rpm = min(tracked_values)
        max_rpm = max(tracked_values)
    else:
        min_rpm = None
        max_rpm = None

    safety_multiplier = {
        "safe": 1.00,
        "warn": 0.75,
        "unsafe": 0.40,
    }

    for row in rows:
        rpm_value = row.get("total_tracked_fan_rpm")
        if rpm_value is not None and min_rpm is not None and max_rpm is not None and max_rpm > min_rpm:
            normalized = (max_rpm - rpm_value) / (max_rpm - min_rpm)
            row["noise_efficiency_score"] = round(normalized * 100.0, 3)
        elif rpm_value is not None:
            row["noise_efficiency_score"] = 50.0
        else:
            row["noise_efficiency_score"] = None

        if row["noise_efficiency_score"] is not None:
            score = (0.65 * row["thermal_score"] + 0.35 * row["noise_efficiency_score"])
            score *= safety_multiplier.get(row["safety_label"], 1.0)
            row["target_score"] = round(clamp(score, 0.0, 100.0), 3)
        else:
            row["target_score"] = None

    summary = {
        "schema_version": SCHEMA_VERSION,
        "created_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "input_root": input_root.replace("\\", "/"),
        "config_root": config_root.replace("\\", "/"),
        "row_count": len(rows),
        "source_file_count": len(set(row["source_file"] for row in rows)),
        "workload_counts": dict(Counter(row["workload_class"] for row in rows)),
        "safety_label_counts": dict(Counter(row["safety_label"] for row in rows)),
        "config_profile_counts": dict(Counter(row.get("config_profile_name") for row in rows)),
        "total_tracked_rpm_range": {
            "min": min_rpm,
            "max": max_rpm,
        },
    }

    return rows, summary


def write_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False))
            handle.write("\n")


def write_csv(path, rows):
    if not rows:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write("")
        return

    fieldnames = list(rows[0].keys())
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main():
    args = parse_args()
    ensure_dir(args.output_dir)

    rows, summary = build_rows(args.input_root, args.config_root)

    jsonl_path = os.path.join(args.output_dir, "training_rows.jsonl")
    csv_path = os.path.join(args.output_dir, "training_rows.csv")
    summary_path = os.path.join(args.output_dir, "training_dataset_summary.json")

    write_jsonl(jsonl_path, rows)
    write_csv(csv_path, rows)
    write_json(summary_path, summary)

    print("Built {0} training rows from {1} source files.".format(summary["row_count"], summary["source_file_count"]))
    print("JSONL: {0}".format(jsonl_path))
    print("CSV:   {0}".format(csv_path))
    print("Stats: {0}".format(summary_path))


if __name__ == "__main__":
    main()
