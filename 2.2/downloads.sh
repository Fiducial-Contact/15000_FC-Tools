#!/bin/bash

# Wan2.2 5B Model Download Script
# This script downloads all required model files for Wan2.2 5B training
# Uses aria2c for efficient parallel downloads

echo "==================================="
echo "Wan2.2 5B Model Download Script"
echo "==================================="

# Create directory structure
echo "Creating directory structure..."
mkdir -p models/Wan2.2-TI2V-5B
mkdir -p models/vae
mkdir -p models/text_encoders
mkdir -p models/comfyui_safetensors

# Function to check if aria2c is installed
check_aria2c() {
    if ! command -v aria2c &> /dev/null; then
        echo "aria2c is not installed. Installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y aria2
        elif command -v yum &> /dev/null; then
            sudo yum install -y aria2
        else
            echo "Please install aria2 manually: https://aria2.github.io/"
            exit 1
        fi
    fi
}

check_aria2c

echo ""
echo "=== Option 1: Download from HuggingFace (Recommended) ==="
echo ""

# Download Wan2.2-TI2V-5B from HuggingFace
echo "Downloading Wan2.2-TI2V-5B model..."
cat << 'EOF' > wan22_5b_download.txt
# Wan2.2-TI2V-5B model files
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/config.json
  dir=models/Wan2.2-TI2V-5B
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model.safetensors.index.json
  dir=models/Wan2.2-TI2V-5B
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/diffusion_pytorch_model-00001-of-00003.safetensors
  dir=models/Wan2.2-TI2V-5B
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/diffusion_pytorch_model-00002-of-00003.safetensors
  dir=models/Wan2.2-TI2V-5B
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/diffusion_pytorch_model-00003-of-00003.safetensors
  dir=models/Wan2.2-TI2V-5B
EOF

echo "Starting Wan2.2-TI2V-5B download with aria2c..."
aria2c -x 16 -s 16 -j 5 -c --auto-file-renaming=false -i wan22_5b_download.txt

# Download VAE
echo ""
echo "Downloading Wan2.2 VAE..."
cat << 'EOF' > wan22_vae_download.txt
# Wan2.2 VAE - Critical: This is different from Wan2.1 VAE!
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/Wan2.2_VAE.pth
  dir=models/vae
  out=Wan2.2_VAE.pth
EOF

aria2c -x 16 -s 16 -c --auto-file-renaming=false -i wan22_vae_download.txt

# Download UMT5-XXL text encoder
echo ""
echo "Downloading UMT5-XXL text encoder..."
cat << 'EOF' > umt5_download.txt
# UMT5-XXL text encoder
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/models_t5_umt5-xxl-enc-bf16.pth
  dir=models/text_encoders
  out=umt5-xxl-enc-bf16.pth
EOF

aria2c -x 16 -s 16 -c --auto-file-renaming=false -i umt5_download.txt

echo ""
echo "=== Option 2: ComfyUI Safetensors (Alternative) ==="
echo ""
echo "If you prefer ComfyUI safetensors format, download these files:"
echo ""

cat << 'EOF' > comfyui_downloads.txt
# ComfyUI Wan2.2 5B safetensors
https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors
  dir=models/comfyui_safetensors
  out=wan2.2_ti2v_5B_fp16.safetensors

# ComfyUI Wan2.2 VAE
https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
  dir=models/comfyui_safetensors
  out=wan2.2_vae.safetensors

# ComfyUI UMT5-XXL (fp16 version)
https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors
  dir=models/comfyui_safetensors
  out=umt5_xxl_fp16.safetensors
EOF

echo "To download ComfyUI versions, run:"
echo "aria2c -x 16 -s 16 -j 3 -c --auto-file-renaming=false -i comfyui_downloads.txt"

echo ""
echo "=== Option 3: Download Specific Model Parts ==="
echo ""

# If user only needs specific parts (e.g., skipping transformer if using ComfyUI safetensors)
cat << 'EOF' > wan22_minimal_download.txt
# Minimal download - only config and VAE (if using ComfyUI transformer)
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/config.json
  dir=models/Wan2.2-TI2V-5B
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model_index.json
  dir=models/Wan2.2-TI2V-5B
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/Wan2.2_VAE.pth
  dir=models/vae
  out=Wan2.2_VAE.pth
EOF

echo "For minimal download (config + VAE only), run:"
echo "aria2c -x 16 -s 16 -c --auto-file-renaming=false -i wan22_minimal_download.txt"

echo ""
echo "=== Download Summary ==="
echo ""
echo "Total download size:"
echo "- Full Wan2.2-TI2V-5B model: ~10GB"
echo "- Wan2.2 VAE: ~1.4GB"
echo "- UMT5-XXL text encoder: ~9.2GB"
echo "- Total: ~20.6GB"
echo ""
echo "ComfyUI alternative sizes:"
echo "- wan2.2_ti2v_5B_fp16.safetensors: ~9.9GB"
echo "- wan2.2_vae.safetensors: ~1.4GB"
echo "- umt5_xxl_fp16.safetensors: ~9.2GB"
echo ""

# Clean up temporary files
rm -f wan22_5b_download.txt wan22_vae_download.txt umt5_download.txt

echo "==================================="
echo "Download script completed!"
echo "Check the models/ directory for downloaded files."
echo "==================================="

# Verify downloads
echo ""
echo "Verifying downloads..."
if [ -f "models/Wan2.2-TI2V-5B/config.json" ]; then
    echo "✓ Wan2.2-TI2V-5B config found"
else
    echo "✗ Wan2.2-TI2V-5B config missing"
fi

if [ -f "models/vae/Wan2.2_VAE.pth" ]; then
    echo "✓ Wan2.2 VAE found"
else
    echo "✗ Wan2.2 VAE missing"
fi

if [ -f "models/text_encoders/umt5-xxl-enc-bf16.pth" ]; then
    echo "✓ UMT5-XXL text encoder found"
else
    echo "✗ UMT5-XXL text encoder missing"
fi