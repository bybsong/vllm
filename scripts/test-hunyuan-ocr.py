import argparse
import requests
import json
import base64

def encode_image(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def test_ocr(image_path, api_url="http://localhost:8006/v1/chat/completions"):
    print(f"Testing HunyuanOCR with image: {image_path}")
    
    # Standard OCR Prompt for Hunyuan
    prompt_text = (
        "Extract all information from the main body of the document image "
        "and represent it in markdown format, ignoring headers and footers."
        "Tables should be expressed in HTML format, formulas in the document "
        "should be represented using LaTeX format, and the parsing should be "
        "organized according to the reading order."
    )

    if image_path.startswith("http"):
        image_url = image_path
    else:
        base64_image = encode_image(image_path)
        image_url = f"data:image/jpeg;base64,{base64_image}"

    payload = {
        "model": "tencent/HunyuanOCR",
        "messages": [
            {
                "role": "system",
                "content": ""  # System prompt is typically empty for this model
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": image_url
                        }
                    },
                    {"type": "text", "text": prompt_text}
                ]
            }
        ],
        "temperature": 0.0,  # Greedy sampling recommended
        "top_k": 1,
        "repetition_penalty": 1.0,
        "max_tokens": 2048
    }

    try:
        response = requests.post(api_url, headers={"Content-Type": "application/json"}, json=payload)
        response.raise_for_status()
        result = response.json()
        print("\nOCR Result:\n")
        print(result['choices'][0]['message']['content'])
    except Exception as e:
        print(f"Error: {e}")
        if 'response' in locals():
            print(response.text)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test HunyuanOCR via vLLM")
    parser.add_argument("image_path", help="Path or URL to image")
    parser.add_argument("--url", default="http://localhost:8006/v1/chat/completions", help="API URL")
    args = parser.parse_args()
    
    test_ocr(args.image_path, args.url)

