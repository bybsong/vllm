#!/usr/bin/env pwsh
# Check model download completeness

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Model Download Status Check" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$models = @(
    @{Name="Nanonets-OCR2-3B"; Path="models\nanonets--Nanonets-OCR2-3B"; ExpectedFiles=@("config.json", "tokenizer.json", "*.safetensors")},
    @{Name="Qwen3-4B-Instruct"; Path="models\Qwen--Qwen3-4B-Instruct-2507"; ExpectedFiles=@("config.json", "tokenizer.json", "*.safetensors")},
    @{Name="Qwen3-14B"; Path="models\Qwen--Qwen3-14B"; ExpectedFiles=@("config.json", "tokenizer.json", "*.safetensors")},
    @{Name="Qwen3-VL-4B-Instruct"; Path="models\Qwen--Qwen3-VL-4B-Instruct"; ExpectedFiles=@("config.json", "tokenizer.json", "*.safetensors", "preprocessor_config.json")},
    @{Name="Qwen3-VL-30B-AWQ"; Path="models\QuantTrio--Qwen3-VL-30B-A3B-Instruct-AWQ"; ExpectedFiles=@("config.json", "tokenizer.json", "*.safetensors", "preprocessor_config.json")}
)

foreach ($model in $models) {
    Write-Host "Checking: $($model.Name)" -ForegroundColor Yellow
    Write-Host "  Path: $($model.Path)"
    
    if (Test-Path $model.Path) {
        Write-Host "  Status: " -NoNewline
        Write-Host "FOUND" -ForegroundColor Green
        
        # Check for required files
        $allFilesPresent = $true
        foreach ($file in $model.ExpectedFiles) {
            $found = Get-ChildItem -Path $model.Path -Filter $file -File -ErrorAction SilentlyContinue
            if ($found) {
                if ($file -like "*.safetensors") {
                    $count = ($found | Measure-Object).Count
                    $totalSize = ($found | Measure-Object -Property Length -Sum).Sum
                    $sizeGB = [math]::Round($totalSize / 1GB, 2)
                    Write-Host "    - Model files: $count files ($sizeGB GB)" -ForegroundColor Green
                } else {
                    Write-Host "    - $file : FOUND" -ForegroundColor Green
                }
            } else {
                Write-Host "    - $file : MISSING" -ForegroundColor Red
                $allFilesPresent = $false
            }
        }
        
        if ($allFilesPresent) {
            Write-Host "  Overall: " -NoNewline
            Write-Host "COMPLETE ✓" -ForegroundColor Green
        } else {
            Write-Host "  Overall: " -NoNewline
            Write-Host "INCOMPLETE ✗" -ForegroundColor Red
        }
    } else {
        Write-Host "  Status: " -NoNewline
        Write-Host "NOT DOWNLOADED ✗" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Summary Complete" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

