# 🚀 Quick Start Guide - vLLM OpenAI API

Get your private OpenAI-compatible API running in 5 minutes!

## Prerequisites Checklist

- ✅ Windows with WSL2 installed
- ✅ Docker Desktop running (with WSL2 backend)
- ✅ RTX 5090 GPU detected in WSL2 (`nvidia-smi` works)

## Step-by-Step Setup

### 1️⃣ Navigate to vLLM Directory

**In WSL2 terminal:**
```bash
cd ~/vllm  # or wherever you cloned this repo
```

### 2️⃣ Download Models (Phase 1 - With Network)

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Download models (takes 5-10 minutes depending on internet speed)
bash scripts/download-models.sh
```

**What this does:**
- Downloads 3 test models to `./models/` directory
- Creates offline marker for future use
- Models: opt-125m (~500MB), Qwen2.5-1.5B (~3GB), Llama-3.2-3B (~6GB)

**Note:** If downloading Llama models fails, you may need to:
```bash
pip install huggingface-hub
huggingface-cli login  # Enter your HF token
```

### 3️⃣ Start the API Server

```bash
# Start in background
docker-compose up -d

# View logs (Ctrl+C to exit, server keeps running)
docker-compose logs -f vllm-api
```

**Wait for:** `"Uvicorn running on http://0.0.0.0:8000"` in logs

### 4️⃣ Test the API

```bash
# Quick test
curl http://localhost:8000/health

# Full test suite
bash scripts/test-api.sh
```

### 5️⃣ Try the Python Client

```bash
# Install OpenAI SDK if needed
pip install openai

# Run example client
python scripts/client-example.py
```

## 🎉 Success!

If you see responses, your API is working! You now have:
- ✅ OpenAI-compatible API at `http://localhost:8000`
- ✅ Models running locally on your RTX 5090
- ✅ No data leaving your system
- ✅ Free unlimited inference

## Common Commands

```bash
# View server status
docker-compose ps

# Stop server
docker-compose down

# Restart server
docker-compose restart

# View logs
docker-compose logs -f vllm-api

# Update vLLM
docker-compose pull && docker-compose up -d
```

## Using Your API

### From Bash/PowerShell
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### From Python
```python
from openai import OpenAI

client = OpenAI(
    api_key="EMPTY",
    base_url="http://localhost:8000/v1"
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3.2-3B-Instruct",
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```

### From Windows Applications
Your API is accessible from Windows too! Use the same URL: `http://localhost:8000`

## Next Steps

- 📖 Read [README-VLLM-API.md](README-VLLM-API.md) for detailed documentation
- 🔧 Customize model in `docker-compose.yml`
- 🔒 Enable network restrictions (see README)
- 📊 Try different models (see model recommendations in README)

## Troubleshooting

**Server won't start?**
```bash
# Check Docker
docker ps

# Check GPU access
docker run --rm --gpus all nvidia/cuda:12.8-base nvidia-smi

# Check logs for errors
docker-compose logs vllm-api
```

**Out of memory?**
Edit `docker-compose.yml` and change:
```yaml
--gpu-memory-utilization 0.80  # Lower from 0.90
```

**Permission errors?**
```bash
sudo chown -R $USER:$USER ./models
```

## Performance Tips for RTX 5090

With 32GB VRAM, you can:
- Run 8B models easily
- Run 13B models with quantization
- Handle large batch sizes
- Use higher context lengths

Try this for better performance:
```yaml
command: >
  --model meta-llama/Llama-3.1-8B-Instruct
  --gpu-memory-utilization 0.95
  --max-model-len 8192
  --max-num-batched-tokens 16384
```

---

**Questions?** Check the main [README-VLLM-API.md](README-VLLM-API.md) for more details!

