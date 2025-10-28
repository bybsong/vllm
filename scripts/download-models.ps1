# PowerShell version of download-models.sh
# For running directly in Windows (outside WSL2)
#
# Phase 1: Download Models (WITH network access)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "vLLM Model Download Script - Phase 1" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script downloads models WITH network access enabled."
Write-Host "After models are downloaded, you can run Phase 2 with network restrictions."
Write-Host ""

# Create models directory if it doesn't exist
$modelsDir = Join-Path $PSScriptRoot "..\models"
if (-not (Test-Path $modelsDir)) {
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
}

# Set environment variables
$env:HF_HOME = $modelsDir
$env:HF_HUB_DISABLE_TELEMETRY = "1"
$env:DO_NOT_TRACK = "1"

Write-Host "Download directory: $modelsDir"
Write-Host ""

# Check if Python is available
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python not found. Please install Python first." -ForegroundColor Red
    exit 1
}

# Check if huggingface-cli is available
if (-not (Get-Command huggingface-cli -ErrorAction SilentlyContinue)) {
    Write-Host "Installing huggingface-hub..."
    pip install -q huggingface-hub
}

# Array of models to download
$models = @(
    "meta-llama/Llama-3.2-3B-Instruct",
    "Qwen/Qwen2.5-1.5B-Instruct",
    "facebook/opt-125m"
)

Write-Host "Models to download:"
foreach ($model in $models) {
    Write-Host "  - $model"
}
Write-Host ""

# Download each model
foreach ($model in $models) {
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "Downloading: $model" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    
    if ($model -match "llama|Llama") {
        Write-Host "NOTE: This model may require HuggingFace authentication." -ForegroundColor Yellow
        Write-Host "If download fails, run: huggingface-cli login"
        Write-Host ""
    }
    
    # Download the model
    huggingface-cli download $model --cache-dir $modelsDir --local-dir-use-symlinks False
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully downloaded: $model" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to download: $model" -ForegroundColor Red
        Write-Host "  You may need to authenticate or check your internet connection"
    }
    Write-Host ""
}

Write-Host "================================================" -ForegroundColor Green
Write-Host "Download Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Downloaded models are stored in: $modelsDir"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Verify models downloaded successfully"
Write-Host "  2. In WSL2: docker-compose up -d (to start the API server)"
Write-Host "  3. Test with: bash scripts/test-api.sh"
Write-Host ""

# Create offline marker file
$markerFile = Join-Path $modelsDir ".models_downloaded"
New-Item -ItemType File -Path $markerFile -Force | Out-Null
Write-Host "✓ Created offline marker: $markerFile" -ForegroundColor Green

