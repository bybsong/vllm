#!/usr/bin/env python3
"""
Quick test script to verify Nanonets OCR is accessible from LlamaIndex
Run this from inside your llamaindex-rag container
"""

from openai import OpenAI
import base64

# Connect to vLLM Nanonets OCR
client = OpenAI(
    api_key="not-used",
    base_url="http://vllm-nanonets-ocr:8000/v1"
)

print("=" * 60)
print("Testing Nanonets OCR Service")
print("=" * 60)
print()

# Test 1: Check if service is accessible
print("1. Checking available models...")
try:
    models = client.models.list()
    print(f"   ✓ Service is accessible!")
    print(f"   Available model: {models.data[0].id}")
except Exception as e:
    print(f"   ✗ Error: {e}")
    exit(1)

print()
print("=" * 60)
print("OCR Service Ready!")
print("=" * 60)
print()
print("To use in your code:")
print()
print("from openai import OpenAI")
print('client = OpenAI(')
print('    api_key="not-used",')
print('    base_url="http://vllm-nanonets-ocr:8000/v1"')
print(')')
print()
print("# Then OCR with:")
print("# response = client.chat.completions.create(")
print("#     model='nanonets/Nanonets-OCR2-3B',")
print("#     messages=[{")
print("#         'role': 'user',")
print("#         'content': [")
print("#             {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{base64_image}'}},")
print("#             {'type': 'text', 'text': 'Convert to markdown'}")
print("#         ]")
print("#     }],")
print("#     temperature=0.0,")
print("#     max_tokens=15000")
print("# )")
print()

