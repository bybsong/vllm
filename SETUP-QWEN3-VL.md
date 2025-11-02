# Qwen3-VL-30B-A3B Setup Guide

## Overview

This guide covers the setup of **Qwen3-VL-30B-A3B-Instruct**, the latest-generation vision-language model from Qwen with MoE (Mixture of Experts) architecture.

### Model Specifications

- **Model**: Qwen/Qwen3-VL-30B-A3B-Instruct
- **Architecture**: MoE with 30.5B total parameters, only **3.3B active**
- **VRAM Usage**: ~8-10GB (extremely efficient due to MoE)
- **Context Length**: 32K native, extendable to 256K-1M tokens
- **Capabilities**: 
  - Vision-language understanding
  - Video analysis
  - Visual agent (GUI interaction)
  - Advanced OCR (32 languages)
  - Spatial reasoning
  - Visual coding (HTML/CSS/JS from images)

### Why Qwen3-VL vs Qwen2.5-VL?

✅ **3x more memory efficient**: 8-10GB vs 32GB VRAM  
✅ **Better performance**: Latest April 2025 release  
✅ **No quantization needed**: Full BF16 precision  
✅ **More features**: Visual agent, enhanced spatial reasoning  
✅ **Longer context**: 256K vs 32K tokens  

## Prerequisites

- Docker Desktop with WSL2 backend
- NVIDIA RTX 5090 GPU (32GB VRAM) - verified compatible
- ~70GB free disk space (60GB model + overhead)
- Stable internet connection for initial download

## Setup Instructions

### Step 1: Download the Model

Run the download script to fetch Qwen3-VL-30B-A3B-Instruct from HuggingFace:

```powershell
.\scripts\download-qwen3vl.ps1
```

**What it does:**
- Downloads ~60GB model to `./models/Qwen--Qwen3-VL-30B-A3B-Instruct/`
- Creates offline marker for production mode
- Verifies download completion

**Note**: Download can be resumed if interrupted. Just run the script again.

### Step 2: Start the Service

Start the Qwen3-VL service with Docker Compose:

```powershell
docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway
```

**What happens:**
- Starts vLLM container with Qwen3-VL model
- Uses default network (allows internet for first run)
- Exposes API via NGINX gateway at `http://localhost:8001/qwen3vl/v1/`
- GPU will allocate ~8-10GB VRAM

### Step 3: Verify the Service

Check logs to ensure the model loaded successfully:

```powershell
docker logs -f vllm-qwen3vl
```

Look for:
- `Loading model weights from...`
- `Model loaded successfully`
- `Server listening on 0.0.0.0:8000`

Check GPU memory usage:

```powershell
docker exec vllm-qwen3vl nvidia-smi
```

Expected VRAM usage: ~8-10GB (MoE efficiency!)

### Step 4: Test the API

Run the test script to verify vision-language capabilities:

```powershell
.\scripts\test-qwen3vl.ps1
```

**Tests performed:**
1. Health check
2. Model info
3. Text completion
4. Vision-language completion (with image)

### Step 5: Switch to Production Mode (Optional)

After verifying everything works, switch to secure offline mode:

```powershell
.\scripts\switch-qwen3vl-to-production.ps1
```

**What it does:**
- Disconnects from internet (secure)
- Enables offline mode
- Restarts service with network isolation

## API Usage

### Endpoint

```
http://localhost:8001/qwen3vl/v1/chat/completions
```

### Example: Text Completion

```powershell
$request = @{
    model = "Qwen/Qwen3-VL-30B-A3B-Instruct"
    messages = @(
        @{
            role = "user"
            content = "Explain quantum computing in simple terms."
        }
    )
    max_tokens = 500
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8001/qwen3vl/v1/chat/completions" -Method Post -Body $request -ContentType "application/json"
```

### Example: Image Analysis

```powershell
$request = @{
    model = "Qwen/Qwen3-VL-30B-A3B-Instruct"
    messages = @(
        @{
            role = "user"
            content = @(
                @{
                    type = "image_url"
                    image_url = @{
                        url = "https://example.com/image.jpg"
                    }
                }
                @{
                    type = "text"
                    text = "What's in this image?"
                }
            )
        }
    )
    max_tokens = 200
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8001/qwen3vl/v1/chat/completions" -Method Post -Body $request -ContentType "application/json"
```

### Example: Local Image (Base64)

