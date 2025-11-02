"""
Direct Python download for Qwen3-VL-30B-A3B-Instruct
Uses huggingface_hub Python library directly (more reliable than CLI)
"""
import os
from pathlib import Path
from huggingface_hub import snapshot_download

print("=" * 50)
print("Qwen3-VL Model Downloader (Python)")
print("=" * 50)
print()

MODEL_NAME = "Qwen/Qwen3-VL-30B-A3B-Instruct"
MODEL_DIR = Path("models/Qwen--Qwen3-VL-30B-A3B-Instruct")
OFFLINE_MARKER = Path("models/.qwen3vl_downloaded")

# Check if already downloaded
if MODEL_DIR.exists() and OFFLINE_MARKER.exists():
    print(f"✓ Model already downloaded at: {MODEL_DIR}")
    print()
    print("Start the service with:")
    print("  docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway")
    exit(0)

print(f"Downloading: {MODEL_NAME}")
print(f"Target: {MODEL_DIR}")
print(f"Size: ~60GB (this will take 30-60 minutes)")
print()
print("Download progress will be shown below...")
print("-" * 50)
print()

try:
    # Download model
    snapshot_download(
        repo_id=MODEL_NAME,
        local_dir=str(MODEL_DIR),
        local_dir_use_symlinks=False,
        resume_download=True,  # Resume if interrupted
    )
    
    print()
    print("=" * 50)
    print("✓ Download Complete!")
    print("=" * 50)
    print()
    
    # Create offline marker
    OFFLINE_MARKER.parent.mkdir(parents=True, exist_ok=True)
    OFFLINE_MARKER.touch()
    
    # Get size
    total_size = sum(f.stat().st_size for f in MODEL_DIR.rglob('*') if f.is_file())
    size_gb = total_size / (1024**3)
    
    print(f"Location: {MODEL_DIR.absolute()}")
    print(f"Size: {size_gb:.2f} GB")
    print()
    print("Next steps:")
    print("1. Start service: docker-compose --profile qwen3vl up -d vllm-qwen3vl nginx-gateway")
    print("2. Check logs: docker logs -f vllm-qwen3vl")
    print("3. Test API: .\\scripts\\test-qwen3vl.ps1")
    print()
    
except KeyboardInterrupt:
    print()
    print("Download interrupted. Run this script again to resume.")
    exit(1)
except Exception as e:
    print()
    print(f"Error: {e}")
    print()
    print("You can try running this script again to resume the download.")
    exit(1)

