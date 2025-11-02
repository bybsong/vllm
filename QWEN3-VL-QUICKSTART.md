# Qwen3-VL Quick Start

## One-Command Setup

```powershell
# 1. Download model (~60GB)
.\scripts\download-qwen3vl.ps1

# 2. Start service
docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway

# 3. Test it
.\scripts\test-qwen3vl.ps1

# 4. Switch to secure mode (optional)
.\scripts\switch-qwen3vl-to-production.ps1
```

## API Endpoint

```
http://localhost:8001/qwen3vl/v1/chat/completions
```

## Quick Test

```powershell
$request = @{
    model = "Qwen/Qwen3-VL-30B-A3B-Instruct"
    messages = @(@{role = "user"; content = "Hello!"})
    max_tokens = 50
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8001/qwen3vl/v1/chat/completions" `
    -Method Post -Body $request -ContentType "application/json"
```

## With Image

```powershell
$request = @{
    model = "Qwen/Qwen3-VL-30B-A3B-Instruct"
    messages = @(
        @{
            role = "user"
            content = @(
                @{type = "image_url"; image_url = @{url = "https://example.com/image.jpg"}}
                @{type = "text"; text = "What's in this image?"}
            )
        }
    )
    max_tokens = 200
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8001/qwen3vl/v1/chat/completions" `
    -Method Post -Body $request -ContentType "application/json"
```

## Key Stats

- **VRAM**: ~8-10GB (MoE efficiency!)
- **Context**: 32K tokens (expandable to 256K)
- **Speed**: High throughput due to MoE
- **Quality**: Full BF16 precision

## Comparison with Your Ollama Setup

| | Qwen3-VL (vLLM) | Qwen2.5-VL (Ollama) |
|-|-----------------|---------------------|
| **VRAM** | 8-10GB | 21GB |
| **Model** | Qwen3 (April 2025) | Qwen2.5 |
| **Context** | 256K | 128K |
| **Precision** | BF16 (full) | Q4_K_M (4-bit) |

## Common Commands

```powershell
# Check status
docker ps | Select-String "qwen3vl"

# View logs
docker logs -f vllm-qwen3vl

# Check GPU memory
docker exec vllm-qwen3vl nvidia-smi

# Restart
docker-compose --profile qwen3vl restart vllm-qwen3vl

# Stop
docker-compose --profile qwen3vl stop vllm-qwen3vl
```

## Troubleshooting

**Service won't start?**
- Check logs: `docker logs vllm-qwen3vl`
- Verify model downloaded: Check `./models/Qwen--Qwen3-VL-30B-A3B-Instruct/` exists

**Out of memory?**
- Qwen3-VL MoE should only use 8-10GB
- Check: `docker exec vllm-qwen3vl nvidia-smi`
- If needed, lower `--gpu-memory-utilization` in docker-compose.yml

**API not responding?**
- Verify service running: `docker ps | Select-String "qwen3vl"`
- Check health: `curl http://localhost:8001/health/qwen3vl`

## Full Documentation

See `SETUP-QWEN3-VL.md` for complete setup guide.