```powershell
$imageBytes = [System.IO.File]::ReadAllBytes("path\to\image.jpg")
$base64Image = [Convert]::ToBase64String($imageBytes)

$request = @{
    model = "Qwen/Qwen3-VL-30B-A3B-Instruct"
    messages = @(
        @{
            role = "user"
            content = @(
                @{
                    type = "image_url"
                    image_url = @{
                        url = "data:image/jpeg;base64,$base64Image"
                    }
                }
                @{
                    type = "text"
                    text = "Describe this image in detail."
                }
            )
        }
    )
    max_tokens = 300
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8001/qwen3vl/v1/chat/completions" -Method Post -Body $request -ContentType "application/json"
```

## Comparison with Ollama

You're currently running `qwen2.5vl:32b` in Ollama. Here's how they compare:

| Feature | Qwen3-VL (vLLM) | Qwen2.5-VL (Ollama) |
|---------|-----------------|---------------------|
| **Parameters** | 30.5B (3.3B active) | 33.5B |
| **VRAM Usage** | ~8-10GB | ~21GB (Q4_K_M) |
| **Generation** | Qwen3 (April 2025) | Qwen2.5 |
| **Context Length** | 256K (expandable to 1M) | 128K |
| **Quantization** | None (full BF16) | Q4_K_M (4-bit) |
| **API Format** | OpenAI-compatible | Ollama format |
| **Performance** | Higher throughput | Standard |
| **Features** | Visual agent, spatial reasoning | Standard VL |

**vLLM advantages:**
- ✅ Better performance and throughput
- ✅ OpenAI-compatible API
- ✅ Latest model generation
- ✅ Full precision (no quantization loss)
- ✅ Integrated with existing pipeline

## Monitoring & Maintenance

### Check Service Status

```powershell
docker ps | Select-String "qwen3vl"
```

### View Logs

```powershell
docker logs -f vllm-qwen3vl
```

### Check GPU Usage

```powershell
docker exec vllm-qwen3vl nvidia-smi
```

### Restart Service

```powershell
docker-compose --profile qwen3vl restart vllm-qwen3vl
```

### Stop Service

```powershell
docker-compose --profile qwen3vl stop vllm-qwen3vl
```

## Troubleshooting

### Model Download Issues

**Problem**: Download interrupted or failed  
**Solution**: Run `.\scripts\download-qwen3vl.ps1` again - it will resume

**Problem**: Out of disk space  
**Solution**: Ensure 70GB free space available

### Service Startup Issues

**Problem**: Container exits immediately  
**Solution**: Check logs - `docker logs vllm-qwen3vl` - likely missing model

**Problem**: CUDA out of memory  
**Solution**: Lower `--gpu-memory-utilization` to 0.65 or 0.60 in docker-compose.yml

### API Issues

**Problem**: Connection refused  
**Solution**: Check service is running - `docker ps | Select-String "qwen3vl"`

**Problem**: Slow responses  
**Solution**: Check GPU usage - may need to reduce batch size (`--max-num-seqs`)

## Advanced Configuration

### Increase Context Length

Edit `docker-compose.yml`, change:

```yaml
--max-model-len 32768
```

To:

```yaml
--max-model-len 65536  # or higher up to 256K
```

Note: Higher context = more VRAM usage

### Increase Batch Size

For more concurrent requests:

```yaml
--max-num-seqs 16  # default is 8
```

### Enable CUDA Graphs (Better Performance)

Remove `--enforce-eager` flag in docker-compose.yml after verifying stability.

## Integration Examples

### Python Client

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8001/qwen3vl/v1",
    api_key="dummy"  # not required but OpenAI client needs it
)

# Text completion
response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-30B-A3B-Instruct",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)
print(response.choices[0].message.content)

# Image analysis
response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-30B-A3B-Instruct",
    messages=[
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}},
                {"type": "text", "text": "Describe this image"}
            ]
        }
    ]
)
print(response.choices[0].message.content)
```

### LlamaIndex Integration

The service is accessible from LlamaIndex via the `llamaindex_internal` network.

```python
from llama_index.llms.openai_like import OpenAILike

llm = OpenAILike(
    model="Qwen/Qwen3-VL-30B-A3B-Instruct",
    api_base="http://vllm-qwen3vl:8000/v1",
    api_key="dummy",
    is_chat_model=True,
)
```

## References

- [Qwen3-VL Model Card](https://huggingface.co/Qwen/Qwen3-VL-30B-A3B-Instruct)
- [Qwen3 Technical Report](https://arxiv.org/abs/2505.09388)
- [vLLM Documentation](https://docs.vllm.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference/chat)

## Support

For issues specific to:
- **Model**: Check [Qwen3-VL GitHub](https://github.com/QwenLM/Qwen3)
- **vLLM**: Check [vLLM GitHub](https://github.com/vllm-project/vllm)
- **This setup**: Review logs and configuration files

