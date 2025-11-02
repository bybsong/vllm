# Download Qwen3-VL-30B-A3B-Instruct Model
# Downloads the latest Qwen3-VL model with MoE architecture
# Model Size: ~60GB
# VRAM Usage: ~8-10GB (MoE efficiency - only 3.3B active params)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Qwen3-VL Model Downloader" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$MODEL_NAME = "Qwen/Qwen3-VL-30B-A3B-Instruct"
$MODEL_DIR = "Qwen--Qwen3-VL-30B-A3B-Instruct"
$TARGET_PATH = ".\models\$MODEL_DIR"
$OFFLINE_MARKER = ".\models\.qwen3vl_downloaded"

# Check if model already exists
if (Test-Path $TARGET_PATH) {
    Write-Host "Model already exists at: $TARGET_PATH" -ForegroundColor Yellow
    
    # Check if it's complete
    if (Test-Path $OFFLINE_MARKER) {
        Write-Host "Model download previously completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can start the service with:" -ForegroundColor Cyan
        Write-Host "  docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway" -ForegroundColor White
        exit 0
    }
}

# Check if huggingface-cli is installed
Write-Host "Checking for huggingface-cli..." -ForegroundColor Yellow

# Add common Python Scripts paths to PATH
$pythonScriptsPaths = @(
    "$env:APPDATA\Python\Python310\Scripts",
    "$env:APPDATA\Python\Python311\Scripts",
    "$env:APPDATA\Python\Python312\Scripts",
    "$env:LOCALAPPDATA\Programs\Python\Python310\Scripts",
    "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts",
    "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts"
)

foreach ($path in $pythonScriptsPaths) {
    if ((Test-Path $path) -and ($env:Path -notlike "*$path*")) {
        $env:Path += ";$path"
    }
}

$HF_CLI = Get-Command huggingface-cli -ErrorAction SilentlyContinue

if (-not $HF_CLI) {
    Write-Host "huggingface-cli not found. Installing..." -ForegroundColor Yellow
    pip install -U "huggingface_hub[cli]"
    
    # Refresh PATH after installation
    foreach ($path in $pythonScriptsPaths) {
        if ((Test-Path $path) -and ($env:Path -notlike "*$path*")) {
            $env:Path += ";$path"
        }
    }
    
    $HF_CLI = Get-Command huggingface-cli -ErrorAction SilentlyContinue
    if (-not $HF_CLI) {
        Write-Host "ERROR: Could not find huggingface-cli after installation" -ForegroundColor Red
        Write-Host "Please close and reopen PowerShell, then run this script again." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Downloading: $MODEL_NAME" -ForegroundColor Green
Write-Host "Target: $TARGET_PATH" -ForegroundColor Cyan
Write-Host "Size: ~60GB (this will take time depending on your connection)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press CTRL+C to cancel at any time (download can be resumed)" -ForegroundColor Gray
Write-Host ""

# Create models directory if it doesn't exist
if (-not (Test-Path ".\models")) {
    New-Item -ItemType Directory -Path ".\models" | Out-Null
}

# Download model
try {
    Set-Location ".\models"
    
    Write-Host "Starting download..." -ForegroundColor Green
    huggingface-cli download $MODEL_NAME --local-dir $MODEL_DIR --local-dir-use-symlinks False
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "Model downloaded successfully!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host ""
        
        # Create offline marker
        Set-Location ..
        New-Item -ItemType File -Path $OFFLINE_MARKER -Force | Out-Null
        
        # Get directory size
        $size = (Get-ChildItem -Path $TARGET_PATH -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [math]::Round($size / 1GB, 2)
        
        Write-Host "Location: $TARGET_PATH" -ForegroundColor Cyan
        Write-Host "Size: $sizeGB GB" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Start the service:" -ForegroundColor White
        Write-Host "   docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Check logs:" -ForegroundColor White
        Write-Host "   docker logs -f vllm-qwen3vl" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Test the API:" -ForegroundColor White
        Write-Host "   .\scripts\test-qwen3vl.ps1" -ForegroundColor Gray
        Write-Host ""
    } else {
        throw "Download failed with exit code: $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "Error during download: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can resume the download by running this script again." -ForegroundColor Yellow
    Set-Location ..
    exit 1
} finally {
    # Make sure we're back in the original directory
    if ((Get-Location).Path -like "*\models") {
        Set-Location ..
    }
}

