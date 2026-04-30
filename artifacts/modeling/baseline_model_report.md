# FanControl Baseline Model Comparison Report

- Model version: `fancontrol.baseline-model.v2`
- Dataset: `./artifacts/modeling/training_rows.jsonl`
- Target: `target_score`
- Training rows: `143`
- Preferred model: `ridge_cv`

## Model Comparison

| Model | Train MAE | Train RMSE | Train R2 | CV folds | CV MAE | CV RMSE | CV R2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| ridge | 1.963243 | 3.1102 | 0.907598 | 11 | 4.00569 | 6.808604 | 0.557187 |
| ridge_cv | 2.054193 | 3.377255 | 0.891049 | 11 | 3.403217 | 6.105942 | 0.643869 |
| random_forest | 0.948275 | 2.095602 | 0.958051 | 11 | 2.761453 | 6.453033 | 0.60223 |

## Preferred Model Details

- Name: `ridge_cv`
- Type: `ridge`
- Hyperparameters: `{"alpha": 10.0, "alpha_candidates": [0.01, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0]}`

## Preferred Model Top Features

| Feature | Weight / Usage |
|---|---:|
| vrm_mos_temp_c | -1.931761 |
| total_tracked_fan_rpm | -1.486097 |
| total_case_fan_rpm | -1.47633 |
| system_fan4_rpm | -1.397895 |
| cpu_package_c | -1.341957 |
| cpu_soft_margin_c | 1.341957 |
| cpu_fan_rpm | -1.335393 |
| system_temp_c | -1.267035 |
| system_fan2_rpm | -1.266949 |
| source_sample_count | 0.831883 |
| rolling_gpu_temp_avg_3 | -0.774458 |
| gpu_3d_util_pct | 0.697656 |

## Notes

- `ridge` is the fixed-alpha linear baseline.
- `ridge_cv` selects alpha with leave-one-source-out style validation and is the default preferred model.
- `random_forest` is a lightweight pure-Python non-linear comparison model for interaction effects.
- Use model outputs to rank candidate configs before real-world validation, not to write directly into live configs.
