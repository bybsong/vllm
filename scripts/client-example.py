#!/usr/bin/env python3
"""
Example Python client for vLLM OpenAI-compatible API

This demonstrates how to use vLLM as a drop-in replacement for OpenAI API.
"""

from openai import OpenAI

# Point to your local vLLM server
client = OpenAI(
    api_key="EMPTY",  # vLLM doesn't require API key by default
    base_url="http://localhost:8000/v1",
)

def test_completion():
    """Test the completion endpoint"""
    print("=" * 60)
    print("Testing Completion Endpoint")
    print("=" * 60)
    
    response = client.completions.create(
        model="meta-llama/Llama-3.2-3B-Instruct",
        prompt="The three laws of robotics are:",
        max_tokens=200,
        temperature=0.7,
    )
    
    print(f"Prompt: {response.choices[0].text}")
    print()


def test_chat_completion():
    """Test the chat completion endpoint"""
    print("=" * 60)
    print("Testing Chat Completion Endpoint")
    print("=" * 60)
    
    response = client.chat.completions.create(
        model="meta-llama/Llama-3.2-3B-Instruct",
        messages=[
            {"role": "system", "content": "You are a helpful AI assistant."},
            {"role": "user", "content": "Explain quantum computing in simple terms."},
        ],
        max_tokens=300,
        temperature=0.7,
    )
    
    print(f"Response: {response.choices[0].message.content}")
    print()


def test_streaming():
    """Test streaming responses"""
    print("=" * 60)
    print("Testing Streaming Response")
    print("=" * 60)
    
    stream = client.chat.completions.create(
        model="meta-llama/Llama-3.2-3B-Instruct",
        messages=[
            {"role": "user", "content": "Write a haiku about artificial intelligence."},
        ],
        max_tokens=100,
        temperature=0.8,
        stream=True,
    )
    
    print("Streaming response: ", end="", flush=True)
    for chunk in stream:
        if chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="", flush=True)
    print("\n")


def list_models():
    """List available models"""
    print("=" * 60)
    print("Available Models")
    print("=" * 60)
    
    models = client.models.list()
    for model in models.data:
        print(f"  - {model.id}")
    print()


if __name__ == "__main__":
    try:
        print("\nvLLM OpenAI-Compatible API Client Example\n")
        
        # List available models
        list_models()
        
        # Test different endpoints
        test_completion()
        test_chat_completion()
        test_streaming()
        
        print("=" * 60)
        print("✓ All tests completed successfully!")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nMake sure the vLLM server is running:")
        print("  docker-compose up -d")
        print("\nCheck server status:")
        print("  docker-compose ps")
        print("  docker-compose logs vllm-api")

