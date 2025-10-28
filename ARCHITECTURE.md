# vLLM Nanonets-OCR2-3B Architecture

## Overview

This deployment follows **vLLM's official enterprise deployment pattern** as documented in their [Nginx deployment guide](https://docs.vllm.ai/en/latest/deployment/nginx.html).

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────┐
│                     EXTERNAL ACCESS                       │
│                                                            │
│  Windows Host: http://localhost:8001                      │
│  LlamaIndex Container: http://vllm-nginx-gateway/v1       │
└────────────────────────┬─────────────────────────────────┘
                         │
                         │ Port 8001
                         ↓
        ┌────────────────────────────────┐
        │     Nginx Gateway              │
        │     (nginx-alpine)             │
        │     Networks:                  │
        │       • default (bridge)       │ ← Allows port exposure
        │       • vllm-internal          │ ← Talks to vLLM
        │     • Load balancing           │
        │     • Health checking          │
        │     • Request routing          │
        └────────────┬───────────────────┘
                     │
                     │ vllm-internal network
                     │ (internal: true - NO internet)
                     ↓
        ┌────────────────────────────────┐
        │   vLLM Nanonets-OCR            │
        │   (vllm/vllm-openai:latest)    │
        │   Port 8000 (internal only)    │
        │   Network: vllm-internal ONLY  │
        │   • NO exposed ports           │
        │   • NO internet access         │
        │   • Loads from volume          │
        └────────────┬───────────────────┘
                     │
                     │ Volume mount
                     ↓
        ┌────────────────────────────────┐
        │   ./models (Persistent Disk)   │
        │   • Model cache                │
        │   • 6-8GB Nanonets-OCR2-3B     │
        │   • Shared across restarts     │
        └────────────────────────────────┘
```

## Key Principles

### 1. **Separation of Download and Serving**

**Old Pattern (Toggle):**
```
Same Container:
  Phase 1: Has internet → Downloads model → Serves
  Phase 2: No internet → Serves only
  Problem: Manual toggling, error-prone
```

**New Pattern (Volume):**
```
One-Time Setup:
  model-downloader → Downloads to ./models → Exits
  
Production (Forever):
  vllm-nanonets-ocr → Loads from ./models → Serves
  Benefit: NO internet ever needed, architecture-enforced
```

### 2. **Gateway Pattern**

Following vLLM's official nginx deployment:
- **Single External Access Point:** Only nginx has exposed ports
- **Internal Workers:** vLLM containers are internal-only
- **Load Balancing:** Nginx can route to multiple vLLM replicas
- **Health Checking:** Nginx monitors vLLM health
- **Dual Network:** Nginx on both default (for port exposure) and internal (for vLLM access)

### 3. **Network Isolation**

```yaml
networks:
  vllm-internal:
    internal: true  # NO internet access by Docker design
  vllm-external:
    # Only for one-time model download
  default:
    # Standard bridge - allows port exposure

nginx-gateway:
  networks:
    - default        # Enables port 8001 exposure to host
    - vllm-internal  # Connects to vLLM containers

vllm-nanonets-ocr:
  networks:
    - vllm-internal  # ONLY internal - no internet, no port exposure
