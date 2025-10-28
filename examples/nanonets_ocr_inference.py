#!/usr/bin/env python3
"""
Nanonets-OCR2-3B Advanced Inference Examples

This script demonstrates advanced OCR use cases with vLLM offline inference:
- Batch processing multiple documents
- Different document types (receipts, forms, financial, scientific)
- Performance optimization
- Error handling

Usage:
    python examples/nanonets_ocr_inference.py
"""

from pathlib import Path
from typing import List, Dict
import time

try:
    from PIL import Image
    import torch
    from vllm import LLM, SamplingParams
    from vllm.inputs import TokensPrompt
except ImportError:
    print("Error: Required packages not found. Install with:")
    print("pip install vllm pillow torch")
    exit(1)


# Nanonets recommended prompts for different document types
PROMPTS = {
    "general": """Extract the text from the above document as if you were reading it naturally. Return the tables in html format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes.""",
    
    "financial": """Extract the text from the above document as if you were reading it naturally. Return the tables in HTML format. Return the equations in LaTeX representation. If there is an image in the document and image caption is not present, add a small description of the image inside the <img></img> tag; otherwise, add the image caption inside <img></img>. Watermarks should be wrapped in brackets. Ex: <watermark>OFFICIAL COPY</watermark>. Page numbers should be wrapped in brackets. Ex: <page_number>14</page_number> or <page_number>9/22</page_number>. Prefer using ☐ and ☑ for check boxes. Only return HTML table within <table></table>.""",
}


def create_nanonets_llm(
    model_name: str = "nanonets/Nanonets-OCR2-3B",
    gpu_memory_utilization: float = 0.90,
    max_model_len: int = 15000,
) -> LLM:
    """
    Create vLLM LLM instance for Nanonets-OCR2-3B.
    
    Args:
        model_name: Model identifier
        gpu_memory_utilization: GPU memory to use (0.0-1.0)
        max_model_len: Maximum context length
    
    Returns:
        LLM instance
    """
    print(f"Loading model: {model_name}")
    print(f"Max model length: {max_model_len}")
    print(f"GPU memory utilization: {gpu_memory_utilization}")
    print("")
    
    llm = LLM(
        model=model_name,
        max_model_len=max_model_len,
        gpu_memory_utilization=gpu_memory_utilization,
        trust_remote_code=True,
        # Nanonets recommendations:
        # - Use mixed precision (BF16) - enabled by default on supported GPUs
        # - Flash Attention - enabled by default in vLLM
        limit_mm_per_prompt={"image": 1},  # One image per prompt
    )
    
    print("✓ Model loaded successfully")
    return llm


def format_messages(image_path: str, prompt: str) -> List[Dict]:
    """Format messages for Qwen2.5-VL chat template."""
    return [
        {"role": "system", "content": "You are a helpful assistant."},
        {
            "role": "user",
            "content": [
                {"type": "image", "image": f"file://{image_path}"},
                {"type": "text", "text": prompt},
            ],
        },
    ]


def single_document_ocr(llm: LLM, image_path: str, document_type: str = "general") -> str:
    """
    Process a single document with OCR.
    
    Args:
        llm: vLLM LLM instance
        image_path: Path to image file
        document_type: Type of document ('general' or 'financial')
    
    Returns:
        Extracted text in markdown format
    """
    print(f"\nProcessing: {image_path}")
    print(f"Document type: {document_type}")
    
    # Get appropriate prompt
    prompt = PROMPTS.get(document_type, PROMPTS["general"])
    
    # Format messages
    messages = format_messages(image_path, prompt)
    
    # Sampling parameters (Nanonets recommendations)
    sampling_params = SamplingParams(
        temperature=0.0,  # Deterministic for OCR
        max_tokens=15000,  # Long documents
        repetition_penalty=1.0,  # No penalty for OCR (tables may have repetition)
    )
    
    # Generate
    start_time = time.time()
    outputs = llm.chat(
        messages=[messages],
        sampling_params=sampling_params,
    )
    elapsed = time.time() - start_time
    
    result = outputs[0].outputs[0].text
    
    print(f"✓ Processed in {elapsed:.2f} seconds")
    print(f"  Output length: {len(result)} characters")
    
    return result


def batch_ocr(
    llm: LLM,
    image_paths: List[str],
    document_types: List[str] = None
) -> List[str]:
    """
    Process multiple documents in batch for better throughput.
    
    Args:
        llm: vLLM LLM instance
        image_paths: List of image file paths
        document_types: List of document types (one per image)
    
    Returns:
        List of extracted texts
    """
    if document_types is None:
        document_types = ["general"] * len(image_paths)
    
    if len(image_paths) != len(document_types):
        raise ValueError("image_paths and document_types must have same length")
    
    print(f"\n{'=' * 70}")
    print(f"Batch OCR: {len(image_paths)} documents")
    print(f"{'=' * 70}")
    
    # Prepare all messages
    all_messages = []
    for img_path, doc_type in zip(image_paths, document_types):
        prompt = PROMPTS.get(doc_type, PROMPTS["general"])
        messages = format_messages(img_path, prompt)
        all_messages.append(messages)
    
    # Sampling parameters
    sampling_params = SamplingParams(
        temperature=0.0,
        max_tokens=15000,
        repetition_penalty=1.0,
    )
    
    # Batch generate
    print("Processing batch...")
    start_time = time.time()
    outputs = llm.chat(
        messages=all_messages,
        sampling_params=sampling_params,
    )
    elapsed = time.time() - start_time
    
    results = [output.outputs[0].text for output in outputs]
    
    print(f"\n✓ Batch processed in {elapsed:.2f} seconds")
    print(f"  Average per document: {elapsed/len(image_paths):.2f} seconds")
    print(f"  Throughput: {len(image_paths)/elapsed:.2f} docs/second")
    
    return results


