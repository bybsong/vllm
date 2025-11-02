import os
from huggingface_hub import snapshot_download

MODEL_NAME = "Qwen/Qwen3-VL-4B-Instruct"
TARGET_PATH = os.path.join("models", MODEL_NAME.replace("/", "--"))

print("==================================================")
print("Qwen3-VL-4B-Instruct Download (~8-10GB)")
print("==================================================")
print(f"\nDownloading: {MODEL_NAME}")
print(f"Target: {TARGET_PATH}")
print("Size: ~8-10GB (much smaller than 30B!)")
print("\nKey Benefits:")
print("- 2x faster inference than 30B-AWQ")
print("- Only ~8-10GB VRAM (vs ~30GB)")
print("- Perfect for page comparison tasks")
print("\nDownload progress:")
print("--------------------------------------------------")

try:
    snapshot_download(
        repo_id=MODEL_NAME,
        local_dir=TARGET_PATH,
        local_dir_use_symlinks=False,
        resume_download=True,
    )
    print("==================================================")
    print("Download Complete!")
    print("==================================================")
    print(f"\nLocation: {os.path.abspath(TARGET_PATH)}")
    
    # Calculate size
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(TARGET_PATH):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            total_size += os.path.getsize(fp)
    
    print(f"Size: {round(total_size / (1024**3), 2)} GB")
    
    print("\nNext steps:")
    print("1. Start service: docker-compose --profile qwen3vl-4b up -d vllm-qwen3vl-4b")
    print("2. Check logs: docker logs -f vllm-qwen3vl-4b")
    print("3. Test API: curl http://localhost:8005/v1/models")
    
    print("\nVision-Language Model Comparison:")
    print("- Qwen3-VL-30B-AWQ (port 8002): ~30GB VRAM, 3-5 sec/page")
    print("- Qwen3-VL-4B (port 8005): ~8-10GB VRAM, 1.5-2.5 sec/page (FASTER!)")
    
    print("\nRecommendation:")
    print("Test 4B model on 10 sample pages to verify accuracy before switching.")

except Exception as e:
    print(f"\nError during download: {e}")
    print("\nYou can try running this script again to resume the download.")
    exit(1)

