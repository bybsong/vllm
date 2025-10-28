#!/usr/bin/env pwsh
# OCR a PDF/Image file using Nanonets-OCR2-3B
# Usage: .\scripts\ocr-pdf.ps1 "C:\path\to\document.pdf"
# Usage: .\scripts\ocr-pdf.ps1 "C:\path\to\image.jpg" -Financial

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [switch]$Financial,
    
    [Parameter(Mandatory=$false)]
    [string]$Output
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Nanonets-OCR2-3B - Document OCR" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if file exists
if (-not (Test-Path $FilePath)) {
    Write-Host "Error: File not found: $FilePath" -ForegroundColor Red
    exit 1
}

# Get absolute path
$FilePath = (Resolve-Path $FilePath).Path
Write-Host "File: $FilePath" -ForegroundColor Green

# Check if service is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -Method GET -ErrorAction Stop
    Write-Host "Service: Online" -ForegroundColor Green
} catch {
    Write-Host "Error: vLLM service not running on port 8001" -ForegroundColor Red
    Write-Host "Start it with: docker-compose up -d vllm-nanonets-ocr" -ForegroundColor Yellow
    exit 1
}

# Build command
$cmd = "python scripts\nanonets-ocr-example.py --mode api --image `"$FilePath`""

if ($Financial) {
    $cmd += " --financial"
    Write-Host "Document type: Financial (complex tables)" -ForegroundColor Yellow
}

if ($Output) {
    $cmd += " --output `"$Output`""
    Write-Host "Output file: $Output" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Processing..." -ForegroundColor Cyan
Write-Host ""

# Run OCR
Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Done!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "OCR failed. Check the error above." -ForegroundColor Red
    exit 1
}

