#!/usr/bin/env pwsh
# Verify that models are running in secure offline mode
# Tests network isolation and model functionality

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Secure Model Verification Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$models = @(
    @{
        Name = "Nanonets-OCR (Reference)"
        Container = "vllm-ocr"
        Port = 8000
        Profile = "ocr"
        TestType = "vision"
    },
    @{
        Name = "Qwen3-4B-Instruct"
        Container = "vllm-text"
        Port = 8003
        Profile = "text"
        TestType = "text"
    },
    @{
        Name = "Qwen3-VL-30B-AWQ"
        Container = "vllm-qwen3vl"
        Port = 8002
        Profile = "qwen3vl"
        TestType = "vision"
    },
    @{
        Name = "Qwen3-VL-4B"
        Container = "vllm-qwen3vl-4b"
        Port = 8005
        Profile = "qwen3vl-4b"
        TestType = "vision"
    }
)

$results = @()

foreach ($model in $models) {
    Write-Host "Testing: $($model.Name)" -ForegroundColor Yellow
    Write-Host "  Container: $($model.Container)" -ForegroundColor Gray
    
    $result = @{
        Name = $model.Name
        Container = $model.Container
        Running = $false
        NoInternet = $false
        HealthCheck = $false
        OfflineMode = $false
        ApiWorks = $false
    }
    
    # Check if container is running
    $containerStatus = docker ps --filter "name=$($model.Container)" --format "{{.Status}}" 2>$null
    if ($containerStatus) {
        Write-Host "  [✓] Container running" -ForegroundColor Green
        $result.Running = $true
        
        # Test 1: Verify NO internet access
        Write-Host "  Testing network isolation..." -ForegroundColor Gray
        $pingTest = docker exec $model.Container ping -c 1 -W 1 8.8.8.8 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [✓] No internet access (isolated)" -ForegroundColor Green
            $result.NoInternet = $true
        } else {
            Write-Host "  [✗] HAS INTERNET ACCESS - SECURITY ISSUE!" -ForegroundColor Red
        }
        
        # Test 2: Check environment variables
        Write-Host "  Checking offline mode..." -ForegroundColor Gray
        $envCheck = docker exec $model.Container printenv HF_HUB_OFFLINE 2>$null
        if ($envCheck -eq "1") {
            Write-Host "  [✓] Offline mode enabled (HF_HUB_OFFLINE=1)" -ForegroundColor Green
            $result.OfflineMode = $true
        } else {
            Write-Host "  [✗] Offline mode not set" -ForegroundColor Red
        }
        
        # Test 3: Health check
        Write-Host "  Testing health endpoint..." -ForegroundColor Gray
        try {
            $health = Invoke-WebRequest -Uri "http://localhost:$($model.Port)/health" -TimeoutSec 5 -UseBasicParsing
            if ($health.StatusCode -eq 200) {
                Write-Host "  [✓] Health check passed" -ForegroundColor Green
                $result.HealthCheck = $true
            }
        } catch {
            Write-Host "  [✗] Health check failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 4: API functionality test
        Write-Host "  Testing API..." -ForegroundColor Gray
        try {
            if ($model.TestType -eq "text") {
                # Text completion test
                $body = @{
                    model = $model.Container
                    messages = @(
                        @{
                            role = "user"
                            content = "Say 'test successful' and nothing else."
                        }
                    )
                    max_tokens = 10
                } | ConvertTo-Json
                
                $response = Invoke-WebRequest -Uri "http://localhost:$($model.Port)/v1/chat/completions" `
                    -Method POST `
                    -ContentType "application/json" `
                    -Body $body `
                    -TimeoutSec 30 `
                    -UseBasicParsing
                
                if ($response.StatusCode -eq 200) {
                    Write-Host "  [✓] API test passed (text generation)" -ForegroundColor Green
                    $result.ApiWorks = $true
                }
            } else {
                # Vision model - just test models endpoint
                $modelsResponse = Invoke-WebRequest -Uri "http://localhost:$($model.Port)/v1/models" `
                    -TimeoutSec 10 `
                    -UseBasicParsing
                
                if ($modelsResponse.StatusCode -eq 200) {
                    Write-Host "  [✓] API test passed (models endpoint)" -ForegroundColor Green
                    $result.ApiWorks = $true
                }
            }
        } catch {
            Write-Host "  [✗] API test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    } else {
        Write-Host "  [✗] Container not running" -ForegroundColor Red
        Write-Host "      Start with: docker-compose --profile $($model.Profile) up -d" -ForegroundColor Gray
    }
    
    $results += $result
    Write-Host ""
}

# Summary
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "SECURITY SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$allSecure = $true

foreach ($result in $results) {
    if ($result.Running) {
        $status = if ($result.NoInternet -and $result.OfflineMode -and $result.HealthCheck) {
            "✓ SECURE"
            } else {
            $allSecure = $false
            "✗ INSECURE"
        }
        
        $color = if ($status -eq "✓ SECURE") { "Green" } else { "Red" }
        Write-Host "$($result.Name): " -NoNewline
        Write-Host $status -ForegroundColor $color
        
        if (-not $result.NoInternet) {
            Write-Host "  - HAS INTERNET ACCESS (CRITICAL)" -ForegroundColor Red
        }
        if (-not $result.OfflineMode) {
            Write-Host "  - Offline mode not enabled" -ForegroundColor Yellow
        }
        if (-not $result.HealthCheck) {
            Write-Host "  - Health check failed" -ForegroundColor Yellow
        }
        if (-not $result.ApiWorks) {
            Write-Host "  - API not responding" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

if ($allSecure) {
    Write-Host "✓ ALL MODELS SECURE AND OPERATIONAL" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ SECURITY ISSUES DETECTED - Review above" -ForegroundColor Red
    exit 1
}

