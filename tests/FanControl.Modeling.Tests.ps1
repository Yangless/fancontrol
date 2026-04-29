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
            $reportPath = Join-Path $outputDir 'baseline_model_report.md'
            (Test-Path $modelPath) | Should -BeTrue
            (Test-Path $reportPath) | Should -BeTrue

            $model = Get-Content -Path $modelPath -Raw | ConvertFrom-Json
            $model.model_version | Should -Be 'fancontrol.baseline-model.v1'
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
            $summary.candidate_summary.row_count | Should -BeGreaterThan 0
            @($summary.candidate_by_workload_class).Count | Should -BeGreaterThan 0
            $summary.baseline_summary.avg_predicted_score | Should -Not -BeNullOrEmpty
        } finally {
            Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
