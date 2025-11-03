# Qwen3-VL-4B Mode Switching Guide

You now have **TWO configurations** for Qwen3-VL-4B that you can switch between depending on your use case.

## Configuration Comparison

| Feature | **Standalone Mode** | **Shared Mode** |
|---------|---------------------|-----------------|
| **Profile** | `qwen3vl-4b` | `qwen3vl-4b-shared` |
| **VRAM Usage** | ~24GB (75% util) | ~16GB (50% util) |
| **Context Length** | 8K tokens | 4K tokens |
| **Concurrent Requests** | 3 | 2 |
| **Batch Size** | 8192 tokens | 4096 tokens |
| **Use Case** | Running alone, max performance | Running with marker container |
| **Compatible with Marker?** | ❌ No (not enough VRAM) | ✅ Yes (leaves 16GB free) |

## Quick Commands

### Start Standalone Mode (High Performance)
```powershell
# Stop any running instance first
docker-compose stop vllm-qwen3vl-4b

# Start standalone mode
docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b

# Verify
docker exec vllm-qwen3vl-4b nvidia-smi
```
**Expected VRAM**: ~20-24GB

---

### Start Shared Mode (For Use with Marker)
```powershell
# Stop any running instance first
docker-compose stop vllm-qwen3vl-4b

# Start shared mode
docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared

# Verify
docker exec vllm-qwen3vl-4b nvidia-smi
```
**Expected VRAM**: ~14-18GB

---

### Check Current Mode
```powershell
# See which container is running and its memory usage
docker ps | Select-String "qwen3vl-4b"
docker exec vllm-qwen3vl-4b nvidia-smi
```

---

## Switching Between Modes

### Important Notes
- **Both services use the same container name** (`vllm-qwen3vl-4b`)
- **You CANNOT run both at the same time** (they conflict)
- **Always stop the current one before starting the other**

### Switch from Standalone → Shared
```powershell
# Stop standalone
docker-compose --profile qwen3vl-4b down

# Start shared
docker-compose --profile qwen3vl-4b-shared up -d

# Wait for startup (~30-60 seconds)
docker logs -f vllm-qwen3vl-4b
```

### Switch from Shared → Standalone
```powershell
# Stop shared
docker-compose --profile qwen3vl-4b-shared down

# Start standalone
docker-compose --profile qwen3vl-4b up -d

# Wait for startup (~30-60 seconds)
docker logs -f vllm-qwen3vl-4b
```

---

## Use Case Scenarios

### Scenario 1: Using Qwen3-VL-4B Alone
**Use**: **Standalone Mode** (`qwen3vl-4b`)

**Why**: Maximum performance, full context length, more concurrent requests

**Commands**:
```powershell
docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b
```

---

### Scenario 2: Using Qwen3-VL-4B + Marker Together
**Use**: **Shared Mode** (`qwen3vl-4b-shared`)

**Why**: Leaves enough VRAM for marker (5-6GB) + working memory (8GB)

**Commands**:
```powershell
# Start Qwen3-VL-4B in shared mode
docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared

# Start marker (adjust command based on your setup)
docker-compose up -d marker  # or your marker startup command

# Verify both are running
nvidia-smi
```

**Expected Total VRAM**: ~28-30GB (fits in 32GB!)

---

### Scenario 3: Testing/Comparing Performance
**Use**: Switch between both to test

**Commands**:
```powershell
# Test standalone first
docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b
# ... run your tests ...
docker exec vllm-qwen3vl-4b nvidia-smi  # Note memory usage

# Switch to shared
docker-compose --profile qwen3vl-4b down
docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared
# ... run your tests ...
docker exec vllm-qwen3vl-4b nvidia-smi  # Compare memory usage
```

---

## VRAM Allocation Details

### Standalone Mode (75% utilization)
```
Model Weights:           10-12 GB
KV Cache (3 req × 8K):    8-10 GB
Temp Buffers:             2-3 GB
─────────────────────────────────
TOTAL:                   20-25 GB
FREE for other tasks:     7-12 GB
```

### Shared Mode (50% utilization)
```
Model Weights:           10-12 GB
KV Cache (2 req × 4K):    3-4 GB
Temp Buffers:             1-2 GB
─────────────────────────────────
TOTAL:                   14-18 GB
FREE for marker:          14-18 GB
```

---

## Performance Impact of Shared Mode

### What You Lose
- **50% shorter context**: 4K vs 8K tokens
  - Still enough for: Image + moderate text prompt
  - May be tight for: Image + very long instructions

- **33% fewer concurrent requests**: 2 vs 3
  - Impact: Slightly lower throughput under heavy load
  - Not noticeable: For single-user or low-traffic use

- **Smaller batch sizes**: 4096 vs 8192 tokens
  - Impact: Small latency increase per request
  - Typically: <10% slower

### What You Keep
- ✅ Full BF16 precision (no quality loss)
- ✅ Vision capabilities (unchanged)
- ✅ Prefix caching (speed optimization)
- ✅ Fast inference (still optimized)
- ✅ All model features intact

---

## Troubleshooting

### Error: "Container name already exists"
**Cause**: Previous container still running

**Fix**:
```powershell
docker-compose stop vllm-qwen3vl-4b
# Or force remove:
docker rm -f vllm-qwen3vl-4b
```

### Error: "Out of Memory (OOM)" in Shared Mode
**Cause**: Marker or other processes using too much VRAM

**Fix**:
```powershell
# Check what's using GPU
nvidia-smi

# Option 1: Reduce further
# Edit docker-compose.yml, change shared mode to:
# --gpu-memory-utilization 0.45

# Option 2: Stop other GPU processes
docker stop <other-container>
```

### Shared Mode Still Using 24GB
**Cause**: Started wrong profile

**Fix**:
```powershell
# Make sure you're using the right profile
docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared
# NOT:
# docker-compose --profile qwen3vl-4b up -d
```

---

## API Access

Both modes use the **same endpoint** (no API changes needed):

```
http://localhost:8005/v1/chat/completions
```

Your client code doesn't need to change when switching modes!

---

## Monitoring Commands

```powershell
# Check GPU memory usage
nvidia-smi

# Check which mode is running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | Select-String "qwen3vl"

# View logs
docker logs -f vllm-qwen3vl-4b

# Check vLLM metrics
curl http://localhost:8005/metrics

# Test health
curl http://localhost:8005/health
```

---

## Recommendations

### For Daily Use
- **Use Shared Mode by default** if you often run marker
- Only switch to standalone when you need maximum performance

### For Development/Testing
- **Use Standalone Mode** for faster iteration
- Switch to shared mode before running full pipelines

### For Production
- **Use Shared Mode** if both services are needed
- Monitor actual VRAM usage and adjust if needed
- Consider running them on separate schedules if possible

---

## Summary

✅ **Standalone Mode**: 24GB VRAM, 8K context, 3 concurrent requests, maximum performance  
✅ **Shared Mode**: 16GB VRAM, 4K context, 2 concurrent requests, marker-compatible  
✅ **Easy Switching**: Just stop one profile and start the other  
✅ **Same API**: No code changes needed  
✅ **Same Container Name**: Only one can run at a time  

Both modes use the exact same model and maintain full quality (BF16 precision) - the only differences are memory allocation and capacity limits.

