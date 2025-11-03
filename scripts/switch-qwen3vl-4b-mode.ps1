#!/usr/bin/env pwsh
# Switch Qwen3-VL-4B between Standalone and Shared modes

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("standalone", "shared", "status")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Qwen3-VL-4B Mode Switcher" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if in the right directory
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "Error: docker-compose.yml not found!" -ForegroundColor Red
    Write-Host "Please run this script from the vllm directory." -ForegroundColor Yellow
    exit 1
}

function Get-CurrentMode {
    $container = docker ps --filter "name=vllm-qwen3vl-4b" --format "{{.Names}}" 2>$null
    
    if ($container) {
        # Check which profile is active by inspecting the command
        $command = docker inspect vllm-qwen3vl-4b --format '{{.Args}}' 2>$null
        
        if ($command -like "*--gpu-memory-utilization 0.75*") {
            return "standalone"
        } elseif ($command -like "*--gpu-memory-utilization 0.50*" -or $command -like "*--gpu-memory-utilization 0.5*") {
            return "shared"
        } else {
            return "unknown"
        }
    }
    
    return "none"
}

function Show-Status {
    $currentMode = Get-CurrentMode
    
    Write-Host "Current Status:" -ForegroundColor Yellow
    Write-Host ""
    
    if ($currentMode -eq "none") {
        Write-Host "  Status: " -NoNewline
        Write-Host "NOT RUNNING" -ForegroundColor Red
        Write-Host ""
        Write-Host "To start:" -ForegroundColor Cyan
        Write-Host "  Standalone: .\scripts\switch-qwen3vl-4b-mode.ps1 standalone" -ForegroundColor Gray
        Write-Host "  Shared:     .\scripts\switch-qwen3vl-4b-mode.ps1 shared" -ForegroundColor Gray
    } else {
        Write-Host "  Status: " -NoNewline
        Write-Host "RUNNING" -ForegroundColor Green
        Write-Host "  Mode:   " -NoNewline
        
        if ($currentMode -eq "standalone") {
            Write-Host "STANDALONE (High Performance)" -ForegroundColor Green
            Write-Host "  VRAM:   ~24GB (75% utilization)" -ForegroundColor Gray
            Write-Host "  Context: 8192 tokens" -ForegroundColor Gray
            Write-Host "  Requests: 3 concurrent" -ForegroundColor Gray
        } elseif ($currentMode -eq "shared") {
            Write-Host "SHARED (Memory Efficient)" -ForegroundColor Green
            Write-Host "  VRAM:   ~16GB (50% utilization)" -ForegroundColor Gray
            Write-Host "  Context: 4096 tokens" -ForegroundColor Gray
            Write-Host "  Requests: 2 concurrent" -ForegroundColor Gray
        } else {
            Write-Host "UNKNOWN" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "GPU Memory Usage:" -ForegroundColor Yellow
        docker exec vllm-qwen3vl-4b nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>$null
        
        Write-Host ""
        Write-Host "Container Uptime:" -ForegroundColor Yellow
        docker ps --filter "name=vllm-qwen3vl-4b" --format "  {{.Status}}"
    }
    
    Write-Host ""
}

if ($Mode -eq "status") {
    Show-Status
    exit 0
}

# Get current mode
$currentMode = Get-CurrentMode

if ($Mode -eq "standalone") {
    Write-Host "Switching to STANDALONE mode..." -ForegroundColor Cyan
    Write-Host "  - VRAM: ~24GB (75% utilization)" -ForegroundColor Gray
    Write-Host "  - Context: 8192 tokens" -ForegroundColor Gray
    Write-Host "  - Concurrent: 3 requests" -ForegroundColor Gray
    Write-Host "  - Use case: Maximum performance, running alone" -ForegroundColor Gray
    Write-Host ""
    
    if ($currentMode -eq "standalone") {
        Write-Host "Already in standalone mode!" -ForegroundColor Yellow
        Show-Status
        exit 0
    }
    
    if ($currentMode -ne "none") {
        Write-Host "Stopping current instance..." -ForegroundColor Yellow
        docker-compose --profile qwen3vl-4b-shared down 2>$null
        docker-compose --profile qwen3vl-4b down 2>$null
        docker stop vllm-qwen3vl-4b 2>$null
        Start-Sleep -Seconds 2
    }
    
    Write-Host "Starting standalone mode..." -ForegroundColor Yellow
    docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Success! Standalone mode started." -ForegroundColor Green
        Write-Host ""
        Write-Host "The model is loading... (takes 30-60 seconds)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Monitor startup:" -ForegroundColor Cyan
        Write-Host "  docker logs -f vllm-qwen3vl-4b" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Check memory:" -ForegroundColor Cyan
        Write-Host "  docker exec vllm-qwen3vl-4b nvidia-smi" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Error: Failed to start standalone mode!" -ForegroundColor Red
        exit 1
    }
    
} elseif ($Mode -eq "shared") {
    Write-Host "Switching to SHARED mode..." -ForegroundColor Cyan
    Write-Host "  - VRAM: ~16GB (50% utilization)" -ForegroundColor Gray
    Write-Host "  - Context: 4096 tokens" -ForegroundColor Gray
    Write-Host "  - Concurrent: 2 requests" -ForegroundColor Gray
    Write-Host "  - Use case: Running with marker container" -ForegroundColor Gray
    Write-Host ""
    
    if ($currentMode -eq "shared") {
        Write-Host "Already in shared mode!" -ForegroundColor Yellow
        Show-Status
        exit 0
    }
    
    if ($currentMode -ne "none") {
        Write-Host "Stopping current instance..." -ForegroundColor Yellow
        docker-compose --profile qwen3vl-4b down 2>$null
        docker-compose --profile qwen3vl-4b-shared down 2>$null
        docker stop vllm-qwen3vl-4b 2>$null
        Start-Sleep -Seconds 2
    }
    
    Write-Host "Starting shared mode..." -ForegroundColor Yellow
    docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Success! Shared mode started." -ForegroundColor Green
        Write-Host ""
        Write-Host "The model is loading... (takes 30-60 seconds)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Memory available for marker: ~14-16GB" -ForegroundColor Green
        Write-Host ""
        Write-Host "Monitor startup:" -ForegroundColor Cyan
        Write-Host "  docker logs -f vllm-qwen3vl-4b" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Check memory:" -ForegroundColor Cyan
        Write-Host "  docker exec vllm-qwen3vl-4b nvidia-smi" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Start marker when ready:" -ForegroundColor Cyan
        Write-Host "  docker-compose up -d marker" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Error: Failed to start shared mode!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

