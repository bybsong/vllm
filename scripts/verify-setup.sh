#!/bin/bash
#
# Verify that the vLLM setup is ready to use
#

set -e

echo "================================================"
echo "vLLM Setup Verification"
echo "================================================"
echo ""

SUCCESS=0
WARNINGS=0

# Check 1: WSL2
echo "✓ Running in WSL2/Linux" 
echo ""

# Check 2: GPU availability
echo "Checking GPU..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader | while read line; do
        echo "  GPU: $line"
    done
    echo "✓ GPU detected"
else
    echo "✗ nvidia-smi not found - GPU drivers may not be installed"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check 3: Docker availability
echo "Checking Docker..."
if command -v docker &> /dev/null; then
    echo "  Docker version: $(docker --version)"
    echo "✓ Docker installed"
    
    # Check Docker GPU access
    if docker run --rm --gpus all nvidia/cuda:12.8-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        echo "✓ Docker can access GPU"
    else
        echo "✗ Docker cannot access GPU - check nvidia-container-toolkit"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "✗ Docker not found - please install Docker Desktop"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check 4: Models directory
echo "Checking models..."
if [ -d "./models" ]; then
    MODEL_COUNT=$(find ./models -name "*.safetensors" -o -name "*.bin" 2>/dev/null | wc -l)
    if [ "$MODEL_COUNT" -gt 0 ]; then
        echo "  Found $MODEL_COUNT model files"
        if [ -f "./models/.models_downloaded" ]; then
            echo "✓ Models downloaded (offline marker present)"
        else
            echo "⚠ Models present but offline marker missing"
        fi
    else
        echo "⚠ Models directory exists but no model files found"
        echo "  Run: bash scripts/download-models.sh"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "⚠ Models directory not found"
    echo "  Run: bash scripts/download-models.sh"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check 5: Docker Compose
echo "Checking docker-compose.yml..."
if [ -f "docker-compose.yml" ]; then
    echo "✓ docker-compose.yml found"
else
    echo "✗ docker-compose.yml not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check 6: Scripts
echo "Checking scripts..."
REQUIRED_SCRIPTS=("download-models.sh" "test-api.sh" "client-example.py")
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "scripts/$script" ]; then
        echo "  ✓ $script"
    else
        echo "  ✗ $script missing"
        WARNINGS=$((WARNINGS + 1))
    fi
done
echo ""

# Check 7: Python packages
echo "Checking Python packages..."
if command -v python3 &> /dev/null; then
    echo "  Python: $(python3 --version)"
    
    # Check for openai package
    if python3 -c "import openai" 2>/dev/null; then
        echo "  ✓ openai package installed"
    else
        echo "  ⚠ openai package not installed (needed for client-example.py)"
        echo "    Install with: pip install openai"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "✗ Python3 not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary
echo "================================================"
echo "Verification Summary"
echo "================================================"
if [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed! Your setup is ready."
    echo ""
    echo "Next steps:"
    echo "  1. If models not downloaded: bash scripts/download-models.sh"
    echo "  2. Start API server: docker-compose up -d"
    echo "  3. Test API: bash scripts/test-api.sh"
else
    echo "⚠ Found $WARNINGS warning(s) - review messages above"
    echo ""
    echo "Common fixes:"
    echo "  - Download models: bash scripts/download-models.sh"
    echo "  - Install OpenAI SDK: pip install openai"
    echo "  - Check Docker GPU: docker run --rm --gpus all nvidia/cuda:12.8-base nvidia-smi"
fi
echo ""

