# FanControl Candidate Search Report

- Report version: `fancontrol.candidate-search.v1`
- Model: `./artifacts/modeling/baseline_model.json`
- Model name: `ridge_cv`
- Model type: `ridge`
- Dataset: `./artifacts/modeling/training_rows.jsonl`
- Seed config: `Game_vNext_stage1_low-rpm.json`
- Baseline config: `Game.json`
- Evaluated candidates: `6561`
- Invalid candidates skipped: `0`

## Search Dimensions

| Parameter | Seed | Candidate values |
|---|---:|---|
| Auto.IdleTemperature | 40 | 38, 40, 42 |
| Auto.MinFanSpeed | 25 | 20, 25, 30 |
| Auto.LoadTemperature | 78 | 76, 78, 80 |
| Auto 1.IdleTemperature | 48 | 46, 48, 50 |
| Auto 1.MinFanSpeed | 15 | 10, 15, 20 |
| Auto 2.IdleTemperature | 62 | 60, 62, 64 |
| Auto 2.MinFanSpeed | 0 | 0, 5, 10 |
| Auto 2.LoadTemperature | 74 | 72, 74, 76 |

## Reference Scores

| Config | Avg predicted score |
|---|---:|
| Seed | 80.280087 |
| Baseline | 77.793998 |

## Top Distinct Candidates

| Rank | File | Avg score | Delta vs seed | Delta vs baseline | Parameters |
|---|---|---:|---:|---:|---|
| 1 | candidate_rank01_score80.984.json | 80.984478 | 0.704391 | 3.19048 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=80, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 2 | candidate_rank02_score80.950.json | 80.949949 | 0.669862 | 3.155951 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=80, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=62, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 3 | candidate_rank03_score80.933.json | 80.932684 | 0.652597 | 3.138686 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=78, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 4 | candidate_rank04_score80.915.json | 80.91542 | 0.635333 | 3.121422 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=80, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=74 |
| 5 | candidate_rank05_score80.902.json | 80.901608 | 0.621521 | 3.10761 | Auto.IdleTemperature=40, Auto.MinFanSpeed=20, Auto.LoadTemperature=80, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 6 | candidate_rank06_score80.898.json | 80.898155 | 0.618068 | 3.104157 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=78, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=62, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 7 | candidate_rank07_score80.881.json | 80.880891 | 0.600804 | 3.086893 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=78, Auto 1.IdleTemperature=48, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 8 | candidate_rank08_score80.867.json | 80.867079 | 0.586992 | 3.073081 | Auto.IdleTemperature=40, Auto.MinFanSpeed=20, Auto.LoadTemperature=80, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=62, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 9 | candidate_rank09_score80.864.json | 80.863626 | 0.583539 | 3.069628 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=78, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=74 |
| 10 | candidate_rank10_score80.850.json | 80.849815 | 0.569728 | 3.055817 | Auto.IdleTemperature=40, Auto.MinFanSpeed=20, Auto.LoadTemperature=78, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 11 | candidate_rank11_score80.846.json | 80.846362 | 0.566275 | 3.052364 | Auto.IdleTemperature=42, Auto.MinFanSpeed=20, Auto.LoadTemperature=78, Auto 1.IdleTemperature=48, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=62, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=72 |
| 12 | candidate_rank12_score80.833.json | 80.83255 | 0.552463 | 3.038552 | Auto.IdleTemperature=40, Auto.MinFanSpeed=20, Auto.LoadTemperature=80, Auto 1.IdleTemperature=50, Auto 1.MinFanSpeed=10, Auto 2.IdleTemperature=64, Auto 2.MinFanSpeed=0, Auto 2.LoadTemperature=74 |

## Notes

- This search only changes a constrained set of curve fields around the accepted seed config.
- The ranked output keeps one representative candidate per rounded score bucket to avoid repeated ties crowding out review bandwidth.
- Candidate configs are written to `artifacts/modeling/candidates/` style outputs for review and manual validation.
- Scores come from the baseline model and historical replay, so live thermal verification is still required.
