import os
from huggingface_hub import snapshot_download

# Model ID
MODEL_ID = "tencent/HunyuanOCR"

# Target directory matching the 'hub' volume mount structure
# docker-compose mounts: ./models/hub:/root/.cache/huggingface/hub
# So we download to models/hub to create the models--tencent--HunyuanOCR structure
CACHE_DIR = os.path.join("models", "hub")

print("==================================================")
print(f"HunyuanOCR Download (Model: {MODEL_ID})")
print("==================================================")
print(f"Target Cache Dir: {os.path.abspath(CACHE_DIR)}")
print("Expected Structure: models/hub/models--tencent--HunyuanOCR/snapshots/...")
print("\nModel Details:")
print("- Size: ~1B parameters (Lightweight)")
print("- VRAM: < 4GB")
print("- Purpose: End-to-end document parsing")
print("--------------------------------------------------")

try:
    # We use cache_dir to ensure the internal 'snapshots' structure is created
    # This is required for vLLM to find it when HF_HUB_OFFLINE=1
    path = snapshot_download(
        repo_id=MODEL_ID,
        cache_dir=CACHE_DIR,
        resume_download=True,
        # Specific include patterns can be added if we want to filter files,
        # but for a main model download, we usually want everything.
    )
    
    print("==================================================")
    print("Download Complete!")
    print("==================================================")
    print(f"\nFiles stored in: {path}")
    
    print("\nNext Steps:")
    print("1. Ensure 'vllm-hunyuan-ocr' is added to docker-compose.yml")
    print("2. Run: docker-compose up -d vllm-hunyuan-ocr")
    print("3. Test: curl http://localhost:8006/v1/chat/completions ...")

except Exception as e:
    print(f"\nError during download: {e}")
    exit(1)

