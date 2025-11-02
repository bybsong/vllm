#!/usr/bin/env python3
"""
Download Qwen3-30B-A3B-Instruct-2507-FP8 model for vLLM
Phase 1: Download with internet access
Phase 2: Use offline in secure container
"""

import os
import sys
from pathlib import Path
from huggingface_hub import snapshot_download

# Configuration
MODEL_NAME = "Qwen/Qwen3-30B-A3B-Instruct-2507-FP8"
LOCAL_DIR = "models/Qwen--Qwen3-30B-A3B-Instruct-2507-FP8"

print("=" * 70)
print("Qwen3-30B-A3B-Instruct-2507-FP8 Model Downloader")
print("=" * 70)
print()
print(f"Model: {MODEL_NAME}")
print(f"Destination: {LOCAL_DIR}")
print()
print("This is a large model (~12-14 GB). Download may take 20-40 minutes.")
print("=" * 70)
print()

# Create models directory if it doesn't exist
models_dir = Path("models")
models_dir.mkdir(exist_ok=True)

# Check if model already exists
local_path = Path(LOCAL_DIR)
if local_path.exists() and any(local_path.iterdir()):
    print("✓ Model already downloaded!")
    print(f"  Location: {local_path.absolute()}")
    print()
    
    # List key files
    config_file = local_path / "config.json"
    if config_file.exists():
        print("✓ config.json found")
    
    safetensors_files = list(local_path.glob("*.safetensors"))
    if safetensors_files:
        print(f"✓ {len(safetensors_files)} safetensors files found")
        total_size = sum(f.stat().st_size for f in safetensors_files)
        print(f"  Total size: {total_size / 1024**3:.2f} GB")
    
    print()
    print("Model is ready to use!")
    sys.exit(0)

print("Starting download...")
print()

try:
    # Download model with progress bar
    snapshot_download(
        repo_id=MODEL_NAME,
        local_dir=LOCAL_DIR,
        local_dir_use_symlinks=False,
        resume_download=True,
        max_workers=4,
    )
    
    print()
    print("=" * 70)
    print("✓ Download completed successfully!")
    print("=" * 70)
    print()
    print(f"Model location: {Path(LOCAL_DIR).absolute()}")
    
    # Verify download
    config_file = Path(LOCAL_DIR) / "config.json"
    if config_file.exists():
        print("✓ config.json verified")
    
    safetensors_files = list(Path(LOCAL_DIR).glob("*.safetensors"))
    if safetensors_files:
        print(f"✓ {len(safetensors_files)} model files verified")
        total_size = sum(f.stat().st_size for f in safetensors_files)
        print(f"✓ Total size: {total_size / 1024**3:.2f} GB")
    
    print()
    print("=" * 70)
    print("Next Steps:")
    print("=" * 70)
    print("1. Model is downloaded and ready")
    print("2. Update docker-compose.yml to use this model")
    print("3. Start container in secure offline mode")
    print()
    print("The model will run with:")
    print("  - NO internet access (vllm-internal network)")
    print("  - Offline mode enabled (HF_HUB_OFFLINE=1)")
    print("  - Local model path only")
    print()
    
except KeyboardInterrupt:
    print()
    print("Download interrupted. Run again to resume.")
    sys.exit(1)
except Exception as e:
    print()
    print(f"Error downloading model: {e}")
    print()
    print("Troubleshooting:")
    print("1. Check your internet connection")
    print("2. Ensure you have ~15GB free disk space")
    print("3. Try running again (download will resume)")
    sys.exit(1)

