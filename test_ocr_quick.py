#!/usr/bin/env python3
"""Quick OCR test"""
from PIL import Image, ImageDraw
import base64
import io
import json
import urllib.request

print("Creating test image...")
img = Image.new('RGB', (400, 200), 'white')
d = ImageDraw.Draw(img)
d.text((50, 50), 'SAMPLE INVOICE\nTotal: $1,234.56', fill='black')

buf = io.BytesIO()
img.save(buf, 'PNG')
img_b64 = base64.b64encode(buf.getvalue()).decode()

print("Sending OCR request to http://localhost:8001...")

data = {
    'model': 'nanonets/Nanonets-OCR2-3B',
    'messages': [{
        'role': 'user',
        'content': [
            {'type': 'image_url', 'image_url': {'url': f'data:image/png;base64,{img_b64}'}},
            {'type': 'text', 'text': 'Extract the text from this image.'}
        ]
    }],
    'temperature': 0.0,
    'max_tokens': 500
}

req = urllib.request.Request(
    'http://localhost:8001/v1/chat/completions',
    data=json.dumps(data).encode(),
    headers={'Content-Type': 'application/json'}
)

try:
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    
    print("\n" + "="*60)
    print("OCR RESULT:")
    print("="*60)
    print(result['choices'][0]['message']['content'])
    print("\n✓ OCR is working perfectly!")
    print("="*60)
except Exception as e:
    print(f"✗ Error: {e}")

