# Nanonets-OCR2-3B with vLLM - Enterprise Deployment

**Production-grade OCR service following vLLM official deployment patterns.**

## 🎯 Overview

This setup deploys Nanonets-OCR2-3B (a state-of-the-art vision-language model for OCR) using vLLM's recommended enterprise architecture with:

- ✅ **Gateway pattern** (Nginx load balancer)
- ✅ **Network isolation** (Docker internal networks)
- ✅ **Volume-based model storage** (separate download/serve)
- ✅ **Zero internet access** in production (architecture-enforced)
- ✅ **OpenAI-compatible API** (drop-in replacement)

## 🏗️ Architecture

```
External Access (Port 8001)
        ↓
┌───────────────────────┐
│  Nginx Gateway        │  ← Load balancer, health checks
│  (Port 80 internal)   │
└───────┬───────────────┘
        │ vllm-internal (no internet)
        ↓
┌───────────────────────┐
│  vLLM Nanonets-OCR    │  ← NO exposed ports
│  (Port 8000 internal) │  ← NO internet access
└───────┬───────────────┘
        │ Volume mount
        ↓
┌───────────────────────┐
│  ./models/            │  ← Persistent storage
│  (6-8GB model)        │
└───────────────────────┘
```

**Key Features:**
- vLLM never has internet access (Docker-enforced)
- Single external access point (nginx gateway)
- Model downloaded separately (one-time setup)
- Can scale to multiple vLLM replicas

See `ARCHITECTURE.md` for detailed design documentation.

## 🖥️ System Requirements

- **GPU**: NVIDIA GPU with 8GB+ VRAM (optimized for RTX 5090 32GB)
- **OS**: Linux, WSL2, or macOS with Docker
- **Docker**: 20.10+ with nvidia-container-toolkit
- **Storage**: ~10GB for model + Docker images
- **CUDA**: 12.0+ (included in Docker image)

## 🚀 Quick Start

### One-Command Setup (Recommended)

**Linux/WSL2:**
```bash
chmod +x scripts/setup-nanonets.sh
./scripts/setup-nanonets.sh
```

**PowerShell:**
```powershell
.\scripts\setup-nanonets.ps1
```

This will:
1. Create necessary directories
2. Download the model (6-8GB, ~10-20 min)
3. Start vLLM and nginx services
4. Verify everything is working

### Manual Setup

```bash
# 1. Download model (one-time, ~10-20 minutes)
docker-compose --profile setup up model-downloader

# 2. Start services
docker-compose up -d vllm-nanonets-ocr nginx-gateway

# 3. Wait for model to load (~30-60 seconds)
docker-compose logs -f vllm-nanonets-ocr
# Wait for: "Application startup complete"

# 4. Test
curl http://localhost:8001/health
```

## 📖 Usage Examples

### Python Client (Recommended)

```python
from openai import OpenAI
import base64

# Connect to vLLM via nginx gateway
client = OpenAI(
    api_key="not-used",
    base_url="http://localhost:8001/v1"
)

# Read and encode image
with open("document.jpg", "rb") as f:
    image_data = base64.b64encode(f.read()).decode("utf-8")

# OCR the document
response = client.chat.completions.create(
    model="nanonets/Nanonets-OCR2-3B",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}},
            {"type": "text", "text": "Convert this document to markdown. Output only the markdown, no additional text."}
        ]
    }],
    temperature=0.0,
    max_tokens=15000
)

print(response.choices[0].message.content)
```

### Command Line Scripts

```bash
# Simple OCR
python scripts/nanonets-ocr-example.py --image invoice.jpg

# Financial documents (more accurate for numbers)
python scripts/nanonets-ocr-example.py --image receipt.pdf --financial

# Multi-page PDF
python scripts/ocr-multipage-pdf.py large_document.pdf --output result.md
```

### From LlamaIndex Container

```python
# 1. Connect networks (one-time)
# docker network connect llamaindex_default vllm-nginx-gateway

# 2. Use in your LlamaIndex code
from openai import OpenAI

client = OpenAI(
    api_key="not-used",
    base_url="http://vllm-nginx-gateway/v1"  # Gateway container name
)

# OCR as usual...
```

