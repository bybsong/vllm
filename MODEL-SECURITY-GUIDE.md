# Model Security Guide - Two-Phase Orchestration

## 🎯 Overview

This guide explains the **two-phase security approach** for all vLLM models in this deployment. This ensures models are downloaded properly, then completely isolated from the internet in production.

---

## 📋 Current Status

| Model | Status | Network | Offline Mode | Ready to Use |
|-------|--------|---------|--------------|--------------|
| **Nanonets-OCR** | ✅ Secure | vllm-internal | ✅ Enabled | ✅ Yes |
| **Qwen3-4B** | ✅ Secure | vllm-internal | ✅ Enabled | ✅ Yes |
| **Qwen3-VL-4B** | ✅ Secure | vllm-internal | ✅ Enabled | ✅ Yes |
| **Qwen3-VL-30B-AWQ** | ✅ Secure | vllm-internal | ✅ Enabled | ✅ Yes |
| **Qwen3-14B** | ⚠️ Phase 1 | default | ❌ Disabled | ⚠️ Needs completion |
| **Chandra** | ⚠️ Phase 1 | default | ❌ Disabled | ⚠️ Not configured yet |

---

## 🔐 Two-Phase Security Model

### Phase 1: Model Download (Testing)
**Purpose:** Download models from HuggingFace with internet access

```yaml
networks:
  - default  # Has internet access
environment:
  - HF_HUB_OFFLINE=1  # COMMENTED OUT - allows downloads
  - TRANSFORMERS_OFFLINE=1  # COMMENTED OUT
command:
  --model Qwen/ModelName  # Downloads from HuggingFace
```

**Characteristics:**
- ⚠️ Has internet access
- ⚠️ Can download models/updates
- ⚠️ Can send telemetry (disabled via env vars, but technically possible)
- ✅ Good for initial setup and testing

### Phase 2: Production (Secure)
**Purpose:** Run models completely offline with network isolation

```yaml
networks:
  - vllm-internal  # NO internet (internal=true)
  - llamaindex_internal  # Container-to-container only
environment:
  - HF_HUB_OFFLINE=1  # ENABLED - no HuggingFace access
  - TRANSFORMERS_OFFLINE=1  # ENABLED - no downloads
command:
  --model /root/.cache/huggingface/ModelName  # Local path only
```

**Characteristics:**
- ✅ NO internet access (network isolation)
- ✅ Cannot download anything
- ✅ Cannot send telemetry (physically impossible)
- ✅ All data stays local
- ✅ Production-ready

---

## 🔧 How to Secure a Model

### Step 1: Verify Model is Downloaded

Check that the model exists locally:

```powershell
# Check if model directory exists
ls models\
```

Look for directories like:
- `nanonets--Nanonets-OCR2-3B/` ✅
- `Qwen--Qwen3-4B-Instruct-2507/` ✅
- `Qwen--Qwen3-VL-4B-Instruct/` ✅
- `QuantTrio--Qwen3-VL-30B-A3B-Instruct-AWQ/` ✅

Each should have:
- `config.json`
- `tokenizer.json`
- `*.safetensors` files (the actual model weights)

### Step 2: Update docker-compose.yml

For each model service, make these changes:

#### Change 1: Switch Network
```yaml
# FROM:
networks:
  - default

# TO:
networks:
  - vllm-internal        # NO internet access (internal=true)
  - llamaindex_internal  # Accessible from LlamaIndex
```

#### Change 2: Enable Offline Mode
```yaml
# FROM:
environment:
  # - HF_HUB_OFFLINE=1
  # - TRANSFORMERS_OFFLINE=1

# TO:
environment:
  - HF_HUB_OFFLINE=1
  - TRANSFORMERS_OFFLINE=1
```

#### Change 3: Use Local Model Path
```yaml
# FROM:
command: >
  --model Qwen/Qwen3-4B-Instruct-2507

# TO:
command: >
  --model /root/.cache/huggingface/Qwen--Qwen3-4B-Instruct-2507
```

**Note:** The path format is `/root/.cache/huggingface/` + directory name with `--` replacing `/`
- `Qwen/Qwen3-4B` → `Qwen--Qwen3-4B`
- `nanonets/Nanonets-OCR2-3B` → `nanonets--Nanonets-OCR2-3B`

### Step 3: Restart Container

```powershell
# Stop the container
docker-compose --profile <profile-name> down

# Start with new secure settings
docker-compose --profile <profile-name> up -d

# Watch logs to verify startup
docker-compose logs -f <container-name>
```

### Step 4: Verify Security

```powershell
# Run verification script
.\scripts\verify-secure-models.ps1
```

This will test:
1. ✅ Container is running
2. ✅ NO internet access
3. ✅ Offline mode enabled
4. ✅ Health check passes
5. ✅ API works correctly

---

## 📊 Model-Specific Details

### ✅ Nanonets-OCR (Reference Implementation)

**Container:** `vllm-ocr`  
**Profile:** `ocr`  
**Port:** 8000 (internal), via nginx gateway  
**Status:** ✅ Fully secured

```bash
# Start
docker-compose --profile ocr up -d

# Verify
docker exec vllm-ocr ping -c 1 8.8.8.8  # Should FAIL (no internet)
curl http://localhost:8001/ocr/v1/models  # Should work
```

### ✅ Qwen3-4B-Instruct

**Container:** `vllm-text`  
**Profile:** `text`  
**Port:** 8003  
**Status:** ✅ Secured (just updated)

```bash
# Start
docker-compose --profile text up -d

# Verify
docker exec vllm-text ping -c 1 8.8.8.8  # Should FAIL
curl http://localhost:8003/v1/models  # Should work
```

