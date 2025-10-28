#!/bin/bash
#
# Test the vLLM OpenAI-compatible API
#

set -e

API_URL="http://localhost:8000"

echo "================================================"
echo "vLLM OpenAI API Test Script"
echo "================================================"
echo ""
echo "API URL: $API_URL"
echo ""

# Check if API is running
echo "1. Testing API health..."
if ! curl -s -f "$API_URL/health" > /dev/null 2>&1; then
    echo "✗ API is not responding at $API_URL"
    echo ""
    echo "Make sure the server is running:"
    echo "  docker-compose up -d"
    echo ""
    echo "Check logs with:"
    echo "  docker-compose logs -f vllm-api"
    exit 1
fi
echo "✓ API is healthy"
echo ""

# List available models
echo "2. Listing available models..."
curl -s "$API_URL/v1/models" | python3 -m json.tool
echo ""

# Test completion endpoint
echo "3. Testing completion endpoint..."
curl -s "$API_URL/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "meta-llama/Llama-3.2-3B-Instruct",
        "prompt": "The capital of France is",
        "max_tokens": 20,
        "temperature": 0.7
    }' | python3 -m json.tool
echo ""

# Test chat completion endpoint
echo "4. Testing chat completion endpoint..."
curl -s "$API_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "meta-llama/Llama-3.2-3B-Instruct",
        "messages": [
            {"role": "system", "content": "You are a helpful AI assistant."},
            {"role": "user", "content": "What is the capital of France?"}
        ],
        "max_tokens": 100,
        "temperature": 0.7
    }' | python3 -m json.tool
echo ""

echo "================================================"
echo "✓ All API tests completed!"
echo "================================================"
echo ""
echo "You can now use this API as a drop-in replacement for OpenAI API."
echo ""
echo "Python example:"
echo "  python scripts/client-example.py"
echo ""

