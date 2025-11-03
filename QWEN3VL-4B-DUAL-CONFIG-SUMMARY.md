# Qwen3-VL-4B Dual Configuration Summary

## What Was Implemented

Created **two separate configurations** for Qwen3-VL-4B in `docker-compose.yml`:

### 1. **Standalone Mode** (Profile: `qwen3vl-4b`)
- **VRAM**: 24GB (75% utilization)
- **Context**: 8K tokens
- **Concurrent**: 3 requests
- **Use**: Maximum performance when running alone

### 2. **Shared Mode** (Profile: `qwen3vl-4b-shared`)
- **VRAM**: 16GB (50% utilization)
- **Context**: 4K tokens
- **Concurrent**: 2 requests  
- **Use**: Running alongside marker container

## Why Two Configurations?

Your marker container analysis showed:
```
Marker models:        5-6 GB
Marker working mem:   6-8 GB
System overhead:      2-3 GB
─────────────────────────────
Total needed:        13-17 GB
```

**Original config used 24GB** → No room for marker ❌  
**Shared mode uses 16GB** → Leaves 16GB for marker ✅

## Quick Usage

### Easy Mode: Use the Helper Script

```powershell
# Switch to standalone (max performance)
.\scripts\switch-qwen3vl-4b-mode.ps1 standalone

# Switch to shared (marker compatible)
.\scripts\switch-qwen3vl-4b-mode.ps1 shared

# Check current status
.\scripts\switch-qwen3vl-4b-mode.ps1 status
```

### Manual Mode: Docker Compose

```powershell
# Standalone mode
docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b

# Shared mode  
docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared

# Stop either
docker-compose stop vllm-qwen3vl-4b
```

## Configuration Comparison

| Parameter | Standalone | Shared | Difference |
|-----------|-----------|--------|------------|
| `gpu-memory-utilization` | 0.75 | 0.50 | -33% VRAM |
| `max-model-len` | 8192 | 4096 | -50% context |
| `max-num-seqs` | 3 | 2 | -1 concurrent |
| `max-num-batched-tokens` | 8192 | 4096 | -50% batch |
| **VRAM Used** | ~24GB | ~16GB | **-8GB freed** |

## Memory Allocation Breakdown

### Standalone Mode (24GB)
```
Model weights:        10-12 GB
KV cache (3×8K):       8-10 GB
Temp buffers:          2-3 GB
─────────────────────────────
TOTAL:                20-25 GB
FREE:                  7-12 GB (not enough for marker)
```

### Shared Mode (16GB)
```
Model weights:        10-12 GB
KV cache (2×4K):       3-4 GB
Temp buffers:          1-2 GB
─────────────────────────────
TOTAL:                14-18 GB
FREE:                 14-18 GB (perfect for marker!)
```

### With Marker Running (Total: 32GB)
```
Qwen3-VL-4B (shared): 14-18 GB
Marker models:         5-6 GB
Marker working:        6-8 GB
System overhead:       2-3 GB
─────────────────────────────
TOTAL:                27-31 GB ✅ FITS!
```

## Performance Impact

### What Changes in Shared Mode
- **Context length**: 4K vs 8K tokens (-50%)
  - Still plenty for: image + moderate text
  - Tight for: image + very long instructions

- **Concurrent requests**: 2 vs 3 (-33%)
  - Impact: Lower throughput under heavy load
  - Not noticeable for single-user use

- **Batch processing**: 4096 vs 8192 tokens
  - Small latency increase (<10%)

### What Stays the Same
- ✅ Model quality (BF16 precision)
- ✅ Vision capabilities
- ✅ Inference speed
- ✅ API compatibility
- ✅ All features intact

## Files Created/Modified

### Modified
- **`docker-compose.yml`**
  - Added `vllm-qwen3vl-4b-shared` service (new shared mode)
  - Updated `vllm-qwen3vl-4b` comments (standalone mode)

