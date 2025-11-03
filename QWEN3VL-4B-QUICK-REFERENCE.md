# Qwen3-VL-4B Quick Reference Card

## 🚀 Fastest Way to Switch Modes

```powershell
# High performance (24GB) - use alone
.\scripts\switch-qwen3vl-4b-mode.ps1 standalone

# Memory efficient (16GB) - use with marker
.\scripts\switch-qwen3vl-4b-mode.ps1 shared

# Check what's running
.\scripts\switch-qwen3vl-4b-mode.ps1 status
```

## 📊 Mode Comparison (One Glance)

|                    | **Standalone** | **Shared** |
|--------------------|----------------|------------|
| **VRAM**           | 24GB           | 16GB       |
| **Context**        | 8K tokens      | 4K tokens  |
| **Concurrent**     | 3 requests     | 2 requests |
| **With Marker?**   | ❌ No          | ✅ Yes     |
| **Performance**    | Maximum        | Good       |

## 🎯 Which Mode Should I Use?

**Choose STANDALONE if:**
- Running Qwen3-VL-4B alone
- Need full 8K context
- Want max throughput

**Choose SHARED if:**
- Running with marker
- Need to save VRAM
- 4K context is enough

## 🔧 Manual Commands (If Script Doesn't Work)

### Standalone
```powershell
docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b
```

### Shared
```powershell
docker-compose --profile qwen3vl-4b-shared up -d vllm-qwen3vl-4b-shared
```

### Stop
```powershell
docker-compose stop vllm-qwen3vl-4b
```

## 🔍 Check VRAM Usage

```powershell
nvidia-smi
# or
docker exec vllm-qwen3vl-4b nvidia-smi
```

**Expected:**
- Standalone: ~20-24GB
- Shared: ~14-18GB

## 🏥 Health Check

```powershell
curl http://localhost:8005/health
curl http://localhost:8005/v1/models
```

## 📝 With Marker (Shared Mode)

```powershell
# 1. Start Qwen3-VL-4B in shared mode
.\scripts\switch-qwen3vl-4b-mode.ps1 shared

# 2. Wait for startup (30-60 sec)
docker logs -f vllm-qwen3vl-4b

# 3. Start marker
docker-compose up -d marker  # adjust to your setup

# 4. Verify both running
nvidia-smi  # Should show ~28-30GB total
```

## ⚠️ Common Issues

**"Container already exists"**
```powershell
docker rm -f vllm-qwen3vl-4b
```

**"Still using 24GB"**
```powershell
# You started wrong profile
.\scripts\switch-qwen3vl-4b-mode.ps1 shared
```

**"Out of memory"**
```powershell
# Check what's using GPU
nvidia-smi
# Stop other containers or reduce to 0.45
```

## 📚 Full Documentation

- **Mode Switching Guide**: `QWEN3VL-4B-MODE-SWITCHING.md`
- **Implementation Details**: `QWEN3VL-4B-DUAL-CONFIG-SUMMARY.md`
- **This Card**: `QWEN3VL-4B-QUICK-REFERENCE.md`

## 💾 VRAM Allocation With Marker

```
32GB RTX 5090
├─ Qwen3-VL-4B (shared):  16GB
├─ Marker models:          6GB
├─ Marker working:         8GB
└─ System overhead:        2GB
   ────────────────────────────
   TOTAL:                ~30GB ✅
```

## ⚡ Performance Impact (Shared vs Standalone)

- Context: **50% shorter** (4K vs 8K)
- Concurrency: **33% fewer** (2 vs 3 requests)
- Latency: **~10% slower**
- Quality: **No change** (still BF16)

## 🎬 First Time Setup

```powershell
# 1. Test standalone first
.\scripts\switch-qwen3vl-4b-mode.ps1 standalone
docker logs -f vllm-qwen3vl-4b

# 2. Test shared mode
.\scripts\switch-qwen3vl-4b-mode.ps1 shared
docker exec vllm-qwen3vl-4b nvidia-smi

# 3. Add marker and verify
docker-compose up -d marker
nvidia-smi  # Check total usage
```

---

**🔗 Same API endpoint for both modes:**  
`http://localhost:8005/v1/chat/completions`

**🔄 Switch anytime - no downtime needed for other services**

