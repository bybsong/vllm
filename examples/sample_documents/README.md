# Sample Documents for Nanonets-OCR2-3B Testing

This directory is for test images to use with Nanonets-OCR2-3B examples.

## Adding Your Own Test Documents

Place any of these file types here:
- `.jpg` / `.jpeg` - JPEG images
- `.png` - PNG images
- `.pdf` - PDF documents (first page will be processed)

## Recommended Test Documents

### Free/Public Domain Sources

1. **Sample Invoices & Receipts**
   - https://www.receipt-template.com/sample-receipts/
   - https://templates.office.com/en-us/invoices

2. **Form Templates**
   - https://www.irs.gov/forms-pubs (Tax forms with checkboxes)
   - https://www.gsa.gov/forms (Government forms)

3. **Financial Documents**
   - https://www.sec.gov/edgar/searchedgar/companysearch.html (Public company filings)
   - Sample annual reports (available on most company websites)

4. **Scientific Papers (with equations)**
   - https://arxiv.org/ (Open access research papers)
   - Look for papers with tables and mathematical notation

5. **Sample Documents from Nanonets**
   - Check https://huggingface.co/nanonets/Nanonets-OCR2-3B for example inputs

### Creating Test Images

You can also create test images with:

```python
from PIL import Image, ImageDraw, ImageFont

# Create a simple invoice
img = Image.new('RGB', (800, 1000), color='white')
draw = ImageDraw.Draw(img)

# Add invoice content
invoice_text = """
INVOICE #12345

Company Name Inc.
123 Main Street
City, State 12345

Bill To:
Customer Name
456 Oak Avenue

Date: 2025-01-15
Due Date: 2025-02-15

Items:
Service 1    $500.00
Service 2    $750.00
Tax          $125.00
-----------------------
TOTAL        $1,375.00

☐ Check if paid
"""

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
except:
    font = ImageFont.load_default()

draw.text((50, 50), invoice_text, fill='black', font=font)
img.save('examples/sample_documents/test_invoice.png')
```

## Document Types to Test

### 1. Receipts
- Simple text structure
- Line items with prices
- Total calculation
- **Best for:** Basic OCR accuracy testing

### 2. Forms with Checkboxes
- Form fields
- Checkbox states (☐ unchecked, ☑ checked)
- **Best for:** Testing checkbox detection

### 3. Financial Documents
- Complex multi-row/column tables
- Merged cells
- Currency symbols
- **Best for:** Testing table extraction (use `--financial` flag)

### 4. Scientific Papers
- Mathematical equations (LaTeX)
- Charts and graphs
- References and citations
- **Best for:** Testing equation recognition

### 5. Handwritten Documents
- Handwritten notes
- Mixed handwriting and print
- **Best for:** Testing handwriting recognition

## Usage Examples

### Single Document
```bash
# General document
python scripts/nanonets-ocr-example.py --mode api --image examples/sample_documents/receipt.jpg

# Financial document
python scripts/nanonets-ocr-example.py --mode api --image examples/sample_documents/financial.jpg --financial
```

### Batch Processing
```bash
python examples/nanonets_ocr_inference.py
```

The script will automatically find and process all images in this directory.

## Tips for Best Results

1. **Resolution:** Higher resolution = better accuracy
   - Minimum: 800x600
   - Recommended: 1280x1024 or higher
   - Maximum: Limited by VRAM (32GB on RTX 5090 handles very large images)

2. **Image Quality:**
   - Good lighting, no shadows
   - No blur or motion artifacts
   - Straight orientation (not skewed)
   - Clear contrast between text and background

3. **File Size:**
   - JPEG: Prefer quality 90+ (less compression artifacts)
   - PNG: Lossless, ideal for text documents
   - PDF: First page only (for multi-page, extract pages separately)

4. **Document Types:**
   - For tables: Use `--financial` flag
   - For equations: Make sure symbols are clear
   - For forms: Ensure checkboxes are visible

## Current Contents

This directory will contain your test documents. The examples scripts will automatically:
- Find all `.jpg` and `.png` files
- Process them with appropriate settings
- Display OCR results

If no files are found, the scripts will show usage examples instead.

## Privacy Note

**Do not commit sensitive documents** to version control!

This directory is included in `.gitignore` to prevent accidentally committing:
- Personal information
- Financial records
- Confidential business documents

Always use public domain or synthetic test data for development.

