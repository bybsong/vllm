#!/usr/bin/env python3
"""
Multi-page PDF OCR with Nanonets-OCR2-3B

Extracts each page from a PDF and processes them sequentially.
Combines results into a single markdown document.

Usage:
    python scripts/ocr-multipage-pdf.py input.pdf
    python scripts/ocr-multipage-pdf.py input.pdf --output result.md
    python scripts/ocr-multipage-pdf.py input.pdf --financial
"""

import argparse
import base64
import sys
from pathlib import Path

try:
    from PIL import Image
    import fitz  # PyMuPDF
    from openai import OpenAI
except ImportError as e:
    print("Error: Required packages not installed.")
    print("Install with: pip install PyMuPDF pillow openai")
    sys.exit(1)

# Nanonets prompts
PROMPT_GENERAL = """Extract the text from the above document as if you were reading it naturally. Return the tables in html format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes."""

PROMPT_FINANCIAL = """Extract the text from the above document as if you were reading it naturally. Return the tables in HTML format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes. Only return HTML table within <table></table>."""


def pdf_to_images(pdf_path, dpi=300):
    """Convert PDF pages to PIL Images."""
    print(f"Opening PDF: {pdf_path}")
    doc = fitz.open(pdf_path)
    num_pages = len(doc)
    print(f"Found {num_pages} pages")
    
    images = []
    for page_num in range(num_pages):
        print(f"Converting page {page_num + 1}/{num_pages}...", end=' ')
        page = doc[page_num]
        
        # Render page to image at specified DPI
        mat = fitz.Matrix(dpi / 72, dpi / 72)  # 72 is default DPI
        pix = page.get_pixmap(matrix=mat)
        
        # Convert to PIL Image
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        images.append(img)
        print("✓")
    
    doc.close()
    return images


def encode_image(image):
    """Encode PIL Image to base64."""
    from io import BytesIO
    buffered = BytesIO()
    image.save(buffered, format="PNG")
    return base64.b64encode(buffered.getvalue()).decode('utf-8')


def ocr_image(client, image, prompt, page_num, total_pages):
    """OCR a single image."""
    print(f"\nProcessing page {page_num}/{total_pages}...", end=' ')
    
    img_base64 = encode_image(image)
    
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
        max_tokens=15000,
    )
    
    result = response.choices[0].message.content
    print(f"✓ ({len(result)} chars)")
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Multi-page PDF OCR with Nanonets-OCR2-3B",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/ocr-multipage-pdf.py document.pdf
  python scripts/ocr-multipage-pdf.py report.pdf --output result.md
  python scripts/ocr-multipage-pdf.py financial.pdf --financial
  python scripts/ocr-multipage-pdf.py scan.pdf --dpi 200
        """
    )
    
    parser.add_argument("pdf_path", help="Path to PDF file")
    parser.add_argument(
        "--output", "-o",
        help="Output file path (default: print to stdout)"
    )
    parser.add_argument(
        "--financial",
        action="store_true",
        help="Use financial document prompt (better for complex tables)"
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=300,
        help="DPI for PDF rendering (default: 300, higher = better quality)"
    )
    parser.add_argument(
        "--url",
        default="http://localhost:8001/v1",
        help="vLLM API URL (default: http://localhost:8001/v1)"
    )
    
    args = parser.parse_args()
    
    # Validate input
    pdf_path = Path(args.pdf_path)
    if not pdf_path.exists():
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("Multi-Page PDF OCR with Nanonets-OCR2-3B")
    print("=" * 70)
    print(f"PDF: {pdf_path}")
    print(f"DPI: {args.dpi}")
    print(f"Document type: {'Financial' if args.financial else 'General'}")
    print(f"API: {args.url}")
    print("")
    
    # Convert PDF to images
    try:
        images = pdf_to_images(str(pdf_path), dpi=args.dpi)
    except Exception as e:
        print(f"\nError converting PDF: {e}")
        sys.exit(1)
    
    # Initialize client
    client = OpenAI(api_key="EMPTY", base_url=args.url)
    
    # Select prompt
    prompt = PROMPT_FINANCIAL if args.financial else PROMPT_GENERAL
    
    # Process each page
    print("\n" + "=" * 70)
    print("Processing pages...")
    print("=" * 70)
    
    results = []
    for i, image in enumerate(images, 1):
        try:
            result = ocr_image(client, image, prompt, i, len(images))
            results.append(result)
        except Exception as e:
            print(f"\n✗ Error processing page {i}: {e}")
            results.append(f"[Error processing page {i}: {e}]")
    
    # Combine results
    print("\n" + "=" * 70)
    print("Combining results...")
    print("=" * 70)
    
    combined = []
    for i, result in enumerate(results, 1):
        combined.append(f"# Page {i}\n\n{result}\n\n")
    
    final_text = "\n".join(combined)
    
    # Output
    if args.output:
        output_path = Path(args.output)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(final_text)
        print(f"✓ Saved to: {output_path}")
        print(f"  Total pages: {len(results)}")
        print(f"  Total characters: {len(final_text)}")
    else:
        print("\n" + "=" * 70)
        print("OCR RESULTS:")
        print("=" * 70)
        print(final_text)
    
    print("\n" + "=" * 70)
    print("✓ Complete!")
    print("=" * 70)


if __name__ == "__main__":
    main()