See `examples/llamaindex_ocr_integration.py` for complete integration example.

### curl Examples

```bash
# Health check
curl http://localhost:8001/health

# List models
curl http://localhost:8001/v1/models

# OCR request (with base64 image)
curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nanonets/Nanonets-OCR2-3B",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,'$(base64 -w 0 document.jpg)'"}},
        {"type": "text", "text": "Convert to markdown"}
      ]
    }],
    "temperature": 0.0,
    "max_tokens": 15000
  }'
```

## 🔧 Configuration

### vLLM Settings

Edit `docker-compose.yml` under `vllm-nanonets-ocr` service:

```yaml
command: >
  --model nanonets/Nanonets-OCR2-3B
  --max-model-len 15000          # Max tokens (adjust for longer docs)
  --gpu-memory-utilization 0.90  # GPU memory % (adjust based on other workloads)
  --max-num-seqs 5               # Concurrent requests (increase for higher throughput)
  --trust-remote-code            # Required for this model
  --enforce-eager                # Disable cudagraph (more stable)
```

### Nginx Settings

Edit `nginx-config/nginx.conf`:

```nginx
# Timeouts
proxy_read_timeout 300s;  # Increase for large documents

# Max upload size
client_max_body_size 50M;  # Increase for large PDFs

# Add more backends for load balancing
upstream vllm_backend {
    server vllm-nanonets-ocr:8000;
    # server vllm-nanonets-ocr-2:8000;  # Add more replicas
}
```

## 🔒 Security

### Network Isolation

The vLLM container **cannot** access the internet:

```bash
# This will FAIL (good - no internet)
docker exec vllm-nanonets-ocr ping -c 1 8.8.8.8

# This will SUCCEED (container-to-container communication)
docker exec nginx-gateway curl http://vllm-nanonets-ocr:8000/health
```

**How it works:**
- `vllm-internal` network has `internal: true` (Docker-enforced)
- Only nginx gateway is exposed to host
- Model loaded from persistent volume (no download needed)
- Telemetry disabled

### Why This is Secure

| Aspect | Our Setup | Why Secure |
|--------|-----------|------------|
| Internet | vLLM has NO access | Docker network isolation (`internal: true`) |
| Ports | vLLM has NO exposed ports | Only accessible via nginx |
| Model Downloads | Separate container | vLLM never needs internet |
| Data Leakage | Impossible | No outbound connections possible |
| Telemetry | Disabled | `HF_HUB_DISABLE_TELEMETRY=1` |

## 📊 Performance

### Hardware Utilization

- **GPU Memory**: ~7-8GB for model
- **System RAM**: ~4-6GB
- **Throughput**: ~5-10 pages/minute (depends on document complexity)
- **Latency**: 2-10 seconds per page

### Optimization Tips

1. **Increase GPU memory** for better throughput:
   ```yaml
   --gpu-memory-utilization 0.95  # From 0.90
   ```

2. **Increase concurrent requests**:
   ```yaml
   --max-num-seqs 10  # From 5
   ```

3. **Use multiple GPUs** (if available):
   ```yaml
   --tensor-parallel-size 2
   ```

4. **Add vLLM replicas** for load balancing:
   See "Scaling" section in `ARCHITECTURE.md`

## 📝 Common Tasks

```bash
# View logs
docker-compose logs -f vllm-nanonets-ocr
docker-compose logs -f nginx-gateway

# Restart services
docker-compose restart vllm-nanonets-ocr
docker-compose restart nginx-gateway

# Stop services
docker-compose down

# Update model
docker-compose down vllm-nanonets-ocr
rm -rf models/nanonets--Nanonets-OCR2-3B
docker-compose --profile setup up model-downloader
docker-compose up -d vllm-nanonets-ocr nginx-gateway

# Check resource usage
docker stats vllm-nanonets-ocr

# Check GPU usage
nvidia-smi -l 1
```

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker-compose logs vllm-nanonets-ocr

# Common issues:

# 1. Model not downloaded
docker-compose --profile setup up model-downloader

# 2. GPU not available
nvidia-smi

