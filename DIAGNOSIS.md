# Docker Network Setup - Problem Diagnosis

## Current Status
- ✅ vLLM container: Running and healthy
- ✅ Nginx container: Running 
- ❌ Port 8001: **NOT ACCESSIBLE** from host
- ❌ API: Cannot be reached from Windows

## Root Cause

**Docker Security Feature: Internal Networks Block Port Exposure**

When a container is connected **ONLY** to an internal network (`internal: true`), Docker **prevents** port exposure to the host as a security measure, even if ports are configured in docker-compose.yml.

### Evidence

```bash
# Port binding is CONFIGURED but not ACTIVE
$ docker inspect vllm-nginx-gateway --format "{{json .HostConfig.PortBindings}}"
{"80/tcp":[{"HostIp":"","HostPort":"8001"}]}  # ✅ Configuration exists

$ docker inspect vllm-nginx-gateway --format "{{json .NetworkSettings.Ports}}"
{"80/tcp":[]}  # ❌ No active port binding

# Nginx is ONLY on internal network
$ docker inspect vllm-nginx-gateway --format "{{json .NetworkSettings.Networks}}"
{"vllm_vllm-internal": {...}}  # Only internal network
```

### The Issue

```yaml
networks:
  vllm-internal:
    internal: true  # NO external connectivity

nginx-gateway:
  networks:
    - vllm-internal  # ONLY internal network
  ports:
    - "8001:80"  # Port configured but BLOCKED by Docker
```

**Result:** Port 8001 is configured but Docker blocks it because nginx-gateway has no external network connectivity.

## Solution Options

### Option 1: Add Bridge Network to Nginx (RECOMMENDED)
Keep security while allowing port exposure.

```yaml
networks:
  vllm-internal:
    internal: true  # vLLM containers stay isolated
  vllm-gateway:
    driver: bridge  # External connectivity for gateway only

nginx-gateway:
  networks:
    - vllm-internal  # Can talk to vLLM
    - vllm-gateway   # Can expose ports to host
  ports:
    - "8001:80"  # Now this will work!
```

**Security:**
- ✅ vLLM containers: Still NO internet (only on internal network)
- ✅ Nginx gateway: Can expose ports but doesn't route internet to vLLM
- ✅ Best practice: Gateway acts as security boundary

### Option 2: Use Default Bridge Network
Remove network specification from nginx only.

```yaml
nginx-gateway:
  networks:
    - vllm-internal  # Can talk to vLLM
    - default        # Docker's default bridge (has external connectivity)
  ports:
    - "8001:80"
```

### Option 3: Make vllm-internal Non-Internal (NOT RECOMMENDED)
Removes network isolation security.

```yaml
networks:
  vllm-internal:
    driver: bridge  # Remove internal: true
    # Now containers CAN access internet
```

**Problem:** vLLM containers would have internet access, which defeats the security goal.

## Recommended Fix

Use **Option 1** - it maintains your security architecture while fixing port exposure:

1. vLLM containers: Isolated (no internet, no exposed ports)
2. Nginx gateway: Acts as security boundary
3. Port exposure: Works correctly
4. Architecture: Matches vLLM's official patterns

## Why This Happened

The docker-compose.yml was designed with excellent security principles:
- Internal network for vLLM isolation ✅
- Gateway pattern for access ✅

But missed one detail:
- Gateway needs TWO networks: one internal (for vLLM) and one external (for port exposure)

This is actually mentioned in vLLM's official nginx deployment guide, but it's easy to miss!

## Implementation

I'll update docker-compose.yml to add the gateway network and fix the nginx configuration.

