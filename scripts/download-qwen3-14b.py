import os
from huggingface_hub import snapshot_download

MODEL_NAME = "Qwen/Qwen3-14B"
TARGET_PATH = os.path.join("models", MODEL_NAME.replace("/", "--"))

print("==================================================")
print("Qwen3-14B-Instruct Download (~14-18GB)")
print("==================================================")
print(f"\nDownloading: {MODEL_NAME}")
print(f"Target: {TARGET_PATH}")
print("Size: ~14-18GB (bfloat16)")
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
    print("1. Start service: docker-compose --profile text-14b up -d vllm-text-14b")
    print("2. Check logs: docker logs -f vllm-text-14b")
    print("3. Test API: curl http://localhost:8004/v1/models")
    print("\nComparison:")
    print("- Qwen3-4B (port 8003): Fast, basic tasks")
    print("- Qwen3-14B (port 8004): 2-3x better reasoning/coding")

except Exception as e:
    print(f"\nError during download: {e}")
    print("\nYou can try running this script again to resume the download.")
    exit(1)

