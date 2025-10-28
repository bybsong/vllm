#!/usr/bin/env pwsh
# Multi-page PDF OCR using Nanonets-OCR2-3B
# Usage: .\scripts\ocr-multipage-pdf.ps1 "C:\path\to\document.pdf"
# Usage: .\scripts\ocr-multipage-pdf.ps1 "C:\path\to\document.pdf" -Financial -Output "result.md"

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$PdfPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$Financial,
    
    [Parameter(Mandatory=$false)]
    [string]$Output,
    
    [Parameter(Mandatory=$false)]
    [int]$DPI = 300
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Multi-Page PDF OCR - Nanonets-OCR2-3B" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if file exists
if (-not (Test-Path $PdfPath)) {
    Write-Host "Error: File not found: $PdfPath" -ForegroundColor Red
    exit 1
}

# Get absolute path
$PdfPath = (Resolve-Path $PdfPath).Path
Write-Host "PDF: $PdfPath" -ForegroundColor Green

# Check if service is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8001/health" -Method GET -ErrorAction Stop
    Write-Host "Service: Online" -ForegroundColor Green
} catch {
    Write-Host "Error: vLLM service not running on port 8001" -ForegroundColor Red
    Write-Host "Start it with: docker-compose up -d vllm-nanonets-ocr" -ForegroundColor Yellow
    exit 1
}

# Check if PyMuPDF is installed
try {
    python -c "import fitz" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing PyMuPDF (required for PDF processing)..." -ForegroundColor Yellow
        pip install PyMuPDF pillow openai
    }
} catch {
    Write-Host "Error checking dependencies" -ForegroundColor Red
}

# Build command
$cmd = "python scripts\ocr-multipage-pdf.py `"$PdfPath`" --dpi $DPI"

if ($Financial) {
    $cmd += " --financial"
    Write-Host "Document type: Financial (complex tables)" -ForegroundColor Yellow
}

if ($Output) {
    $cmd += " --output `"$Output`""
    Write-Host "Output file: $Output" -ForegroundColor Yellow
}

Write-Host "DPI: $DPI" -ForegroundColor Cyan
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