```

**Security Benefits:**
- vLLM serving container **cannot** access internet (Docker-enforced)
- vLLM has NO exposed ports (only nginx does)
- Nginx acts as security boundary
- No manual toggling needed
- No risk of accidentally leaving internet enabled
- Data cannot leak even if compromised

**Why Nginx Needs Two Networks:**
- `default`: Allows Docker to bind port 8001 to host (external access)
- `vllm-internal`: Allows nginx to reach vLLM containers (internal routing)
- Docker blocks port exposure from containers ONLY on internal networks

## Components

### 1. Model Downloader (`model-downloader`)

**Purpose:** One-time model download with internet access

**Properties:**
- **Image:** `alpine:latest` (minimal)
- **Network:** `vllm-external` (has internet)
- **Volumes:** `./models:/models`
- **Restart:** `no` (runs once and exits)
- **Profile:** `setup` (only runs when explicitly called)

**Usage:**
```bash
# Run once to download model
docker-compose --profile setup up model-downloader
```

**What it does:**
1. Installs git and git-lfs
2. Checks if model already exists
3. Downloads from Hugging Face (6-8GB)
4. Exits successfully

### 2. vLLM Serving Container (`vllm-nanonets-ocr`)

**Purpose:** Production OCR serving (NO internet)

**Properties:**
- **Image:** `vllm/vllm-openai:latest`
- **Network:** `vllm-internal` (NO internet access)
- **Ports:** NONE exposed (internal 8000 only)
- **Volumes:** `./models:/root/.cache/huggingface`
- **GPU:** All available GPUs

**Configuration:**
```
Model: nanonets/Nanonets-OCR2-3B
Max Length: 15000 tokens
GPU Memory: 90%
Max Sequences: 5
Trust Remote Code: Yes
```

**Security:**
- ✅ NO internet access (network=internal)
- ✅ NO exposed ports
- ✅ Telemetry disabled
- ✅ Loads model from volume (no download)

### 3. Nginx Gateway (`nginx-gateway`)

**Purpose:** External access point and load balancer

**Properties:**
- **Image:** `nginx:alpine`
- **Network:** `vllm-internal` (can talk to vllm)
- **Ports:** `8001:80` (only exposed container)
- **Config:** `./nginx-config/nginx.conf`

**Features:**
- Health checking with automatic failover
- Least-connections load balancing
- Large request support (50MB)
- Extended timeouts for OCR (300s)
- Access logging

**Endpoints:**
- `/health` - Health check
- `/v1/*` - OpenAI-compatible API
- `/metrics` - Prometheus metrics

## Data Flow

### OCR Request Flow

```
1. Client Request
   ↓
   http://localhost:8001/v1/chat/completions
   
2. Nginx Gateway
   ↓
   • Receives request on port 8001
   • Routes to vllm-nanonets-ocr:8000
   • Handles timeouts and retries
   
3. vLLM Container (Internal)
   ↓
   • Processes OCR request
   • Loads model from /root/.cache/huggingface
   • Returns markdown result
   
4. Response
   ↓
   • Nginx forwards to client
   • Client receives OCR output
```

## Network Security

### Why `internal: true` is Better Than Network Blocking

**Network Blocking (What we had):**
```yaml
# Manual approach
network_mode: none  # or switching between networks
```
- ❌ Must manually configure
- ❌ Can be accidentally changed
- ❌ Docker restart might reset
- ❌ Easy to forget

**Internal Networks (vLLM's way):**
```yaml
networks:
  vllm-internal:
    internal: true  # Docker-enforced, cannot be bypassed
```
- ✅ Docker-enforced at network level
- ✅ Cannot be accidentally disabled
- ✅ Survives container restarts
- ✅ Standard enterprise pattern

### Connecting to Other Containers

The vLLM containers can still communicate with other containers:

```bash
# Connect vLLM network to your LlamaIndex network
docker network connect llamaindex_default vllm-nginx-gateway

# Now LlamaIndex can access via:
# http://vllm-nginx-gateway/v1
```

**This works because:**
- `internal: true` blocks **internet** access
- Container-to-container communication still works
- Multiple networks per container allowed

## Comparison: Old vs New

| Aspect | Old (Toggle Pattern) | New (Volume + Gateway) |
|--------|---------------------|------------------------|
| **Internet Access** | Manual toggle required | Never has internet |
| **Security** | Manual enforcement | Architecture-enforced |
| **Port Exposure** | vLLM directly exposed | Only nginx exposed |
| **Model Download** | In same container | Separate downloader |
| **Scalability** | Single container | Can add replicas easily |
| **Pattern** | Custom/manual | vLLM official pattern |
| **Forgetting Risk** | High (manual steps) | Zero (automated) |

## Scaling

To add more vLLM replicas (for load balancing):

### 1. Update docker-compose.yml:

```yaml
services:
  vllm-nanonets-ocr-1:
    # ... same config ...
    container_name: vllm-nanonets-ocr-1
  
  vllm-nanonets-ocr-2:
    # ... same config ...
    container_name: vllm-nanonets-ocr-2
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['1']  # Different GPU
```

### 2. Update nginx-config/nginx.conf:

```nginx
upstream vllm_backend {
    least_conn;
    server vllm-nanonets-ocr-1:8000 max_fails=3 fail_timeout=30s;
    server vllm-nanonets-ocr-2:8000 max_fails=3 fail_timeout=30s;
}
```

Nginx will automatically load-balance between replicas!

## Troubleshooting

### Check Container Status
```bash
docker-compose ps
```

### View Logs
```bash
# vLLM logs
docker-compose logs -f vllm-nanonets-ocr

# Nginx logs
docker-compose logs -f nginx-gateway
```

### Test Health
```bash
# Via nginx gateway
curl http://localhost:8001/health

# Direct to vLLM (from another container)
docker exec vllm-nginx-gateway curl http://vllm-nanonets-ocr:8000/health
```

### Verify Network Isolation
```bash
# Should FAIL (no internet)
docker exec vllm-nanonets-ocr ping -c 1 8.8.8.8

# Should SUCCEED (internal communication)
docker exec vllm-nginx-gateway curl http://vllm-nanonets-ocr:8000/health
```

## Migration from Old Setup

If you have the old toggle-based setup:

```bash
# 1. Stop old containers
docker-compose down

# 2. Backup your models (if needed)
# They should already be in ./models

# 3. Use new setup script
./scripts/setup-nanonets.sh  # Linux/WSL2
# or
.\scripts\setup-nanonets.ps1  # PowerShell

# 4. Test
curl http://localhost:8001/health
```

## Best Practices

1. **Never expose vLLM ports directly** - Always use gateway
2. **Use persistent volumes** - Never download models inside serving containers
3. **Keep gateway separate** - Allows easy scaling and security updates
4. **Monitor health endpoints** - Set up alerts on /health
5. **Use internal networks** - Architecture-enforced security > manual blocking

## References

- [vLLM Nginx Deployment Guide](https://docs.vllm.ai/en/latest/deployment/nginx.html)
- [vLLM Docker Deployment](https://docs.vllm.ai/en/latest/deployment/docker.html)
- [vLLM Kubernetes Deployment](https://docs.vllm.ai/en/latest/deployment/k8s.html)
- [Nanonets-OCR2-3B Model](https://huggingface.co/nanonets/Nanonets-OCR2-3B)