### ✅ Qwen3-VL-30B-AWQ

**Container:** `vllm-qwen3vl`  
**Profile:** `qwen3vl`  
**Port:** 8002  
**Status:** ✅ Secured (just updated)

```bash
# Start
docker-compose --profile qwen3vl up -d

# Verify
docker exec vllm-qwen3vl ping -c 1 8.8.8.8  # Should FAIL
curl http://localhost:8002/v1/models  # Should work
```

### ✅ Qwen3-VL-4B

**Container:** `vllm-qwen3vl-4b`  
**Profile:** `qwen3vl-4b`  
**Port:** 8005  
**Status:** ✅ Secured (just updated)

```bash
# Start
docker-compose --profile qwen3vl-4b up -d

# Verify
docker exec vllm-qwen3vl-4b ping -c 1 8.8.8.8  # Should FAIL
curl http://localhost:8005/v1/models  # Should work
```

### ⚠️ Qwen3-14B (Not Yet Secured)

**Container:** `vllm-text-14b`  
**Profile:** `text-14b`  
**Port:** 8004  
**Status:** ⚠️ Phase 1 - Has `.incomplete` file

**Action Required:**
1. Check if download completed: `ls models\Qwen--Qwen3-14B\`
2. If `.incomplete` file exists, let it finish downloading
3. Once complete, apply security updates (same as other models)

### ⚠️ Chandra (Not Yet Configured)

**Container:** `vllm-chandra`  
**Profile:** `chandra`  
**Port:** N/A (internal only)  
**Status:** ⚠️ Phase 1 - Not yet secured

**Action Required:**
1. Verify model downloaded: `ls models\hub\models--datalab-to--chandra\`
2. Apply security updates when ready

---

## 🛡️ Security Testing

### Network Isolation Test

```powershell
# This should FAIL (timeout or network unreachable)
docker exec <container-name> ping -c 1 8.8.8.8
docker exec <container-name> curl https://google.com --max-time 3
```

Expected output: `Network is unreachable` or similar error ✅

### Offline Mode Test

```powershell
# Should return "1"
docker exec <container-name> printenv HF_HUB_OFFLINE
docker exec <container-name> printenv TRANSFORMERS_OFFLINE
```

### API Functionality Test

```powershell
# Should return 200 OK
curl http://localhost:<port>/health
curl http://localhost:<port>/v1/models
```

### Comprehensive Test

```powershell
# Run full verification suite
.\scripts\verify-secure-models.ps1
```

---

## 📝 Best Practices

### ✅ DO:
1. **Always download models first** (Phase 1) before securing
2. **Verify models are complete** before switching to Phase 2
3. **Test API works** before and after securing
4. **Run verification script** after making changes
5. **Keep offline env vars enabled** in production
6. **Use local paths** for model loading

### ❌ DON'T:
1. **Don't skip verification** - always test network isolation
2. **Don't use HuggingFace model names** in production (use local paths)
3. **Don't expose ports directly** unless needed for testing
4. **Don't remove offline env vars** once in production
5. **Don't switch to vllm-internal** before model is downloaded
6. **Don't restart with internet access** unless re-downloading

---

## 🚨 Security Risks by Phase

### Phase 1 Risks (Development/Download)
- ⚠️ Container can access internet
- ⚠️ Could download updates without notice
- ⚠️ Could send data externally (though telemetry disabled)
- ⚠️ Vulnerable to supply chain attacks

**Mitigation:** Only stay in Phase 1 during initial download, then immediately move to Phase 2

### Phase 2 Protection (Production)
- ✅ NO internet access - physically impossible to send data
- ✅ No model updates - uses local cache only
- ✅ No telemetry - network isolated
- ✅ Protected from supply chain attacks
- ✅ Complete data sovereignty

---

## 🔄 Workflow Summary

```
┌─────────────────────────────────────────────────────────┐
│ PHASE 1: DOWNLOAD                                       │
│ - Network: default (internet)                           │
│ - Offline: disabled                                     │
│ - Model: downloads from HuggingFace                     │
│ - Duration: 10-60 minutes (one-time)                    │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Model downloaded successfully ✓
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ TRANSITION                                              │
│ 1. Verify model files exist                            │
│ 2. Update docker-compose.yml                           │
│ 3. Restart container                                    │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ PHASE 2: PRODUCTION                                     │
│ - Network: vllm-internal (NO internet)                  │
│ - Offline: enabled                                      │
│ - Model: loads from local cache                         │
│ - Duration: Permanent (production ready)                │
└─────────────────────────────────────────────────────────┘
```

---

## 📚 Related Documentation

- **Network Architecture:** `SECURITY-NETWORK-SETUP.md`
- **Nanonets Setup:** `SETUP-NANONETS-OCR.md` (reference implementation)
- **Verification Script:** `scripts/verify-secure-models.ps1`
- **Docker Compose:** `docker-compose.yml`

---

## ✅ Quick Checklist

Before deploying to production, ensure:

- [ ] All models downloaded and verified complete
- [ ] docker-compose.yml updated for each model:
  - [ ] Network switched to `vllm-internal`
  - [ ] Offline env vars enabled
  - [ ] Model path uses local directory
- [ ] Containers restarted with new config
- [ ] Verification script passes all tests
- [ ] Network isolation confirmed (ping test fails)
- [ ] API functionality confirmed (health check works)
- [ ] No direct port exposures (unless required)

---

**Last Updated:** October 31, 2024  
**Status:** 4/6 models secured, 2 remaining in Phase 1

