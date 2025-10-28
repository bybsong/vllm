# Chandra OCR Model Integration Attempt

## Status: ⚠️ Blocked - Model Loading Issues

### What We Tried

1. **Created symbolic links** from your existing Chandra model cache to vLLM models directory
2. **Added vLLM service** for Chandra in `docker-compose.yml` 
3. **Updated nginx gateway** to route `/chandra/v1/*` to the Chandra service
4. **Configured networking** with temporary internet access for model download

### Issue Encountered

The Chandra model **crashes during initialization** in vLLM, showing the same errors you experienced when trying to build from your forked repo at `C:\Users\bybso\chandra`.

**Key observation:** The model successfully:
- ✅ Downloads from HuggingFace
- ✅ Loads weights (16.6GB VRAM, ~105 seconds)
- ✅ Initializes Flash Attention backend
- ✅ Recognizes architecture as `Qwen3VLForConditionalGeneration`
- ❌ **Crashes during encoder cache initialization**

The container enters a restart loop after attempting to profile the encoder cache.

### Files Modified

All changes are complete and saved:

1. **`docker-compose.yml`**
   - Added `vllm-chandra` service with Qwen3-VL configuration
   - Temporarily enabled internet access for model download
   - Configuration: 32K context, 0.45 GPU utilization, 8 max sequences

2. **`nginx-config/nginx-multi-model.conf`**
   - Added `vllm_chandra` upstream backend
   - Added `/chandra/` location block with proper routing
   - Added health check endpoint: `/health/chandra`
   - Added metrics endpoint: `/metrics/chandra`
   - Updated root JSON to include Chandra model info

3. **`scripts/test-chandra.sh`**
   - Created test script for API validation (not yet functional)

### Model Details

- **Model:** `datalab-to/chandra` (Qwen3-VL based)
- **Size:** ~6-8GB download, 16.6GB VRAM when loaded
- **Architecture:** Qwen3VLForConditionalGeneration (natively supported by vLLM)
- **Downloaded to:** `/models/hub/models--datalab-to--chandra/`

### Why It's Not Working

This appears to be the **same fundamental issue** you encountered when trying to build Chandra from your forked repo. The problem is NOT with:
- ❌ vLLM compatibility (Qwen3-VL is fully supported)
- ❌ Model file structure (downloads correctly)
- ❌ Docker configuration (follows working Nanonets pattern)
- ❌ Network setup (works with internet access)

The issue is likely:
- ⚠️ **Vision model initialization bug** in this vLLM version (0.11.0) with Chandra's specific config
- ⚠️ **Encoder cache profiling failure** during startup
- ⚠️ **Compatibility issue** between Chandra's model architecture and vLLM's expectations

### Possible Solutions to Try Later

1. **Try different vLLM version**
   ```yaml
   image: vllm/vllm-openai:v0.10.4  # or another stable version
   ```

2. **Disable encoder cache** or reduce profiling requirements
   ```yaml
   command: >
     --model datalab-to/chandra
     --disable-custom-all-reduce  # Try various flags
   ```

3. **Use HuggingFace Transformers directly** instead of vLLM
   - Your existing Chandra setup at `C:\Users\bybso\chandra` uses HF Transformers
   - That might be more stable for this specific model

4. **Contact Chandra/vLLM communities**
   - Check if others have successfully loaded Chandra in vLLM
   - Report the specific crash during encoder cache initialization

### How to Resume Testing Later

If you want to try again:

```bash
# From WSL2
cd /mnt/c/Users/bybso/vllm

# Check logs for specific error
docker-compose logs vllm-chandra | grep -E "(ERROR|Exception|Traceback)" | tail -50

# Try restarting
docker-compose restart vllm-chandra

# Or try without network restrictions
# (already configured in docker-compose.yml)
```

### Current State

- Model files downloaded and cached in `./models/hub/models--datalab-to--chandra/`
- Docker service configured but not running (crashes on startup)
- Nginx routing configured and ready (just needs working backend)
- Test script created but untested

### Recommendation

Since this is hitting the same error as your original build attempt, integrating Chandra into your vLLM setup might require:
1. Debugging the specific vLLM/Chandra compatibility issue
2. Using a different inference engine (like your existing Chandra HF setup)
3. Waiting for vLLM updates that better support this model variant

For now, **Nanonets-OCR2-3B is your working OCR solution** on vLLM.

---

**Date:** October 28, 2025  
**vLLM Version:** 0.11.0  
**Chandra Model:** datalab-to/chandra (Qwen3-VL based)

