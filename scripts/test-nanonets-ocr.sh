#!/bin/bash
# Test Nanonets-OCR2-3B API Server
# This script verifies that the vLLM server is running correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

API_URL="http://localhost:8001"
MODEL_NAME="nanonets/Nanonets-OCR2-3B"

echo "=================================================="
echo "Nanonets-OCR2-3B API Test Suite"
echo "=================================================="
echo ""

# Test 1: Health check
echo -e "${BLUE}Test 1: Health Check${NC}"
echo "Checking if server is running..."
if curl -s -f "${API_URL}/health" > /dev/null; then
    echo -e "${GREEN}✓ Server is healthy${NC}"
else
    echo -e "${RED}✗ Server is not responding${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Is the container running? Check with: docker-compose ps"
    echo "2. Start the service: docker-compose up -d vllm-nanonets-ocr"
    echo "3. Check logs: docker-compose logs vllm-nanonets-ocr"
    exit 1
fi
echo ""

# Test 2: Model info
echo -e "${BLUE}Test 2: Model Information${NC}"
echo "Fetching available models..."
MODELS=$(curl -s "${API_URL}/v1/models")
if echo "$MODELS" | grep -q "$MODEL_NAME"; then
    echo -e "${GREEN}✓ Model loaded: $MODEL_NAME${NC}"
else
    echo -e "${YELLOW}Warning: Model name not found in response${NC}"
    echo "Response: $MODELS"
fi
echo ""

# Test 3: Simple text completion
echo -e "${BLUE}Test 3: Text Completion (without image)${NC}"
echo "Testing basic API endpoint..."
RESPONSE=$(curl -s -X POST "${API_URL}/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "'"$MODEL_NAME"'",
        "prompt": "Hello",
        "max_tokens": 10,
        "temperature": 0.0
    }')

if echo "$RESPONSE" | grep -q '"text"'; then
    echo -e "${GREEN}✓ Text completion working${NC}"
    echo "Response preview: $(echo $RESPONSE | cut -c1-100)..."
else
    echo -e "${RED}✗ Text completion failed${NC}"
    echo "Response: $RESPONSE"
fi
echo ""

# Test 4: Vision capability check
echo -e "${BLUE}Test 4: Vision-Language Capability${NC}"
echo "Creating a test image..."

# Create a simple test image with text using Python
python3 << 'EOF'
from PIL import Image, ImageDraw, ImageFont
import base64
import io

# Create test image with text
img = Image.new('RGB', (400, 200), color='white')
draw = ImageDraw.Draw(img)

# Add text
text = "SAMPLE INVOICE\nTotal: $1,234.56"
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 24)
except:
    font = ImageFont.load_default()

draw.text((50, 50), text, fill='black', font=font)

# Save as base64
buffer = io.BytesIO()
img.save(buffer, format='PNG')
img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

# Save to file for curl
with open('/tmp/test_image_b64.txt', 'w') as f:
    f.write(img_base64)

print("✓ Test image created")
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Test image generated${NC}"
    
    # Read the base64 image
    IMG_BASE64=$(cat /tmp/test_image_b64.txt)
    
    echo "Sending OCR request..."
    VISION_RESPONSE=$(curl -s -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$MODEL_NAME"'",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": "data:image/png;base64,'"$IMG_BASE64"'"
                            }
                        },
                        {
                            "type": "text",
                            "text": "Extract the text from this image."
                        }
                    ]
                }
            ],
            "temperature": 0.0,
            "max_tokens": 500
        }')
    
    if echo "$VISION_RESPONSE" | grep -q '"content"'; then
        echo -e "${GREEN}✓ Vision-language processing working${NC}"
        
        # Try to extract the content
        CONTENT=$(echo "$VISION_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['choices'][0]['message']['content'][:200])" 2>/dev/null || echo "Could not parse response")
        echo "OCR Response preview:"
        echo "$CONTENT"
    else
        echo -e "${YELLOW}⚠ Vision test completed but response format unexpected${NC}"
        echo "This may be normal depending on the input. Check logs for details."
    fi
    
    # Cleanup
    rm -f /tmp/test_image_b64.txt
else
    echo -e "${YELLOW}⚠ Could not create test image (Pillow may not be installed)${NC}"
    echo "Skipping vision test. Install Pillow with: pip install pillow"
fi
echo ""

# Test 5: Server stats
echo -e "${BLUE}Test 5: Server Statistics${NC}"
echo "Fetching server metrics..."
STATS=$(curl -s "${API_URL}/metrics" || echo "Metrics endpoint not available")
if [ "$STATS" != "Metrics endpoint not available" ]; then
    echo -e "${GREEN}✓ Metrics available${NC}"
    echo "Preview:"
    echo "$STATS" | head -n 5
else
    echo -e "${YELLOW}⚠ Metrics endpoint not available (this is normal)${NC}"
fi
echo ""

# Summary
echo "=================================================="
echo -e "${GREEN}Test Suite Complete!${NC}"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Try OCR on real documents:"
echo "   python scripts/nanonets-ocr-example.py --mode api --image your_document.jpg"
echo ""
echo "2. Run advanced examples:"
echo "   python examples/nanonets_ocr_inference.py"
echo ""
echo "3. View server logs:"
echo "   docker-compose logs -f vllm-nanonets-ocr"
echo ""
echo "4. For production (network isolation):"
echo "   - Edit docker-compose.yml"
echo "   - Uncomment 'network_mode: none' under vllm-nanonets-ocr"
echo "   - Restart: docker-compose down && docker-compose up -d"
echo ""

