# vLLM OpenAI-Compatible API Setup

This setup provides a production-ready vLLM server that's compatible with OpenAI's API format. It follows a two-phase approach for security and can run with network restrictions.

## 🖥️ System Requirements

- **GPU**: RTX 5090 (32GB VRAM) ✅ Compatible!
- **OS**: Windows with WSL2 + Docker Desktop
- **CUDA**: 12.8+ (required for RTX 5090 Blackwell)
- **PyTorch**: 2.9.0+ (included in Docker image)

## 📁 Directory Structure

```
vllm/
├── docker-compose.yml          # Main Docker configuration
├── scripts/
│   ├── download-models.sh      # Phase 1: Download models
│   ├── test-api.sh             # Test the API
│   └── client-example.py       # Python client example
├── models/                     # Model cache (created automatically)
└── README-VLLM-API.md         # This file
```

## 🚀 Quick Start

### Phase 1: Download Models (With Network)

**In WSL2 terminal:**

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Download models (requires internet)
bash scripts/download-models.sh
```

This downloads models to `./models/` directory for offline use.

### Phase 2: Start the API Server

**Option A: With network access** (default):
```bash
docker-compose up -d
```

**Option B: Without network access** (production, after models downloaded):
1. Edit `docker-compose.yml`
2. Uncomment the line: `# network_mode: none`
3. Run:
```bash
docker-compose down
docker-compose up -d
```

### Test the API

```bash
# Test with curl
bash scripts/test-api.sh

# Test with Python
python scripts/client-example.py
```

## 🔧 Configuration

### Change Model

Edit `docker-compose.yml` and modify the `command` section:

```yaml
command: >
  --model YOUR_MODEL_HERE
  --host 0.0.0.0
  --port 8000
  --max-model-len 4096
  --gpu-memory-utilization 0.90
```

**Recommended models for RTX 5090 (32GB VRAM):**

| Model | Size | VRAM | Use Case |
|-------|------|------|----------|
| `facebook/opt-125m` | 125M | <1GB | Testing |
| `Qwen/Qwen2.5-1.5B-Instruct` | 1.5B | ~3GB | Fast responses |
| `meta-llama/Llama-3.2-3B-Instruct` | 3B | ~6GB | Balanced |
| `meta-llama/Llama-3.1-8B-Instruct` | 8B | ~16GB | High quality |
| `meta-llama/Llama-3.1-70B-Instruct` | 70B | ~140GB | Best quality (needs quantization) |

**For larger models on RTX 5090 (32GB):**

```yaml
command: >
  --model meta-llama/Llama-3.1-8B-Instruct
  --host 0.0.0.0
  --port 8000
  --max-model-len 8192
  --gpu-memory-utilization 0.95
  --quantization awq  # or fp8 for better performance
```

### vLLM Server Parameters

Common parameters you can add to `command:` section:

- `--max-model-len 4096` - Maximum context length
- `--gpu-memory-utilization 0.90` - GPU memory usage (0.0-1.0)
- `--tensor-parallel-size 1` - Number of GPUs for tensor parallelism
- `--quantization awq` - Enable quantization (awq, fp8, int4, int8)
- `--max-num-batched-tokens 8192` - Batch size for throughput
- `--max-num-seqs 256` - Max concurrent sequences
- `--enforce-eager` - Disable CUDA graphs (for debugging)
- `--disable-log-stats` - Disable statistics logging

## 📡 API Usage

### Using curl

**Chat completion:**
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

**Text completion:**
```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "prompt": "Once upon a time",
    "max_tokens": 100
  }'
```

### Using Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    api_key="EMPTY",
    base_url="http://localhost:8000/v1",
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3.2-3B-Instruct",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)
```

### Access from Windows (outside WSL2)

Since Docker Desktop bridges networks, you can access from Windows:

```python
# In Windows Python
client = OpenAI(
    api_key="EMPTY",
    base_url="http://localhost:8000/v1",  # Same URL!
)
```

## 🔍 Monitoring & Management

### View logs
```bash
docker-compose logs -f vllm-api
```

### Check status
```bash
docker-compose ps
```

### Restart server
```bash
docker-compose restart vllm-api
```

### Stop server
```bash
docker-compose down
```

### Update to latest vLLM
```bash
docker-compose pull
docker-compose up -d
```

## 🔒 Security & Privacy Features

✅ **No data leaves your system** - All inference runs locally  
✅ **Telemetry disabled** - `HF_HUB_DISABLE_TELEMETRY=1`  
✅ **Network isolation** - Can run with `network_mode: none` after model download  
✅ **Persistent model cache** - Models stored in `./models/` directory  

## 🐛 Troubleshooting

### Permission denied errors
```bash
# In WSL2
sudo chown -R $USER:$USER ./models
chmod -R u+rwX ./models
```

### GPU not detected
```bash
# Check GPU in WSL2
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.8-base nvidia-smi
```

### Out of memory errors
Reduce `--gpu-memory-utilization` in `docker-compose.yml`:
```yaml
--gpu-memory-utilization 0.80  # or lower
```

### Model download fails
```bash
# Authenticate with HuggingFace (for gated models like Llama)
pip install huggingface-hub
huggingface-cli login
```

### Container won't start
```bash
# Check logs
docker-compose logs vllm-api

# Verify Docker has GPU access
docker run --rm --gpus all vllm/vllm-openai:latest --help
```

## 📚 Additional Resources

- [vLLM Documentation](https://docs.vllm.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Supported Models](https://docs.vllm.ai/en/latest/models/supported_models.html)
- [vLLM Server Parameters](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html)

## 🎯 Example Use Cases

1. **Replace OpenAI API** - Drop-in replacement for development
2. **Private AI Assistant** - Run ChatGPT-like models locally
3. **Document Q&A** - Build RAG systems with local inference
4. **Batch Processing** - Process documents/data at high throughput
5. **AI Development** - Test and develop AI applications offline

## 💾 Backup & Portability

To backup your setup (excluding models):
```bash
tar -czf vllm-config-backup.tar.gz docker-compose.yml scripts/ README-VLLM-API.md
```

To backup everything including models:
```bash
tar -czf vllm-full-backup.tar.gz docker-compose.yml scripts/ models/ README-VLLM-API.md
```

## 🔄 Running Multiple Models

You can run multiple models simultaneously on different ports. Uncomment the `vllm-api-small` service in `docker-compose.yml` or add more services following the same pattern.

---

**Need help?** Check the [vLLM GitHub Issues](https://github.com/vllm-project/vllm/issues) or [vLLM Discussions](https://discuss.vllm.ai/)