def example_receipt_ocr(llm: LLM, image_path: str):
    """Example: Extract information from a receipt."""
    print("\n" + "=" * 70)
    print("Example 1: Receipt OCR")
    print("=" * 70)
    
    result = single_document_ocr(llm, image_path, "general")
    
    print("\nExtracted Receipt Data:")
    print("-" * 70)
    print(result)
    
    return result


def example_form_ocr(llm: LLM, image_path: str):
    """Example: Extract information from a form with checkboxes."""
    print("\n" + "=" * 70)
    print("Example 2: Form OCR (with checkboxes)")
    print("=" * 70)
    
    result = single_document_ocr(llm, image_path, "general")
    
    print("\nExtracted Form Data:")
    print("-" * 70)
    print(result)
    print("\nNote: Checkboxes are represented as ☐ (unchecked) or ☑ (checked)")
    
    return result


def example_financial_ocr(llm: LLM, image_path: str):
    """Example: Extract tables from financial documents."""
    print("\n" + "=" * 70)
    print("Example 3: Financial Document OCR (complex tables)")
    print("=" * 70)
    
    result = single_document_ocr(llm, image_path, "financial")
    
    print("\nExtracted Financial Data:")
    print("-" * 70)
    print(result)
    print("\nNote: Tables are in HTML format for better structure preservation")
    
    return result


def example_batch_processing(llm: LLM, image_paths: List[str]):
    """Example: Batch process multiple documents."""
    print("\n" + "=" * 70)
    print("Example 4: Batch Processing Multiple Documents")
    print("=" * 70)
    
    # Process different document types
    document_types = ["general", "financial", "general", "financial"][:len(image_paths)]
    
    results = batch_ocr(llm, image_paths, document_types)
    
    for i, (img_path, result) in enumerate(zip(image_paths, results)):
        print(f"\n--- Document {i+1}: {Path(img_path).name} ---")
        print(result[:200] + "..." if len(result) > 200 else result)
    
    return results


def main():
    """Main function demonstrating various OCR use cases."""
    print("=" * 70)
    print("Nanonets-OCR2-3B Advanced Inference Examples")
    print("=" * 70)
    print("")
    
    # Check if sample documents exist
    sample_dir = Path("examples/sample_documents")
    if not sample_dir.exists():
        print(f"Note: Sample documents directory not found: {sample_dir}")
        print("To use this script with real documents:")
        print("1. Create the directory: mkdir -p examples/sample_documents")
        print("2. Add your test images (jpg, png, pdf)")
        print("3. Run this script again")
        print("")
        print("For now, this will show you the code structure.")
        print("")
        
        # Show example usage without actual execution
        print("Example usage pattern:")
        print("-" * 70)
        print("""
# Initialize model
llm = create_nanonets_llm(
    model_name="nanonets/Nanonets-OCR2-3B",
    gpu_memory_utilization=0.90,
    max_model_len=15000,
)

# Single document OCR
result = single_document_ocr(
    llm,
    image_path="examples/sample_documents/receipt.jpg",
    document_type="general"
)

# Batch processing
results = batch_ocr(
    llm,
    image_paths=[
        "examples/sample_documents/doc1.jpg",
        "examples/sample_documents/doc2.jpg",
    ],
    document_types=["general", "financial"]
)
        """)
        return
    
    # Find sample images
    image_files = list(sample_dir.glob("*.jpg")) + list(sample_dir.glob("*.png"))
    
    if not image_files:
        print(f"No image files found in {sample_dir}")
        print("Please add some test images (.jpg or .png) to the directory.")
        return
    
    print(f"Found {len(image_files)} sample documents")
    print("")
    
    # Initialize model
    llm = create_nanonets_llm()
    
    # Run examples based on available images
    if len(image_files) >= 1:
        example_receipt_ocr(llm, str(image_files[0]))
    
    if len(image_files) >= 2:
        example_form_ocr(llm, str(image_files[1]))
    
    if len(image_files) >= 3:
        example_financial_ocr(llm, str(image_files[2]))
    
    if len(image_files) >= 4:
        example_batch_processing(llm, [str(f) for f in image_files[:4]])
    
    print("\n" + "=" * 70)
    print("Examples completed!")
    print("=" * 70)
    print("\nTips for best OCR accuracy:")
    print("- Use high-resolution images (higher resolution = better accuracy)")
    print("- Ensure good lighting and minimal glare")
    print("- For financial documents, use 'financial' document type")
    print("- Batch processing improves throughput for multiple documents")


if __name__ == "__main__":
    main()

