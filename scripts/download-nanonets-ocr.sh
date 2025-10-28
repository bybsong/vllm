#!/bin/bash
# Download Nanonets-OCR2-3B model for offline use
# This script downloads the model to ./models/ directory for use with vLLM

set -e

echo "=================================================="
echo "Nanonets-OCR2-3B Model Downloader"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MODEL_NAME="nanonets/Nanonets-OCR2-3B"
CACHE_DIR="./models"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

echo -e "${BLUE}Model:${NC} $MODEL_NAME"
echo -e "${BLUE}Cache Directory:${NC} $CACHE_DIR"
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Warning:${NC} python3 not found. Please install Python 3."
    exit 1
fi

# Check if huggingface_hub is installed
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
    echo -e "${YELLOW}Installing huggingface_hub...${NC}"
    pip install huggingface_hub
fi

echo -e "${GREEN}Starting download...${NC}"
echo ""
echo "This will download approximately 6-8GB of model files."
echo "The download may take 10-30 minutes depending on your internet speed."
echo ""

# Download the model using Python
python3 << EOF
from huggingface_hub import snapshot_download
import os

cache_dir = "$CACHE_DIR"
model_name = "$MODEL_NAME"

print(f"Downloading {model_name}...")
print(f"Target directory: {cache_dir}")
print("")

try:
    # Download model files
    local_dir = snapshot_download(
        repo_id=model_name,
        cache_dir=cache_dir,
        local_dir=os.path.join(cache_dir, model_name.replace('/', '--')),
        local_dir_use_symlinks=False,
        resume_download=True,
    )
    
    print(f"\n✓ Model downloaded successfully to: {local_dir}")
    
    # Create offline marker
    marker_file = os.path.join(cache_dir, ".nanonets_ocr_downloaded")
    with open(marker_file, "w") as f:
        f.write(f"Model: {model_name}\n")
        f.write(f"Path: {local_dir}\n")
    
    print(f"✓ Created offline marker: {marker_file}")
    
except Exception as e:
    print(f"\n✗ Error downloading model: {e}")
    print("\nIf the model is gated, you may need to:")
    print("1. Accept the model license on HuggingFace")
    print("2. Login with: huggingface-cli login")
    exit(1)

EOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=================================================="
    echo "✓ Download Complete!"
    echo -e "==================================================${NC}"
    echo ""
    echo "Model is ready for offline use."
    echo ""
    echo "Next steps:"
    echo "1. Start the vLLM server: docker-compose up -d vllm-nanonets-ocr"
    echo "2. Test the API: bash scripts/test-nanonets-ocr.sh"
    echo "3. Run examples: python scripts/nanonets-ocr-example.py"
    echo ""
    echo "For production (network isolation):"
    echo "- Edit docker-compose.yml"
    echo "- Uncomment 'network_mode: none' under vllm-nanonets-ocr service"
    echo ""
else
    echo ""
    echo -e "${YELLOW}Download failed. Please check the error messages above.${NC}"
    exit 1
fi

