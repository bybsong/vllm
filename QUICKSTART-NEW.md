# Nanonets-OCR2-3B with vLLM - Quick Start

## 🚀 30-Second Start (If Model Already Downloaded)

```bash
# Start everything
docker-compose up -d vllm-nanonets-ocr nginx-gateway

# Wait 30 seconds for model loading, then test
curl http://localhost:8001/health
```

## 📦 Complete Setup (First Time)

### Option 1: Automated Setup (Recommended)

**Linux/WSL2:**
```bash
chmod +x scripts/setup-nanonets.sh
./scripts/setup-nanonets.sh
```

**PowerShell:**
```powershell
.\scripts\setup-nanonets.ps1
```

### Option 2: Manual Setup

```bash
# 1. Download model (6-8GB, ~10-20 minutes)
docker-compose --profile setup up model-downloader

# 2. Start serving containers
docker-compose up -d vllm-nanonets-ocr nginx-gateway

# 3. Wait for model to load (~30-60 seconds)
# Watch logs:
docker-compose logs -f vllm-nanonets-ocr

# 4. Test health
curl http://localhost:8001/health
```

## ✅ Verify Setup

```bash
# Check containers are running
docker-compose ps

# Check health
curl http://localhost:8001/health

# Verify security (should FAIL - no internet)
docker exec vllm-nanonets-ocr ping -c 1 8.8.8.8
```

## 🎯 Usage Examples

### From Host Machine (Windows/Linux)

```bash
# Simple OCR test
python scripts/nanonets-ocr-example.py --image your_document.jpg

# Financial document (more accurate for numbers)
python scripts/nanonets-ocr-example.py --image invoice.pdf --financial

# Multi-page PDF
python scripts/ocr-multipage-pdf.py input.pdf --output result.md
```

### From LlamaIndex Container

```bash
# 1. Connect networks
docker network connect llamaindex_default vllm-nginx-gateway

# 2. In your LlamaIndex code
api_base = "http://vllm-nginx-gateway/v1"
```

See `examples/llamaindex_ocr_integration.py` for complete example.

## 🏗️ Architecture

```
Your Application
      ↓
http://localhost:8001 (nginx gateway - only exposed port)
      ↓
vllm-nanonets-ocr (internal, no internet, no exposed ports)
      ↓
./models/ (persistent disk storage)
```

**Key Security Features:**
- ✅ vLLM container has NO internet access (architecture-enforced)
- ✅ vLLM container has NO exposed ports
- ✅ Model loaded from persistent volume (no downloads during serving)
- ✅ Only nginx gateway accessible from outside

## 📝 Common Commands

```bash
# Start services
docker-compose up -d vllm-nanonets-ocr nginx-gateway

# Stop services
docker-compose down

# View logs
docker-compose logs -f vllm-nanonets-ocr
docker-compose logs -f nginx-gateway

# Restart vLLM (model changes, etc.)
docker-compose restart vllm-nanonets-ocr

# Check resource usage
docker stats vllm-nanonets-ocr
```

## 🔧 Configuration

Edit `docker-compose.yml` to adjust:

```yaml
services:
  vllm-nanonets-ocr:
    command: >
      --model nanonets/Nanonets-OCR2-3B
      --max-model-len 15000          # Adjust for longer documents
      --gpu-memory-utilization 0.90  # Adjust GPU memory usage
      --max-num-seqs 5               # Concurrent requests
```

## 🚨 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker-compose logs vllm-nanonets-ocr

# Common issues:
# 1. Model not downloaded
docker-compose --profile setup up model-downloader

# 2. GPU not available
nvidia-smi  # Check GPU is detected

# 3. Out of memory
# Reduce --gpu-memory-utilization in docker-compose.yml
```

### Health Check Fails

```bash
# Wait longer (model loading takes 30-60 seconds)
docker-compose logs -f vllm-nanonets-ocr | grep "Application startup complete"

# Once you see "Application startup complete", test again
curl http://localhost:8001/health
```

### Can't Connect from LlamaIndex

```bash
# Ensure networks are connected
docker network connect llamaindex_default vllm-nginx-gateway

# Test from inside llamaindex container
docker exec llamaindex-rag curl http://vllm-nginx-gateway/health
```

## 📚 Next Steps

- **Read Architecture:** See `ARCHITECTURE.md` for detailed design
- **Examples:** Check `examples/` directory
- **API Reference:** See `README-VLLM-API.md`
- **LlamaIndex Integration:** See `examples/llamaindex_ocr_integration.py`

## 🔄 Updating the Model

```bash
# 1. Stop serving
docker-compose down vllm-nanonets-ocr

# 2. Remove old model
rm -rf models/nanonets--Nanonets-OCR2-3B

# 3. Download fresh
docker-compose --profile setup up model-downloader

# 4. Restart
docker-compose up -d vllm-nanonets-ocr nginx-gateway
```

## ⚖️ Old vs New Setup

If you used the old toggle-based setup:

| Old Way | New Way |
|---------|---------|
| `switch-to-production.ps1` | Not needed - always secure |
| Port 8001 → vLLM directly | Port 8001 → nginx → vLLM |
| Manual network toggle | Automatic isolation |
| Internet toggle scripts | NO internet ever |

The new setup is **always** in production mode with full security!

