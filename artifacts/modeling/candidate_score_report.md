# FanControl Candidate Config Score Report

- Report version: `fancontrol.candidate-score.v1`
- Candidate config: `Game_vNext_stage1_low-rpm.json`
- Model: `./artifacts/modeling/baseline_model.json`
- Model name: `ridge_cv`
- Model type: `ridge`
- Dataset: `./artifacts/modeling/training_rows.jsonl`
- Baseline config: `Game.json`

## Overall

| Metric | Candidate | Baseline | Delta |
|---|---:|---:|---:|
| Avg predicted score | 80.280087 | 77.793998 | 2.486089 |
| Avg CPU package (from dataset rows) | 65.601399 | 65.601399 | - |
| Avg GPU temp (from dataset rows) | 50.293706 | 50.293706 | - |
| Avg total tracked RPM (from dataset rows) | 2382.664336 | 2382.664336 | - |

## By Workload Class

| Workload | Rows | Candidate score | Baseline score | Delta |
|---|---:|---:|---:|---:|
| idle | 18 | 92.508517 | 90.022429 | 2.486088 |
| cpu-biased | 16 | 80.094273 | 77.608185 | 2.486088 |
| unknown | 18 | 80.084122 | 77.598034 | 2.486088 |
| gpu-biased | 77 | 78.099319 | 75.613231 | 2.486088 |
| mixed | 14 | 77.016354 | 74.530266 | 2.486088 |

## Notes

- This score is a model estimate, not a live thermal validation.
- The candidate config is replayed across historical hardware states from the dataset.
- Use this as a ranking tool before real-world verification.
