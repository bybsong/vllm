#!/usr/bin/env python3
"""
LlamaIndex RAG + Nanonets OCR Integration

This shows how to use Nanonets-OCR2-3B as a preprocessing step
in your LlamaIndex RAG pipeline.

Usage:
  1. Copy this code into your llamaindex-rag container
  2. Modify your existing RAG pipeline to use ocr_pdf_with_nanonets()
  3. Process PDFs with OCR before indexing
"""

import base64
from io import BytesIO
from typing import List, Optional
import requests
from PIL import Image

try:
    from llama_index.core import Document
    from llama_index.core.node_parser import SimpleNodeParser
except ImportError:
    print("Note: This example requires llama-index. Install in your container.")
    Document = None  # For type hints


# Configuration
OCR_API_URL = "http://vllm-nanonets-ocr:8000/v1"  # Container-to-container
# OCR_API_URL = "http://localhost:8001/v1"        # From host

# Nanonets prompts
PROMPT_GENERAL = """Extract the text from the above document as if you were reading it naturally. Return the tables in html format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes."""

PROMPT_FINANCIAL = """Extract the text from the above document as if you were reading it naturally. Return the tables in HTML format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes. Only return HTML table within <table></table>."""


def ocr_image_with_nanonets(
    image: Image.Image,
    prompt: str = PROMPT_GENERAL,
    api_url: str = OCR_API_URL,
    max_tokens: int = 15000
) -> str:
    """
    OCR a single image using Nanonets-OCR2-3B.
    
    Args:
        image: PIL Image object
        prompt: OCR prompt template
        api_url: vLLM API URL
        max_tokens: Maximum tokens to generate
    
    Returns:
        Extracted text in markdown format
    """
    # Encode image to base64
    buffered = BytesIO()
    image.save(buffered, format="PNG")
    img_base64 = base64.b64encode(buffered.getvalue()).decode('utf-8')
    
    # Make API request
    response = requests.post(
        f"{api_url}/chat/completions",
        json={
            "model": "nanonets/Nanonets-OCR2-3B",
            "messages": [
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
            "temperature": 0.0,
            "max_tokens": max_tokens,
        },
        timeout=60,
    )
    
    response.raise_for_status()
    result = response.json()
    return result['choices'][0]['message']['content']


def ocr_pdf_with_nanonets(
    pdf_path: str,
    is_financial: bool = False,
    dpi: int = 300,
    api_url: str = OCR_API_URL
) -> List[dict]:
    """
    OCR a multi-page PDF using Nanonets-OCR2-3B.
    
    Args:
        pdf_path: Path to PDF file
        is_financial: Use financial document prompt
        dpi: DPI for PDF rendering
        api_url: vLLM API URL
    
    Returns:
        List of dicts with page_num and text for each page
    """
    import fitz  # PyMuPDF
    
    prompt = PROMPT_FINANCIAL if is_financial else PROMPT_GENERAL
    
    # Open PDF
    doc = fitz.open(pdf_path)
    results = []
    
    print(f"Processing {len(doc)} pages from {pdf_path}...")
    
    for page_num in range(len(doc)):
        print(f"  Page {page_num + 1}/{len(doc)}...", end=' ')
        
        # Render page to image
        page = doc[page_num]
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        pix = page.get_pixmap(matrix=mat)
        
        # Convert to PIL Image
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        
        # OCR the page
        try:
            text = ocr_image_with_nanonets(img, prompt=prompt, api_url=api_url)
            results.append({
                'page_num': page_num + 1,
                'text': text
            })
            print(f"✓ ({len(text)} chars)")
        except Exception as e:
            print(f"✗ Error: {e}")
            results.append({
                'page_num': page_num + 1,
                'text': f"[Error processing page: {e}]"
            })
    
    doc.close()
    return results


def create_llamaindex_documents_from_ocr(
    ocr_results: List[dict],
    pdf_path: str,
    metadata: Optional[dict] = None
) -> List:
    """
    Convert OCR results to LlamaIndex Document objects.
    
    Args:
        ocr_results: List from ocr_pdf_with_nanonets()
        pdf_path: Original PDF path
        metadata: Additional metadata to attach
    
    Returns:
        List of LlamaIndex Document objects
    """
    if Document is None:
        raise ImportError("llama-index not installed")
    
    documents = []
    
    for result in ocr_results:
        doc_metadata = {
            'source': pdf_path,
            'page': result['page_num'],
            'extraction_method': 'nanonets-ocr2-3b',
            **(metadata or {})
        }
        
        doc = Document(
            text=result['text'],
            metadata=doc_metadata
        )
        documents.append(doc)
    
    return documents


# ========================================
# Example: Complete RAG Pipeline with OCR
# ========================================

def example_rag_pipeline_with_ocr():
    """
    Example: Integrate Nanonets OCR into LlamaIndex RAG pipeline.
    
    This replaces standard PDF loading with OCR preprocessing.
    """
    from llama_index.core import VectorStoreIndex, Settings
    from llama_index.core.node_parser import SentenceSplitter
    
    # Your PDF files
    pdf_files = [
        "/path/to/document1.pdf",
        "/path/to/financial_report.pdf",  # Will use financial prompt
    ]
    
    all_documents = []
    
    for pdf_path in pdf_files:
        print(f"\nProcessing: {pdf_path}")
        
        # Determine if financial document (you can add your logic here)
        is_financial = "financial" in pdf_path.lower() or "report" in pdf_path.lower()
        
        # OCR the PDF
        ocr_results = ocr_pdf_with_nanonets(
            pdf_path,
            is_financial=is_financial,
            dpi=300,  # Adjust for quality/speed
            api_url=OCR_API_URL
        )
        
        # Convert to LlamaIndex documents
        documents = create_llamaindex_documents_from_ocr(
            ocr_results,
            pdf_path,
            metadata={'document_type': 'financial' if is_financial else 'general'}
        )
        
        all_documents.extend(documents)
    
    print(f"\nTotal documents created: {len(all_documents)}")
    
    # Parse into nodes
    parser = SentenceSplitter(chunk_size=1024, chunk_overlap=200)
    nodes = parser.get_nodes_from_documents(all_documents)
    
    print(f"Total nodes/chunks: {len(nodes)}")
    
    # Create index (use your existing embedding model)
    index = VectorStoreIndex(nodes)
    
    # Query
    query_engine = index.as_query_engine()
    response = query_engine.query("What is the total revenue?")
    
    print(f"\nQuery: What is the total revenue?")
    print(f"Response: {response}")
    
    return index


# ========================================
# Example: Simple Document Processing
# ========================================

def example_simple_processing():
    """
    Simple example: Process one PDF and print results.
    """
    pdf_path = "/path/to/your/document.pdf"
    
    # OCR the PDF
    results = ocr_pdf_with_nanonets(
        pdf_path,
        is_financial=False,  # Set to True for financial docs
        dpi=300
    )
    
    # Print results
    for result in results:
        print(f"\n{'='*60}")
        print(f"Page {result['page_num']}")
        print(f"{'='*60}")
        print(result['text'])
    
    return results


# ========================================
# Example: Integration with Existing Pipeline
# ========================================

def process_pdf_for_rag(pdf_path: str, is_financial: bool = False):
    """
    Drop-in replacement for your existing PDF loader.
    
    Usage in your existing code:
        # Instead of:
        # documents = SimpleDirectoryReader(input_files=[pdf_path]).load_data()
        
        # Use:
        documents = process_pdf_for_rag(pdf_path)
    """
    # OCR with Nanonets
    ocr_results = ocr_pdf_with_nanonets(
        pdf_path,
        is_financial=is_financial,
        api_url=OCR_API_URL
    )
    
    # Convert to LlamaIndex documents
    documents = create_llamaindex_documents_from_ocr(
        ocr_results,
        pdf_path
    )
    
    return documents


if __name__ == "__main__":
    print("Nanonets OCR + LlamaIndex Integration Examples")
    print("="*60)
    print("\nThis module provides:")
    print("1. ocr_pdf_with_nanonets() - OCR any PDF")
    print("2. create_llamaindex_documents_from_ocr() - Convert to LlamaIndex docs")
    print("3. process_pdf_for_rag() - Drop-in PDF processor")
    print("\nImport these functions into your RAG pipeline!")

