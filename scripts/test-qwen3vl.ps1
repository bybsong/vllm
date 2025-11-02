# Test Qwen3-VL-30B-A3B-Instruct API
# Tests vision-language capabilities of the Qwen3-VL model

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Qwen3-VL API Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$API_BASE = "http://localhost:8001/qwen3vl/v1"
$MODEL_NAME = "Qwen/Qwen3-VL-30B-A3B-Instruct"

# Test 1: Health Check
Write-Host "[1/4] Testing health endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8001/health/qwen3vl" -Method Get -TimeoutSec 5
    Write-Host "Health check: OK" -ForegroundColor Green
} catch {
    Write-Host "Health check failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Is the service running?" -ForegroundColor Yellow
    Write-Host "Start with: docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway" -ForegroundColor Gray
    exit 1
}

# Test 2: Model Info
Write-Host "[2/4] Checking model info..." -ForegroundColor Yellow
try {
    $models = Invoke-RestMethod -Uri "$API_BASE/models" -Method Get
    Write-Host "Model loaded: $($models.data[0].id)" -ForegroundColor Green
} catch {
    Write-Host "Failed to get model info: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Text-only completion (to verify basic functionality)
Write-Host "[3/4] Testing text completion..." -ForegroundColor Yellow
$textRequest = @{
    model = $MODEL_NAME
    messages = @(
        @{
            role = "user"
            content = "What is 2+2? Answer in one word."
        }
    )
    max_tokens = 10
    temperature = 0.1
} | ConvertTo-Json -Depth 10

try {
    $textResponse = Invoke-RestMethod -Uri "$API_BASE/chat/completions" -Method Post -Body $textRequest -ContentType "application/json"
    $answer = $textResponse.choices[0].message.content.Trim()
    Write-Host "Text completion: $answer" -ForegroundColor Green
} catch {
    Write-Host "Text completion failed: $_" -ForegroundColor Red
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Gray
}

# Test 4: Vision-Language completion (with image URL)
Write-Host "[4/4] Testing vision-language completion..." -ForegroundColor Yellow
$visionRequest = @{
    model = $MODEL_NAME
    messages = @(
        @{
            role = "user"
            content = @(
                @{
                    type = "image_url"
                    image_url = @{
                        url = "https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen-VL/assets/demo.jpeg"
                    }
                }
                @{
                    type = "text"
                    text = "What's in this image? Answer briefly."
                }
            )
        }
    )
    max_tokens = 100
    temperature = 0.1
} | ConvertTo-Json -Depth 10

try {
    Write-Host "Sending image analysis request..." -ForegroundColor Gray
    $visionResponse = Invoke-RestMethod -Uri "$API_BASE/chat/completions" -Method Post -Body $visionRequest -ContentType "application/json" -TimeoutSec 60
    $description = $visionResponse.choices[0].message.content
    Write-Host ""
    Write-Host "Image description:" -ForegroundColor Cyan
    Write-Host $description -ForegroundColor White
    Write-Host ""
    Write-Host "Vision test: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "Vision completion failed: $_" -ForegroundColor Red
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "API Base: $API_BASE" -ForegroundColor White
Write-Host "Model: $MODEL_NAME" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check GPU memory usage:" -ForegroundColor White
Write-Host "   docker exec vllm-qwen3vl nvidia-smi" -ForegroundColor Gray
Write-Host ""
Write-Host "2. View logs:" -ForegroundColor White
Write-Host "   docker logs -f vllm-qwen3vl" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Compare with Ollama:" -ForegroundColor White
Write-Host "   Send the same request to both and compare responses" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Switch to production (no network):" -ForegroundColor White
Write-Host "   .\scripts\switch-qwen3vl-to-production.ps1" -ForegroundColor Gray
Write-Host ""

