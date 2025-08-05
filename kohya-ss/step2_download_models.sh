#!/bin/bash

# WAN2.2 Model Download Script
# Downloads all required models for training

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

echo "========================================="
echo "WAN2.2 Model Download"
echo "========================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check aria2c
if ! command -v aria2c &> /dev/null; then
    print_warning "aria2c not found. Downloads will be slower."
    print_info "Install with: sudo apt-get install aria2"
    USE_ARIA2=false
else
    print_status "Using aria2c for fast downloads"
    USE_ARIA2=true
fi

# Model directory
MODEL_DIR="musubi-tuner/models"
mkdir -p "$MODEL_DIR"/{diffusion_models,text_encoders,vae}

# Check disk space
print_info "Checking disk space..."
REQUIRED_SPACE_GB=35
AVAILABLE_SPACE_KB=$(df -k "$SCRIPT_DIR" | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))

if [ "$AVAILABLE_SPACE_GB" -lt "$REQUIRED_SPACE_GB" ]; then
    print_error "Insufficient disk space! Need ${REQUIRED_SPACE_GB}GB, have ${AVAILABLE_SPACE_GB}GB"
    exit 1
else
    print_status "Disk space OK (${AVAILABLE_SPACE_GB}GB available)"
fi

# Download function
download_model() {
    local url=$1
    local dir=$2
    local filename=$3
    local size_mb=$4
    local description=$5
    
    local filepath="$dir/$filename"
    
    # Check if already exists
    if [ -f "$filepath" ]; then
        local file_size=$(du -m "$filepath" | cut -f1)
        if [ "$file_size" -ge "$size_mb" ]; then
            print_status "$description already downloaded"
            return
        else
            print_warning "$description incomplete, redownloading..."
        fi
    fi
    
    print_info "Downloading $description..."
    mkdir -p "$dir"
    
    if [ "$USE_ARIA2" = true ]; then
        aria2c -x 16 -s 16 -k 1M --check-certificate=false \
               --file-allocation=none --continue=true \
               --dir="$dir" --out="$filename" "$url"
    else
        wget -c -O "$filepath" "$url"
    fi
}

# Download models
echo ""
print_info "Downloading models (total ~30GB)..."
echo ""

download_model \
    "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-720P/resolve/main/models_t5_umt5-xxl-enc-bf16.pth" \
    "$MODEL_DIR/text_encoders" \
    "models_t5_umt5-xxl-enc-bf16.pth" \
    4700 \
    "T5 Text Encoder (4.7GB)"

download_model \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "$MODEL_DIR/vae" \
    "wan_2.1_vae.safetensors" \
    240 \
    "VAE Model (240MB)"

download_model \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors" \
    "$MODEL_DIR/diffusion_models" \
    "wan2.2_t2v_high_noise_14B_fp16.safetensors" \
    13000 \
    "High Noise Model (13GB)"

download_model \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors" \
    "$MODEL_DIR/diffusion_models" \
    "wan2.2_t2v_low_noise_14B_fp16.safetensors" \
    13000 \
    "Low Noise Model (13GB)"

# Create model paths configuration
print_info "Creating model configuration..."
cat > model_paths.sh << EOF
#!/bin/bash
# Model paths for WAN2.2 training

export WAN22_MODELS_DIR="$SCRIPT_DIR/$MODEL_DIR"
export WAN22_T5_MODEL="\$WAN22_MODELS_DIR/text_encoders/models_t5_umt5-xxl-enc-bf16.pth"
export WAN22_VAE_MODEL="\$WAN22_MODELS_DIR/vae/wan_2.1_vae.safetensors"
export WAN22_HIGH_NOISE_MODEL="\$WAN22_MODELS_DIR/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors"
export WAN22_LOW_NOISE_MODEL="\$WAN22_MODELS_DIR/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"
EOF

chmod +x model_paths.sh
print_status "Model configuration created"

# Summary
echo ""
echo "========================================="
echo "Download Complete!"
echo "========================================="
echo ""
echo "Models saved to: $MODEL_DIR/"
echo ""
echo "Next steps:"
echo "1. Add training images to: dataset/images/"
echo "2. Create caption files (.txt) for each image"
echo "3. Run training: ./train_lora_simple.sh \"LoRA_Name\" \"trigger\""