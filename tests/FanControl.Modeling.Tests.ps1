Describe 'FanControl modeling scripts' {
    It 'builds a training dataset from experiment samples' {
        $outputDir = Join-Path $env:TEMP ("fancontrol-modeling-build-" + [guid]::NewGuid().ToString("N"))
        $repoRoot = Split-Path -Parent $PSScriptRoot

        try {
            $buildScript = Join-Path $repoRoot 'scripts\modeling\build_training_dataset.py'
            $inputRoot = Join-Path $repoRoot 'docs\experiments\data'
            $configRoot = Join-Path $repoRoot 'configs'

            & python $buildScript --input-root $inputRoot --config-root $configRoot --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $jsonlPath = Join-Path $outputDir 'training_rows.jsonl'
            $csvPath = Join-Path $outputDir 'training_rows.csv'
            $summaryPath = Join-Path $outputDir 'training_dataset_summary.json'

            (Test-Path $jsonlPath) | Should -BeTrue
            (Test-Path $csvPath) | Should -BeTrue
            (Test-Path $summaryPath) | Should -BeTrue

            $firstRow = Get-Content -Path $jsonlPath -First 1 | ConvertFrom-Json
            $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json

            $firstRow.schema_version | Should -Be 'fancontrol.training-row.v1'
            $firstRow.target_score | Should -Not -BeNullOrEmpty
            $firstRow.cfg_auto2_uses_gpu_temp | Should -Not -BeNullOrEmpty
            $firstRow.rolling_cpu_package_avg_3 | Should -Not -BeNullOrEmpty
            $firstRow.sample_progress_pct | Should -Not -BeNullOrEmpty
            $summary.row_count | Should -BeGreaterThan 0
            $summary.source_file_count | Should -BeGreaterThan 0
        } finally {
            Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'trains a baseline model from the built dataset' {
        $outputDir = Join-Path $env:TEMP ("fancontrol-modeling-train-" + [guid]::NewGuid().ToString("N"))
        $repoRoot = Split-Path -Parent $PSScriptRoot

        try {
            $buildScript = Join-Path $repoRoot 'scripts\modeling\build_training_dataset.py'
            $trainScript = Join-Path $repoRoot 'scripts\modeling\train_baseline_model.py'
            $inputRoot = Join-Path $repoRoot 'docs\experiments\data'
            $configRoot = Join-Path $repoRoot 'configs'

            & python $buildScript --input-root $inputRoot --config-root $configRoot --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $datasetPath = Join-Path $outputDir 'training_rows.jsonl'
            & python $trainScript --dataset $datasetPath --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $modelPath = Join-Path $outputDir 'baseline_model.json'
            $bundlePath = Join-Path $outputDir 'baseline_model_bundle.json'
            $reportPath = Join-Path $outputDir 'baseline_model_report.md'
            (Test-Path $modelPath) | Should -BeTrue
            (Test-Path $bundlePath) | Should -BeTrue
            (Test-Path $reportPath) | Should -BeTrue

            $model = Get-Content -Path $modelPath -Raw | ConvertFrom-Json
            $bundle = Get-Content -Path $bundlePath -Raw | ConvertFrom-Json
            $bundle.model_version | Should -Be 'fancontrol.baseline-model.v2'
            $bundle.preferred_model | Should -Be 'ridge_cv'
            $bundle.models.ridge_cv | Should -Not -BeNullOrEmpty
            $bundle.models.random_forest | Should -Not -BeNullOrEmpty
            $model.model_type | Should -Be 'ridge'
            @($model.feature_names).Count | Should -BeGreaterThan 5
            $model.metrics.training.row_count | Should -BeGreaterThan 0
            $model.metrics.leave_one_source_out.fold_count | Should -BeGreaterThan 0
        } finally {
            Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'scores a candidate config with the trained baseline model' {
        $outputDir = Join-Path $env:TEMP ("fancontrol-modeling-score-" + [guid]::NewGuid().ToString("N"))
        $repoRoot = Split-Path -Parent $PSScriptRoot

        try {
            $buildScript = Join-Path $repoRoot 'scripts\modeling\build_training_dataset.py'
            $trainScript = Join-Path $repoRoot 'scripts\modeling\train_baseline_model.py'
            $scoreScript = Join-Path $repoRoot 'scripts\modeling\score_candidate_config.py'
            $inputRoot = Join-Path $repoRoot 'docs\experiments\data'
            $configRoot = Join-Path $repoRoot 'configs'
            $candidateConfig = Join-Path $repoRoot 'configs\Game_vNext_stage1_low-rpm.json'
            $baselineConfig = Join-Path $repoRoot 'configs\Game.json'

            & python $buildScript --input-root $inputRoot --config-root $configRoot --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $datasetPath = Join-Path $outputDir 'training_rows.jsonl'
            & python $trainScript --dataset $datasetPath --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $modelPath = Join-Path $outputDir 'baseline_model.json'
            & python $scoreScript --dataset $datasetPath --model $modelPath --candidate-config $candidateConfig --baseline-config $baselineConfig --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $summaryPath = Join-Path $outputDir 'candidate_score_summary.json'
            $reportPath = Join-Path $outputDir 'candidate_score_report.md'
            (Test-Path $summaryPath) | Should -BeTrue
            (Test-Path $reportPath) | Should -BeTrue

            $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json
            $summary.report_version | Should -Be 'fancontrol.candidate-score.v1'
            $summary.model_name | Should -Be 'ridge_cv'
            $summary.model_type | Should -Be 'ridge'
            $summary.candidate_summary.row_count | Should -BeGreaterThan 0
            @($summary.candidate_by_workload_class).Count | Should -BeGreaterThan 0
            $summary.baseline_summary.avg_predicted_score | Should -Not -BeNullOrEmpty
        } finally {
            Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'searches constrained candidate configs around the seed config' {
        $outputDir = Join-Path $env:TEMP ("fancontrol-modeling-search-" + [guid]::NewGuid().ToString("N"))
        $repoRoot = Split-Path -Parent $PSScriptRoot

        try {
            $buildScript = Join-Path $repoRoot 'scripts\modeling\build_training_dataset.py'
            $trainScript = Join-Path $repoRoot 'scripts\modeling\train_baseline_model.py'
            $searchScript = Join-Path $repoRoot 'scripts\modeling\search_candidate_configs.py'
            $inputRoot = Join-Path $repoRoot 'docs\experiments\data'
            $configRoot = Join-Path $repoRoot 'configs'
            $seedConfig = Join-Path $repoRoot 'configs\Game_vNext_stage1_low-rpm.json'
            $baselineConfig = Join-Path $repoRoot 'configs\Game.json'

            & python $buildScript --input-root $inputRoot --config-root $configRoot --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $datasetPath = Join-Path $outputDir 'training_rows.jsonl'
            & python $trainScript --dataset $datasetPath --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $modelPath = Join-Path $outputDir 'baseline_model.json'
            & python $searchScript --dataset $datasetPath --model $modelPath --seed-config $seedConfig --baseline-config $baselineConfig --output-dir $outputDir --top-k 5
            $LASTEXITCODE | Should -Be 0

            $summaryPath = Join-Path $outputDir 'candidate_search_summary.json'
            $reportPath = Join-Path $outputDir 'candidate_search_report.md'
            $candidateDir = Join-Path $outputDir 'candidates'

            (Test-Path $summaryPath) | Should -BeTrue
            (Test-Path $reportPath) | Should -BeTrue
            (Test-Path $candidateDir) | Should -BeTrue

            $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json
            $summary.report_version | Should -Be 'fancontrol.candidate-search.v1'
            $summary.model_name | Should -Be 'ridge_cv'
            $summary.model_type | Should -Be 'ridge'
            $summary.evaluated_candidate_count | Should -BeGreaterThan 0
            $summary.top_candidates.Count | Should -BeGreaterThan 0
            $summary.selected_candidate_count | Should -Be $summary.top_candidates.Count
            $summary.seed_summary.avg_predicted_score | Should -Not -BeNullOrEmpty

            $candidateFiles = @(Get-ChildItem -Path $candidateDir -Filter '*.json')
            $candidateFiles.Count | Should -Be $summary.top_candidates.Count
            ($candidateFiles.Name | Select-Object -Unique).Count | Should -Be $candidateFiles.Count

            $roundedScores = @($summary.top_candidates | ForEach-Object { [math]::Round([double]$_.avg_predicted_score, [int]$summary.score_dedup_decimals) })
            ($roundedScores | Select-Object -Unique).Count | Should -Be $roundedScores.Count
        } finally {
            Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'prepares a candidate validation pack from search results' {
        $outputDir = Join-Path $env:TEMP ("fancontrol-modeling-validate-pack-" + [guid]::NewGuid().ToString("N"))
        $repoRoot = Split-Path -Parent $PSScriptRoot

        try {
            $buildScript = Join-Path $repoRoot 'scripts\modeling\build_training_dataset.py'
            $trainScript = Join-Path $repoRoot 'scripts\modeling\train_baseline_model.py'
            $searchScript = Join-Path $repoRoot 'scripts\modeling\search_candidate_configs.py'
            $prepareScript = Join-Path $repoRoot 'scripts\modeling\prepare_candidate_validation.py'
            $inputRoot = Join-Path $repoRoot 'docs\experiments\data'
            $configRoot = Join-Path $repoRoot 'configs'
            $seedConfig = Join-Path $repoRoot 'configs\Game_vNext_stage1_low-rpm.json'
            $baselineConfig = Join-Path $repoRoot 'configs\Game.json'

            & python $buildScript --input-root $inputRoot --config-root $configRoot --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $datasetPath = Join-Path $outputDir 'training_rows.jsonl'
            & python $trainScript --dataset $datasetPath --output-dir $outputDir
            $LASTEXITCODE | Should -Be 0

            $modelPath = Join-Path $outputDir 'baseline_model.json'
            & python $searchScript --dataset $datasetPath --model $modelPath --seed-config $seedConfig --baseline-config $baselineConfig --output-dir $outputDir --top-k 5
            $LASTEXITCODE | Should -Be 0

            $searchSummaryPath = Join-Path $outputDir 'candidate_search_summary.json'
            & python $prepareScript --search-summary $searchSummaryPath --output-dir $outputDir --top-n 3 --validation-date '2026-04-30'
            $LASTEXITCODE | Should -Be 0

            $manifestPath = Join-Path $outputDir 'candidate_validation_manifest.json'
            $checklistPath = Join-Path $outputDir 'candidate_validation_checklist.md'
            (Test-Path $manifestPath) | Should -BeTrue
            (Test-Path $checklistPath) | Should -BeTrue

            $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
            $manifest.report_version | Should -Be 'fancontrol.candidate-validation-pack.v1'
            $manifest.candidate_count | Should -Be 3
            $manifest.candidates.Count | Should -Be 3
            $manifest.scenarios.Count | Should -BeGreaterThan 0
            $manifest.source_search_summary | Should -Match 'candidate_search_summary.json'

            $checklist = Get-Content -Path $checklistPath -Raw
            $checklist | Should -Match 'Candidate Validation Pack'
            $checklist | Should -Match 'monitor_simple\.ps1 -Mode Sample'
        } finally {
            Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
