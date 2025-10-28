#!/usr/bin/env pwsh
# Complete setup script for Nanonets-OCR2-3B with vLLM (PowerShell)
# Follows vLLM enterprise deployment best practices

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Nanonets-OCR2-3B Setup" -ForegroundColor Cyan
Write-Host "vLLM Enterprise Architecture" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check docker-compose
try {
    docker-compose --version | Out-Null
} catch {
    Write-Host "Error: docker-compose not found" -ForegroundColor Red
    exit 1
}

Write-Host "Step 1/4: Creating directories" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path models | Out-Null
New-Item -ItemType Directory -Force -Path nginx-config | Out-Null
Write-Host "[OK] Directories created" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2/4: Downloading model (6-8GB)" -ForegroundColor Cyan
Write-Host "This may take 10-20 minutes depending on your internet speed..." -ForegroundColor Yellow
Write-Host ""

# Check if model exists
if (Test-Path "models/nanonets--Nanonets-OCR2-3B") {
    Write-Host "[OK] Model already downloaded" -ForegroundColor Green
    $size = (Get-ChildItem -Path "models/nanonets--Nanonets-OCR2-3B" -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host ("  Location: models/nanonets--Nanonets-OCR2-3B") -ForegroundColor Gray
    Write-Host ("  Size: {0:N2} GB" -f $size) -ForegroundColor Gray
} else {
    # Run model downloader
    docker-compose --profile setup up model-downloader
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Model downloaded successfully" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Model download failed" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

Write-Host "Step 3/4: Starting services" -ForegroundColor Cyan
Write-Host "Starting vLLM and Nginx gateway..." -ForegroundColor Gray
docker-compose up -d vllm-nanonets-ocr nginx-gateway

Write-Host ""
Write-Host "Waiting for vLLM to load model (30-60 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Step 4/4: Verifying deployment" -ForegroundColor Cyan

# Test health endpoint
$healthy = $false
for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] Service is healthy" -ForegroundColor Green
            $healthy = $true
            break
        }
    } catch {
        if ($i -eq 10) {
            Write-Host "[FAIL] Service health check failed" -ForegroundColor Red
            Write-Host "Check logs: docker-compose logs vllm-nanonets-ocr" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "  Waiting... ($i/10)" -ForegroundColor Gray
        Start-Sleep -Seconds 6
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Architecture:" -ForegroundColor Cyan
Write-Host "  ┌─────────────────────────────┐"
Write-Host "  │  Nginx Gateway (Port 8001)  │  ← External access"
Write-Host "  └────────────┬────────────────┘"
Write-Host "               │ internal network"
Write-Host "  ┌────────────▼────────────────┐"
Write-Host "  │  vLLM-Nanonets-OCR          │  ← NO internet"
Write-Host "  │  (Internal only)            │  ← NO exposed ports"
Write-Host "  └─────────────────────────────┘"
Write-Host ""
Write-Host "Security Status:" -ForegroundColor Cyan
Write-Host "  • vLLM container: NO internet access" -ForegroundColor Green
Write-Host "  • vLLM container: NO exposed ports" -ForegroundColor Green
Write-Host "  • Access: Only via nginx gateway (8001)" -ForegroundColor Green
Write-Host "  • Model: Loaded from persistent volume" -ForegroundColor Green
Write-Host ""
Write-Host "API Endpoint:" -ForegroundColor Cyan
Write-Host "  http://localhost:8001" -ForegroundColor White
Write-Host ""
Write-Host "Quick Test:" -ForegroundColor Cyan
Write-Host "  curl http://localhost:8001/health" -ForegroundColor White
Write-Host "  python scripts\nanonets-ocr-example.py --image your_doc.jpg" -ForegroundColor White
Write-Host ""
Write-Host "Management:" -ForegroundColor Cyan
Write-Host "  View logs:    docker-compose logs -f vllm-nanonets-ocr" -ForegroundColor White
Write-Host "  Stop:         docker-compose down" -ForegroundColor White
Write-Host "  Restart:      docker-compose restart vllm-nanonets-ocr" -ForegroundColor White
Write-Host ""

