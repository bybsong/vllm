#!/usr/bin/env python3
"""
Nanonets-OCR2-3B Example Script

This script demonstrates how to use Nanonets-OCR2-3B for document OCR:
- Image-to-markdown conversion
- Table extraction (HTML format)
- Equation recognition (LaTeX)
- Watermark and checkbox detection

Usage:
    # With vLLM server running:
    python scripts/nanonets-ocr-example.py --mode api --image path/to/image.jpg
    
    # Offline inference (no server needed):
    python scripts/nanonets-ocr-example.py --mode offline --image path/to/image.jpg
"""

import argparse
import base64
import sys
from pathlib import Path

# Nanonets recommended prompt template
NANONETS_OCR_PROMPT = """Extract the text from the above document as if you were reading it naturally. Return the tables in html format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes."""

# For financial documents (complex tables)
NANONETS_FINANCIAL_PROMPT = """Extract the text from the above document as if you were reading it naturally. Return the tables in HTML format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes. Only return HTML table within <table></table>."""


def encode_image(image_path: str) -> str:
    """Encode image to base64 string."""
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode("utf-8")


def ocr_with_api(image_path: str, prompt: str = NANONETS_OCR_PROMPT, 
                 base_url: str = "http://localhost:8001/v1",
                 max_tokens: int = 15000) -> str:
    """
    Perform OCR using vLLM API server.
    
    Args:
        image_path: Path to the image file
        prompt: OCR prompt (use NANONETS_OCR_PROMPT or NANONETS_FINANCIAL_PROMPT)
        base_url: vLLM server URL
        max_tokens: Maximum tokens to generate
    
    Returns:
        Extracted text in markdown format
    """
    try:
        from openai import OpenAI
    except ImportError:
        print("Error: openai package not found. Install with: pip install openai")
        sys.exit(1)
    
    # Encode image
    img_base64 = encode_image(image_path)
    
    # Create OpenAI client pointing to vLLM
    client = OpenAI(api_key="EMPTY", base_url=base_url)
    
    print(f"Sending OCR request to {base_url}...")
    print(f"Image: {image_path}")
    print(f"Max tokens: {max_tokens}")
    print("")
    
    # Make request
    response = client.chat.completions.create(
        model="nanonets/Nanonets-OCR2-3B",
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{img_base64}"},
                    },
                    {
                        "type": "text",
                        "text": prompt,
                    },
                ],
            }
        ],
        temperature=0.0,
        max_tokens=max_tokens,
    )
    
    return response.choices[0].message.content


def ocr_offline(image_path: str, prompt: str = NANONETS_OCR_PROMPT,
                max_new_tokens: int = 15000) -> str:
    """
    Perform OCR using transformers (offline, no server needed).
    
    Args:
        image_path: Path to the image file
        prompt: OCR prompt
        max_new_tokens: Maximum tokens to generate
    
    Returns:
        Extracted text in markdown format
    """
    try:
        from PIL import Image
        from transformers import AutoTokenizer, AutoProcessor, AutoModelForImageTextToText
        import torch
    except ImportError:
        print("Error: Required packages not found. Install with:")
        print("pip install transformers pillow torch")
        sys.exit(1)
    
    model_path = "nanonets/Nanonets-OCR2-3B"
    
    print(f"Loading model: {model_path}")
    print("This may take a minute on first run...")
    
    # Load model
    model = AutoModelForImageTextToText.from_pretrained(
        model_path,
        torch_dtype="auto",
        device_map="auto",
        attn_implementation="flash_attention_2"  # Recommended by Nanonets
    )
    model.eval()
    
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    processor = AutoProcessor.from_pretrained(model_path)
    
    print(f"Processing image: {image_path}")
    
    # Load image
    image = Image.open(image_path)
    
    # Prepare messages
    messages = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": [
            {"type": "image", "image": f"file://{image_path}"},
            {"type": "text", "text": prompt},
        ]},
    ]
    
    # Process
    text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = processor(text=[text], images=[image], padding=True, return_tensors="pt")
    inputs = inputs.to(model.device)
    
    # Generate
    print("Generating OCR output...")
    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=False
        )
    
    generated_ids = [
        output_ids[len(input_ids):] 
        for input_ids, output_ids in zip(inputs.input_ids, output_ids)
    ]
    
    output_text = processor.batch_decode(
        generated_ids,
        skip_special_tokens=True,
        clean_up_tokenization_spaces=True
    )[0]
    
    return output_text


def main():
    parser = argparse.ArgumentParser(
        description="Nanonets-OCR2-3B Example Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # API mode (vLLM server must be running):
  python scripts/nanonets-ocr-example.py --mode api --image document.jpg
  
  # Offline mode (no server needed):
  python scripts/nanonets-ocr-example.py --mode offline --image document.jpg
  
  # Financial document with complex tables:
  python scripts/nanonets-ocr-example.py --mode api --image financial.pdf --financial
  
  # Custom server URL:
  python scripts/nanonets-ocr-example.py --mode api --image doc.jpg --url http://localhost:8001/v1
        """
    )
    
    parser.add_argument(
        "--mode",
        choices=["api", "offline"],
        default="api",
        help="OCR mode: 'api' (uses vLLM server) or 'offline' (uses transformers directly)"
    )
    parser.add_argument(
        "--image",
        type=str,
        required=True,
        help="Path to the image or PDF file to process"
    )
    parser.add_argument(
        "--url",
        type=str,
        default="http://localhost:8001/v1",
        help="vLLM server URL (only for API mode)"
    )
    parser.add_argument(
        "--financial",
        action="store_true",
        help="Use financial document prompt (optimized for complex tables)"
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=15000,
        help="Maximum tokens to generate (default: 15000)"
    )
    parser.add_argument(
        "--output",
        type=str,
        help="Save output to file (optional)"
    )
    
    args = parser.parse_args()
    
    # Validate image path
    image_path = Path(args.image)
    if not image_path.exists():
        print(f"Error: Image file not found: {args.image}")
        sys.exit(1)
    
    # Select prompt
    prompt = NANONETS_FINANCIAL_PROMPT if args.financial else NANONETS_OCR_PROMPT
    
    print("=" * 70)
    print("Nanonets-OCR2-3B - Document OCR")
    print("=" * 70)
    print(f"Mode: {args.mode.upper()}")
    print(f"Document type: {'Financial' if args.financial else 'General'}")
    print("")
    
    # Perform OCR
    try:
        if args.mode == "api":
            result = ocr_with_api(
                str(image_path),
                prompt=prompt,
                base_url=args.url,
                max_tokens=args.max_tokens
            )
        else:
            result = ocr_offline(
                str(image_path),
                prompt=prompt,
                max_new_tokens=args.max_tokens
            )
        
        print("")
        print("=" * 70)
        print("OCR Result:")
        print("=" * 70)
        print(result)
        print("")
        
        # Save to file if requested
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(result)
            print(f"✓ Output saved to: {args.output}")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        if args.mode == "api":
            print("\nTroubleshooting:")
            print("1. Is the vLLM server running? Check with: docker-compose ps")
            print("2. Try: curl http://localhost:8001/health")
            print("3. View logs: docker-compose logs vllm-nanonets-ocr")
        sys.exit(1)


if __name__ == "__main__":
    main()