# 3. Out of memory
# Edit docker-compose.yml: --gpu-memory-utilization 0.80
```

### Health Check Fails

```bash
# Model loading takes time (30-60 seconds)
docker-compose logs -f vllm-nanonets-ocr | grep "Application startup complete"

# Once you see "Application startup complete", test:
curl http://localhost:8001/health
```

### OCR Quality Issues

```python
# 1. Use temperature=0.0 for consistent output
temperature=0.0

# 2. For financial documents, use specific prompt
"Extract all text including numbers, tables, and amounts. Preserve exact formatting."

# 3. Increase max_tokens for long documents
max_tokens=20000  # From 15000

# 4. Use higher DPI for scanned documents
# When converting PDF to images, use DPI=300
```

### Can't Access from Container

```bash
# Connect your container's network to vLLM gateway
docker network connect your_network_name vllm-nginx-gateway

# Test from your container
docker exec your_container curl http://vllm-nginx-gateway/health
```

## 📚 Documentation

- **Architecture**: `ARCHITECTURE.md` - Detailed design and rationale
- **Quick Start**: `QUICKSTART-NEW.md` - Fast setup guide
- **Migration**: `MIGRATION-GUIDE.md` - Upgrading from old setup
- **API Reference**: Standard OpenAI API format
- **Examples**: `examples/` directory

## 🔄 Comparison with Old Setup

Migrating from the toggle-based setup? See `MIGRATION-GUIDE.md`.

| Aspect | Old Setup | New Setup |
|--------|-----------|-----------|
| **Pattern** | Custom/manual | vLLM official |
| **Security** | Manual toggle | Architecture-enforced |
| **Internet** | Toggle required | Never accessible |
| **Ports** | vLLM exposed | Only nginx exposed |
| **Scaling** | Single container | Multi-replica ready |
| **Maintenance** | Remember to toggle | Zero manual steps |

## 🎓 Model Information

**Nanonets-OCR2-3B** is a fine-tuned Qwen2.5-VL-3B-Instruct model optimized for:

- ✅ Document OCR (invoices, receipts, forms)
- ✅ Mathematical notation (LaTeX)
- ✅ Tables and structured data
- ✅ Handwriting recognition
- ✅ Multiple languages
- ✅ Checkboxes and signatures
- ✅ Watermark handling

**Model Card:** https://huggingface.co/nanonets/Nanonets-OCR2-3B

## 🤝 Integration Examples

### LlamaIndex RAG Pipeline

```python
from examples.llamaindex_ocr_integration import ocr_pdf_with_vllm, create_documents_from_ocr

# OCR a PDF
ocr_text = ocr_pdf_with_vllm("document.pdf")

# Create LlamaIndex documents
documents = create_documents_from_ocr(ocr_text, source="document.pdf")

# Use in RAG pipeline
from llama_index.core import VectorStoreIndex
index = VectorStoreIndex.from_documents(documents)
```

### FastAPI Service

```python
from fastapi import FastAPI, UploadFile
from openai import OpenAI

app = FastAPI()
client = OpenAI(api_key="x", base_url="http://vllm-nginx-gateway/v1")

@app.post("/ocr")
async def ocr_endpoint(file: UploadFile):
    content = await file.read()
    image_data = base64.b64encode(content).decode()
    # ... OCR logic ...
    return {"text": ocr_result}
```

## 📄 License

- **vLLM**: Apache 2.0
- **Nanonets-OCR2-3B**: Check model card on Hugging Face
- **This setup**: Use freely

## 🙏 Credits

- **vLLM Team**: For excellent inference engine and documentation
- **Nanonets**: For the OCR model
- **Qwen Team**: For base vision-language model

## 📞 Support

1. Check `ARCHITECTURE.md` for design questions
2. Check `MIGRATION-GUIDE.md` if upgrading
3. Review `docker-compose logs` for errors
4. Check vLLM documentation: https://docs.vllm.ai
5. Model issues: https://huggingface.co/nanonets/Nanonets-OCR2-3B

---

**Ready to get started?** Run `./scripts/setup-nanonets.sh` and you'll be OCR-ing in minutes! 🚀

