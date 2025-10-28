#!/bin/bash
#
# Phase 1: Download Models (WITH network access)
# Run this script BEFORE applying network restrictions
#

set -e

echo "================================================"
echo "vLLM Model Download Script - Phase 1"
echo "================================================"
echo ""
echo "This script downloads models WITH network access enabled."
echo "After models are downloaded, you can run Phase 2 with network restrictions."
echo ""

# Create models directory if it doesn't exist
mkdir -p ./models

# Set cache directory
export HF_HOME="$(pwd)/models"
export HF_HUB_DISABLE_TELEMETRY=1
export DO_NOT_TRACK=1

# Check if Python/pip is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python3 not found. Please install Python first."
    exit 1
fi

# Check if huggingface-cli is available
if ! command -v huggingface-cli &> /dev/null; then
    echo "Installing huggingface-hub..."
    pip install -q huggingface-hub
fi

echo "Download directory: $(pwd)/models"
echo ""

# Array of models to download
# Add or remove models as needed
MODELS=(
    "meta-llama/Llama-3.2-3B-Instruct"
    "Qwen/Qwen2.5-1.5B-Instruct"
    "facebook/opt-125m"
)

echo "Models to download:"
for model in "${MODELS[@]}"; do
    echo "  - $model"
done
echo ""

# Download each model
for model in "${MODELS[@]}"; do
    echo "================================================"
    echo "Downloading: $model"
    echo "================================================"
    
    # Check if model is gated (requires HF token)
    if [[ "$model" == *"llama"* ]] || [[ "$model" == *"Llama"* ]]; then
        echo "NOTE: This model may require HuggingFace authentication."
        echo "If download fails, run: huggingface-cli login"
        echo ""
    fi
    
    # Download the model
    huggingface-cli download "$model" --cache-dir ./models --local-dir-use-symlinks False
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully downloaded: $model"
    else
        echo "✗ Failed to download: $model"
        echo "  You may need to authenticate or check your internet connection"
    fi
    echo ""
done

echo "================================================"
echo "Download Complete!"
echo "================================================"
echo ""
echo "Downloaded models are stored in: $(pwd)/models"
echo ""
echo "Next steps:"
echo "  1. Verify models downloaded successfully"
echo "  2. Run: docker-compose up -d (to start the API server)"
echo "  3. Test with: bash scripts/test-api.sh"
echo ""
echo "For production with network restrictions:"
echo "  - Edit docker-compose.yml"
echo "  - Uncomment 'network_mode: none' under vllm-api service"
echo "  - Run: docker-compose down && docker-compose up -d"
echo ""

# Create offline marker file
touch ./models/.models_downloaded
echo "✓ Created offline marker: ./models/.models_downloaded"

