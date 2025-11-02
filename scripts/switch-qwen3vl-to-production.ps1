# Switch Qwen3-VL Service to Production Network
# Disables internet access and enables offline mode for security

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Switch Qwen3-VL to Production Mode" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if model is downloaded
$OFFLINE_MARKER = ".\models\.qwen3vl_downloaded"
if (-not (Test-Path $OFFLINE_MARKER)) {
    Write-Host "ERROR: Model not fully downloaded!" -ForegroundColor Red
    Write-Host "Run download script first: .\scripts\download-qwen3vl.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "1. Update docker-compose.yml to use vllm-internal network" -ForegroundColor White
Write-Host "2. Enable offline mode (HF_HUB_OFFLINE=1)" -ForegroundColor White
Write-Host "3. Restart the Qwen3-VL service with network isolation" -ForegroundColor White
Write-Host ""
Write-Host "WARNING: After this, the service will NOT be able to download models." -ForegroundColor Red
Write-Host ""

$confirmation = Read-Host "Continue? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Updating docker-compose.yml..." -ForegroundColor Yellow

# Read the docker-compose file
$composeFile = "docker-compose.yml"
$content = Get-Content $composeFile -Raw

# Replace network settings for vllm-qwen3vl
$content = $content -replace "(?ms)(vllm-qwen3vl:.*?networks:.*?)- default\s+# TEMP: Allow internet to download model\s+#\s+- vllm-internal\s+# NO internet access", '$1- vllm-internal  # NO internet access (internal=true)'

# Enable offline mode
$content = $content -replace "(?ms)(vllm-qwen3vl:.*?environment:.*?)#\s+- HF_HUB_OFFLINE=1\s+# TEMP DISABLED - allow download\s+#\s+- TRANSFORMERS_OFFLINE=1\s+# TEMP DISABLED - allow download", '$1- HF_HUB_OFFLINE=1$2- TRANSFORMERS_OFFLINE=1'

# Save the file
$content | Set-Content $composeFile -NoNewline

Write-Host "docker-compose.yml updated!" -ForegroundColor Green
Write-Host ""

# Restart the service
Write-Host "Restarting vllm-qwen3vl service..." -ForegroundColor Yellow
docker-compose --profile qwen3vl restart vllm-qwen3vl

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Production mode enabled!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The service is now running in isolated mode:" -ForegroundColor Cyan
    Write-Host "- No internet access (secure)" -ForegroundColor White
    Write-Host "- Offline mode enabled" -ForegroundColor White
    Write-Host "- Model loaded from local cache" -ForegroundColor White
    Write-Host ""
    Write-Host "Check status:" -ForegroundColor Yellow
    Write-Host "  docker logs -f vllm-qwen3vl" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Test the service:" -ForegroundColor Yellow
    Write-Host "  .\scripts\test-qwen3vl.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Failed to restart service!" -ForegroundColor Red
    Write-Host "Check logs: docker logs vllm-qwen3vl" -ForegroundColor Yellow
    exit 1
}