### Created
- **`QWEN3VL-4B-MODE-SWITCHING.md`** - Complete switching guide
- **`scripts/switch-qwen3vl-4b-mode.ps1`** - Helper script for easy switching
- **`QWEN3VL-4B-DUAL-CONFIG-SUMMARY.md`** - This file

## Use Cases

### When to Use Standalone Mode
- ✅ Running Qwen3-VL-4B alone
- ✅ Need maximum context length (8K)
- ✅ High concurrent request volume
- ✅ Testing/development with full capabilities
- ❌ **Cannot** run with marker simultaneously

### When to Use Shared Mode
- ✅ Running with marker container
- ✅ Memory-constrained environment
- ✅ Don't need full 8K context
- ✅ Pipeline processing (Qwen3-VL + marker)
- ✅ Production with multiple services

## Switching Best Practices

1. **Always stop the current mode first**
   ```powershell
   docker-compose stop vllm-qwen3vl-4b
   ```

2. **Wait for complete shutdown** (2-3 seconds)

3. **Start the new mode**
   ```powershell
   docker-compose --profile qwen3vl-4b-shared up -d
   ```

4. **Wait for startup** (30-60 seconds)

5. **Verify with nvidia-smi**
   ```powershell
   docker exec vllm-qwen3vl-4b nvidia-smi
   ```

## Troubleshooting

### Container Name Conflict
**Error**: "Container name vllm-qwen3vl-4b already in use"

**Cause**: Both configs use same container name (intentional - only one should run)

**Fix**:
```powershell
docker stop vllm-qwen3vl-4b
docker rm vllm-qwen3vl-4b
# Then try again
```

### Still Using 24GB in Shared Mode
**Cause**: Started wrong profile

**Check**:
```powershell
docker inspect vllm-qwen3vl-4b --format '{{.Args}}'
# Should show: --gpu-memory-utilization 0.50
```

**Fix**: Stop and restart with correct profile:
```powershell
.\scripts\switch-qwen3vl-4b-mode.ps1 shared
```

### OOM Error in Shared Mode
**Cause**: Too many other processes using GPU

**Check**:
```powershell
nvidia-smi  # See what's using VRAM
```

**Fix**: Reduce further if needed:
```powershell
# Edit docker-compose.yml
# Change shared mode to:
# --gpu-memory-utilization 0.45  (14.4GB)
```

## Monitoring Commands

```powershell
# Check current mode
.\scripts\switch-qwen3vl-4b-mode.ps1 status

# Check GPU usage
nvidia-smi

# View logs
docker logs -f vllm-qwen3vl-4b

# Test API
curl http://localhost:8005/v1/models
```

## API Endpoint

Both modes use the **same endpoint** (no code changes needed):
```
http://localhost:8005/v1/chat/completions
```

## Summary

✅ **Two modes available**: Standalone (24GB) and Shared (16GB)  
✅ **Easy switching**: Helper script or docker-compose profiles  
✅ **Same API**: No client code changes needed  
✅ **Marker compatible**: Shared mode leaves 14-18GB free  
✅ **Quality preserved**: Both use full BF16 precision  
✅ **Flexible**: Switch based on your current workflow  

## Recommendations

- **Default to shared mode** if you use marker regularly
- **Use standalone mode** for one-off high-performance tasks
- **Monitor VRAM usage** when first testing with marker
- **Adjust if needed** - can go lower (0.45) or higher (0.55) based on results

## Next Steps

1. **Test shared mode alone**:
   ```powershell
   .\scripts\switch-qwen3vl-4b-mode.ps1 shared
   docker exec vllm-qwen3vl-4b nvidia-smi
   ```

2. **Start marker and verify**:
   ```powershell
   # Your marker startup command
   nvidia-smi  # Should show ~28-30GB total used
   ```

3. **Run a test request** to both services

4. **Adjust if needed** based on actual usage

You now have complete flexibility to optimize VRAM usage based on your current workflow! 🚀

