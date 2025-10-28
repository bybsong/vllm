# Migration Guide: Old Setup → New vLLM Enterprise Architecture

## What Changed?

We've restructured the deployment to follow **vLLM's official enterprise deployment pattern** with gateway architecture and volume-based model storage.

### Old Architecture (Toggle-Based)
```
┌─────────────────────────────┐
│  vllm-nanonets-ocr          │
│  Port 8001 exposed          │
│  Toggle: internet/no-internet│
└─────────────────────────────┘
```

**Problems:**
- Manual network switching required
- vLLM directly exposed to host
- Same container for download and serving
- Easy to forget to switch modes
- Not following vLLM best practices

### New Architecture (vLLM Official Pattern)
```
┌────────────────────────────┐
│  Nginx Gateway (8001)      │  ← Only exposed port
└──────────┬─────────────────┘
           │ internal network
┌──────────▼─────────────────┐
│  vLLM (internal only)      │  ← NO internet, NO exposed ports
└──────────┬─────────────────┘
           │ volume mount
┌──────────▼─────────────────┐
│  ./models/ (persistent)    │  ← Model storage
└────────────────────────────┘
```

**Benefits:**
- Architecture-enforced security (Docker's internal network)
- Follows vLLM official deployment guide
- No manual toggling needed
- Gateway layer for scaling
- Model download separated from serving

## Migration Steps

### Step 1: Stop Old Containers

```bash
# Stop everything
docker-compose down

# Your models should already be cached in ./models
# If not, they will be re-downloaded
```

### Step 2: Backup (Optional)

```bash
# Backup existing models (optional - they'll be reused)
cp -r models models.backup

# Backup old docker-compose.yml (we've already replaced it)
# It's in git history if you need it
```

### Step 3: Use New Setup

**Automated (Recommended):**

```bash
# Linux/WSL2
./scripts/setup-nanonets.sh

# PowerShell
.\scripts\setup-nanonets.ps1
```

**Manual:**

```bash
# 1. Download model (skip if already have models/)
docker-compose --profile setup up model-downloader

# 2. Start new services
docker-compose up -d vllm-nanonets-ocr nginx-gateway

# 3. Wait for startup (~30 seconds)
docker-compose logs -f vllm-nanonets-ocr

# 4. Test
curl http://localhost:8001/health
```

### Step 4: Update Your Applications

**Old endpoint:**
```python
api_base = "http://localhost:8001/v1"  # Direct to vLLM
```

**New endpoint:**
```python
api_base = "http://localhost:8001/v1"  # Via nginx gateway
```

**Good news:** The endpoint is the same! Only the internal routing changed.

**For container-to-container access:**

Old:
```python
# From another container
api_base = "http://vllm-nanonets-ocr:8000/v1"
```

New:
```python
# From another container (recommended)
api_base = "http://vllm-nginx-gateway/v1"

# Or direct to vLLM (still works, but bypasses gateway)
api_base = "http://vllm-nanonets-ocr:8000/v1"
```

### Step 5: Connect to LlamaIndex (If Needed)

```bash
# Connect the gateway to your LlamaIndex network
docker network connect llamaindex_default vllm-nginx-gateway

# Now LlamaIndex can access via:
# http://vllm-nginx-gateway/v1
```

## What to Delete (Old Files)

These scripts are **no longer needed**:

```bash
# Old network switching scripts (not needed anymore)
rm scripts/switch-to-production.ps1
rm scripts/switch-to-production.sh
rm scripts/switch-to-testing.ps1
rm scripts/switch-to-testing.sh

# Old documentation (replaced)
rm SECURITY-NETWORK-SETUP.md
rm NETWORK-SWITCH-GUIDE.md
```

**New files to use:**
- `ARCHITECTURE.md` - Detailed architecture documentation
- `QUICKSTART-NEW.md` - Quick start guide
- `MIGRATION-GUIDE.md` - This file
- `scripts/setup-nanonets.sh` / `.ps1` - One-command setup

## Comparison: Old vs New Commands

| Task | Old Way | New Way |
|------|---------|---------|
| **First Setup** | `docker-compose up -d` + wait + `switch-to-production.ps1` | `./scripts/setup-nanonets.sh` |
| **Start** | `docker-compose up -d` | `docker-compose up -d vllm-nanonets-ocr nginx-gateway` |
| **Switch to Production** | `.\scripts\switch-to-production.ps1` | Not needed - always secure |
| **Switch to Testing** | `.\scripts\switch-to-testing.ps1` | Not needed - model already downloaded |
| **Update Model** | Toggle network, restart | `docker-compose --profile setup up model-downloader` |
| **Check Security** | Hope you remembered to switch | `docker exec vllm-nanonets-ocr ping 8.8.8.8` (should fail) |

## Verification Checklist

After migration, verify everything works:

- [ ] Containers running: `docker-compose ps`
- [ ] Health check: `curl http://localhost:8001/health`
- [ ] Internet blocked: `docker exec vllm-nanonets-ocr ping -c 1 8.8.8.8` (should FAIL)
- [ ] OCR works: `python scripts/nanonets-ocr-example.py --image test.jpg`
- [ ] Gateway accessible: `curl http://localhost:8001/v1/models`
- [ ] LlamaIndex connected: `docker exec llamaindex-rag curl http://vllm-nginx-gateway/health`

## Troubleshooting

### "Model not found" Error

```bash
# Model might not have been downloaded
docker-compose --profile setup up model-downloader

# Check if model exists
ls -lh models/
# Should see: nanonets--Nanonets-OCR2-3B/
```

### Can't Access from Host

```bash
# Check nginx is running
docker-compose ps nginx-gateway

# Check nginx logs
docker-compose logs nginx-gateway

# Test direct to vLLM (should work)
docker exec nginx-gateway curl http://vllm-nanonets-ocr:8000/health
```

### Container Has Internet (Security Issue!)

```bash
# This should FAIL (good):
docker exec vllm-nanonets-ocr ping -c 1 8.8.8.8

# If it succeeds (bad), check docker-compose.yml:
# vllm-nanonets-ocr:
#   networks:
#     - vllm-internal  # Must be internal network only
```

### LlamaIndex Can't Connect

```bash
# Connect networks
docker network connect llamaindex_default vllm-nginx-gateway

# Verify from inside llamaindex
docker exec llamaindex-rag curl http://vllm-nginx-gateway/health

# If still fails, check if both containers are running
docker ps | grep -E "(llamaindex|vllm)"
```

## FAQ

### Q: Do I lose my downloaded models?

**A:** No! Models in `./models/` are preserved. The new setup uses the same directory.

### Q: Can I still use the old direct access?

**A:** Yes, but not recommended. You can access `http://vllm-nanonets-ocr:8000` from other containers, but the gateway provides load balancing and is the official pattern.

### Q: What if I need to download a different model?

**A:**
```bash
# 1. Stop serving
docker-compose down vllm-nanonets-ocr

# 2. Edit docker-compose.yml to change MODEL_NAME
# 3. Remove old model
rm -rf models/nanonets--Nanonets-OCR2-3B

# 4. Download new model
docker-compose --profile setup up model-downloader

# 5. Update vllm command to use new model
# 6. Restart
docker-compose up -d vllm-nanonets-ocr nginx-gateway
```

### Q: How do I scale to multiple vLLM instances?

**A:** See `ARCHITECTURE.md` section on "Scaling". The nginx gateway supports multiple backends:

```yaml
services:
  vllm-nanonets-ocr-1:
    # ... config ...
  vllm-nanonets-ocr-2:
    # ... config ...
```

Then update `nginx-config/nginx.conf` to include both.

### Q: Is this really more secure?

**A:** Yes! Comparison:

| Security Aspect | Old | New |
|----------------|-----|-----|
| Internet access | Manual toggle (can forget) | Docker-enforced (cannot bypass) |
| Port exposure | vLLM direct | Only nginx (gateway pattern) |
| Model download | Same container | Separate process |
| Attack surface | Large (direct access) | Small (gateway only) |
| Compliance | Manual procedures | Architecture-enforced |

### Q: Why follow vLLM's pattern?

**A:** 
1. **Officially supported** - vLLM maintains this pattern
2. **Battle-tested** - Used in production by enterprises
3. **Scalable** - Easy to add replicas
4. **Secure** - Network isolation by design
5. **Standard** - Matches Kubernetes/cloud deployments

## Rollback (If Needed)

If you need to rollback to the old setup:

```bash
# 1. Stop new containers
docker-compose down

# 2. Restore old docker-compose.yml from git
git checkout HEAD~1 docker-compose.yml

# 3. Restore old scripts
git checkout HEAD~1 scripts/switch-to-*.ps1 scripts/switch-to-*.sh

# 4. Start old way
docker-compose up -d vllm-nanonets-ocr
.\scripts\switch-to-production.ps1
```

But please report why you needed to rollback - we want to make this migration smooth!

## Getting Help

- **Architecture questions:** See `ARCHITECTURE.md`
- **Quick start:** See `QUICKSTART-NEW.md`
- **vLLM official docs:** https://docs.vllm.ai/en/latest/deployment/nginx.html
- **Report issues:** Check container logs first: `docker-compose logs -f`

## Summary

The new architecture is:
- ✅ **More secure** (Docker-enforced isolation)
- ✅ **Official pattern** (vLLM recommended)
- ✅ **Easier to use** (no manual toggling)
- ✅ **More scalable** (gateway + workers)
- ✅ **Better maintained** (standard architecture)

**You should migrate!** The old pattern was a temporary solution. This is production-grade.

