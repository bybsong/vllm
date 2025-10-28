#!/bin/bash
# Test script for Chandra OCR model via vLLM API
# Tests health check, model listing, and basic inference

set -e

API_BASE="http://localhost:8001/chandra/v1"
GATEWAY_BASE="http://localhost:8001"

echo "=========================================="
echo "Chandra OCR Model Test Suite"
echo "=========================================="
echo ""

# Test 1: Gateway Health
echo "1. Testing gateway health..."
curl -s -f "${GATEWAY_BASE}/health/chandra" && echo " ✓ Gateway health check passed" || echo " ✗ Gateway health check failed"
echo ""

# Test 2: Model listing
echo "2. Testing model listing..."
MODELS=$(curl -s "${API_BASE}/models")
if echo "$MODELS" | grep -q "datalab-to/chandra"; then
    echo " ✓ Model listed successfully"
    echo "$MODELS" | jq '.' 2>/dev/null || echo "$MODELS"
else
    echo " ✗ Model not found in listing"
    echo "$MODELS"
fi
echo ""

# Test 3: Basic completion (text only)
echo "3. Testing basic text completion..."
RESPONSE=$(curl -s -X POST "${API_BASE}/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "datalab-to/chandra",
    "messages": [
      {
        "role": "user",
        "content": "What is OCR?"
      }
    ],
    "max_tokens": 50,
    "temperature": 0.1
  }')

if echo "$RESPONSE" | grep -q "choices"; then
    echo " ✓ Basic completion test passed"
    echo "$RESPONSE" | jq '.choices[0].message.content' 2>/dev/null || echo "$RESPONSE"
else
    echo " ✗ Basic completion test failed"
    echo "$RESPONSE"
fi
echo ""

# Test 4: Gateway info endpoint
echo "4. Testing gateway info..."
curl -s "${GATEWAY_BASE}/" | jq '.models.chandra' 2>/dev/null && echo " ✓ Chandra info available" || echo " ✗ Gateway info failed"
echo ""

echo "=========================================="
echo "Test Suite Complete"
echo "=========================================="
echo ""
echo "Note: Vision tests require image input and should be tested separately"
echo "For full OCR testing, use the Python client with actual document images"

