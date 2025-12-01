import argparse
import requests
import json
import base64
from pathlib import Path
from PIL import Image
import fitz  # PyMuPDF for PDF handling

def pdf_to_images(pdf_path):
    """Convert PDF pages to images"""
    doc = fitz.open(pdf_path)
    images = []
    for page_num in range(len(doc)):
        page = doc[page_num]
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))  # 2x zoom for better quality
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        images.append(img)
    doc.close()
    return images

def encode_image(image):
    """Convert PIL Image to base64"""
    import io
    buffer = io.BytesIO()
    image.save(buffer, format='PNG')
    return base64.b64encode(buffer.getvalue()).decode('utf-8')

def test_ocr_pdf(pdf_path, api_url="http://localhost:8001/hunyuan/v1/chat/completions"):
    print(f"Testing HunyuanOCR with PDF: {pdf_path}")
    
    # Convert PDF to images
    print("Converting PDF to images...")
    images = pdf_to_images(pdf_path)
    print(f"Found {len(images)} pages")
    
    # Standard OCR Prompt for Hunyuan
    prompt_text = (
        "Extract all information from the main body of the document image "
        "and represent it in markdown format, ignoring headers and footers. "
        "Tables should be expressed in HTML format, formulas in the document "
        "should be represented using LaTeX format, and the parsing should be "
        "organized according to the reading order."
    )
    
    results = []
    
    for page_num, image in enumerate(images, 1):
        print(f"\nProcessing page {page_num}/{len(images)}...")
        
        base64_image = encode_image(image)
        image_url = f"data:image/png;base64,{base64_image}"
        
        payload = {
            "model": "tencent/HunyuanOCR",
            "messages": [
                {
                    "role": "system",
                    "content": ""
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": image_url
                            }
                        },
                        {"type": "text", "text": prompt_text}
                    ]
                }
            ],
            "temperature": 0.0,
            "top_k": 1,
            "repetition_penalty": 1.0,
            "max_tokens": 4096
        }
        
        try:
            response = requests.post(api_url, headers={"Content-Type": "application/json"}, json=payload, timeout=120)
            response.raise_for_status()
            result = response.json()
            text = result['choices'][0]['message']['content']
            results.append(f"=== Page {page_num} ===\n{text}\n")
            print(f"✓ Page {page_num} processed successfully ({len(text)} characters)")
        except Exception as e:
            print(f"✗ Error processing page {page_num}: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            results.append(f"=== Page {page_num} ===\nERROR: {e}\n")
    
    # Save results
    output_path = Path(pdf_path).with_suffix('.ocr.txt')
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(results))
    
    print(f"\n{'='*60}")
    print(f"Results saved to: {output_path}")
    print(f"{'='*60}")
    
    # Print first page result
    if results:
        print("\nFirst page result preview:")
        print("-" * 60)
        print(results[0][:500] + "..." if len(results[0]) > 500 else results[0])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test HunyuanOCR with PDF via vLLM")
    parser.add_argument("pdf_path", help="Path to PDF file")
    parser.add_argument("--url", default="http://localhost:8006/v1/chat/completions", help="API URL")
    args = parser.parse_args()
    
    test_ocr_pdf(args.pdf_path, args.url)

