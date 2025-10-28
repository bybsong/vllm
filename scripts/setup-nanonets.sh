#!/bin/bash
# Complete setup script for Nanonets-OCR2-3B with vLLM
# Follows vLLM enterprise deployment best practices

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}======================================"
echo "Nanonets-OCR2-3B Setup"
echo "vLLM Enterprise Architecture"
echo -e "======================================${NC}"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found${NC}"
    exit 1
fi

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${YELLOW}Warning: nvidia-smi not found. GPU may not be available.${NC}"
fi

echo -e "${CYAN}Step 1/4: Creating directories${NC}"
mkdir -p models
mkdir -p nginx-config
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

echo -e "${CYAN}Step 2/4: Downloading model (6-8GB)${NC}"
echo "This may take 10-20 minutes depending on your internet speed..."
echo ""

# Check if model already exists
if [ -d "models/nanonets--Nanonets-OCR2-3B" ]; then
    echo -e "${GREEN}✓ Model already downloaded${NC}"
    echo "  Location: models/nanonets--Nanonets-OCR2-3B"
    echo "  Size: $(du -sh models/nanonets--Nanonets-OCR2-3B | cut -f1)"
else
    # Run model downloader
    docker-compose --profile setup up model-downloader
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Model downloaded successfully${NC}"
    else
        echo -e "${RED}✗ Model download failed${NC}"
        exit 1
    fi
fi
echo ""

echo -e "${CYAN}Step 3/4: Starting services${NC}"
echo "Starting vLLM and Nginx gateway..."
docker-compose up -d vllm-nanonets-ocr nginx-gateway

echo ""
echo -e "${YELLOW}Waiting for vLLM to load model (30-60 seconds)...${NC}"
sleep 30

echo ""
echo -e "${CYAN}Step 4/4: Verifying deployment${NC}"

# Test health endpoint
for i in {1..10}; do
    if curl -s -f http://localhost:8001/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Service is healthy${NC}"
        break
    else
        if [ $i -eq 10 ]; then
            echo -e "${RED}✗ Service health check failed${NC}"
            echo "Check logs: docker-compose logs vllm-nanonets-ocr"
            exit 1
        fi
        echo "  Waiting... ($i/10)"
        sleep 6
    fi
done

echo ""
echo -e "${GREEN}======================================"
echo "✓ Setup Complete!"
echo -e "======================================${NC}"
echo ""
echo -e "${CYAN}Architecture:${NC}"
echo "  ┌─────────────────────────────┐"
echo "  │  Nginx Gateway (Port 8001)  │  ← External access"
echo "  └────────────┬────────────────┘"
echo "               │ internal network"
echo "  ┌────────────▼────────────────┐"
echo "  │  vLLM-Nanonets-OCR          │  ← NO internet"
echo "  │  (Internal only)            │  ← NO exposed ports"
echo "  └─────────────────────────────┘"
echo ""
echo -e "${CYAN}Security Status:${NC}"
echo "  • vLLM container: NO internet access"
echo "  • vLLM container: NO exposed ports"
echo "  • Access: Only via nginx gateway (8001)"
echo "  • Model: Loaded from persistent volume"
echo ""
echo -e "${CYAN}API Endpoint:${NC}"
echo "  http://localhost:8001"
echo ""
echo -e "${CYAN}Quick Test:${NC}"
echo "  curl http://localhost:8001/health"
echo "  python scripts/nanonets-ocr-example.py --image your_doc.jpg"
echo ""
echo -e "${CYAN}Management:${NC}"
echo "  View logs:    docker-compose logs -f vllm-nanonets-ocr"
echo "  Stop:         docker-compose down"
echo "  Restart:      docker-compose restart vllm-nanonets-ocr"
echo ""

