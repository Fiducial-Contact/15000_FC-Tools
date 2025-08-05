#!/bin/bash

# WAN2.2 Model Download Script - Parallel Version
# Downloads all models simultaneously for maximum speed
# Uses aria2c with optimized settings

set -e

echo "========================================="
echo "WAN2.2 Model Download Script (Parallel)"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if aria2c is installed
if ! command -v aria2c &> /dev/null; then
    print_error "aria2c not found. Please install it first:"
    echo "  Ubuntu/Debian: sudo apt-get install aria2"
    echo "  MacOS: brew install aria2"
    exit 1
fi

# Model directory
MODEL_DIR="musubi-tuner/models"
mkdir -p "$MODEL_DIR"/{diffusion_models,text_encoders,vae}

# Create download list file
DOWNLOAD_LIST="$SCRIPT_DIR/download_list.txt"
rm -f "$DOWNLOAD_LIST"

# Model URLs and paths
cat > "$DOWNLOAD_LIST" << EOF
https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-720P/resolve/main/models_t5_umt5-xxl-enc-bf16.pth
	dir=$MODEL_DIR/text_encoders
	out=models_t5_umt5-xxl-enc-bf16.pth

https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors
	dir=$MODEL_DIR/vae
	out=wan_2.1_vae.safetensors

https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors
	dir=$MODEL_DIR/diffusion_models
	out=wan2.2_t2v_high_noise_14B_fp16.safetensors

https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors
	dir=$MODEL_DIR/diffusion_models
	out=wan2.2_t2v_low_noise_14B_fp16.safetensors
EOF

echo "Starting parallel downloads..."
echo "Total download size: ~30GB"
echo ""
print_info "Downloading all models simultaneously for maximum speed"
echo ""

# Download all files in parallel with aria2c
# Optimized settings for maximum speed:
aria2c \
    --input-file="$DOWNLOAD_LIST" \
    --max-concurrent-downloads=4 \
    --split=16 \
    --max-connection-per-server=16 \
    --min-split-size=1M \
    --check-certificate=false \
    --file-allocation=none \
    --continue=true \
    --auto-file-renaming=false \
    --allow-overwrite=true \
    --console-log-level=info \
    --summary-interval=5 \
    --download-result=full \
    --human-readable=true

# Clean up
rm -f "$DOWNLOAD_LIST"

# Function to check file existence and size
check_model() {
    local file_path=$1
    local expected_size=$2  # in MB
    
    if [ -f "$file_path" ]; then
        local file_size=$(du -m "$file_path" | cut -f1)
        if [ "$file_size" -ge "$expected_size" ]; then
            return 0
        else
            print_warning "File exists but seems incomplete (${file_size}MB, expected >${expected_size}MB)"
            return 1
        fi
    else
        return 1
    fi
}

# Create model path configuration file
echo ""
print_info "Creating model path configuration..."

cat > model_paths.sh << EOF
#!/bin/bash
# Model paths for WAN2.2 training
# Source this file to set environment variables

export WAN22_MODELS_DIR="$SCRIPT_DIR/$MODEL_DIR"
export WAN22_T5_MODEL="\$WAN22_MODELS_DIR/text_encoders/models_t5_umt5-xxl-enc-bf16.pth"
export WAN22_VAE_MODEL="\$WAN22_MODELS_DIR/vae/wan_2.1_vae.safetensors"
export WAN22_HIGH_NOISE_MODEL="\$WAN22_MODELS_DIR/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors"
export WAN22_LOW_NOISE_MODEL="\$WAN22_MODELS_DIR/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"

echo "Model paths loaded:"
echo "  T5: \$WAN22_T5_MODEL"
echo "  VAE: \$WAN22_VAE_MODEL"
echo "  High Noise: \$WAN22_HIGH_NOISE_MODEL"
echo "  Low Noise: \$WAN22_LOW_NOISE_MODEL"
EOF

chmod +x model_paths.sh
print_status "Created model_paths.sh configuration file"

# Verify all downloads
echo ""
echo "========================================="
echo "Verifying downloads..."
echo "========================================="

all_good=true

if check_model "$MODEL_DIR/text_encoders/models_t5_umt5-xxl-enc-bf16.pth" 4700; then
    print_status "T5 Text Encoder: OK"
else
    print_error "T5 Text Encoder: Missing or incomplete"
    all_good=false
fi

if check_model "$MODEL_DIR/vae/wan_2.1_vae.safetensors" 650; then
    print_status "VAE Model: OK"
else
    print_error "VAE Model: Missing or incomplete"
    all_good=false
fi

if check_model "$MODEL_DIR/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors" 13000; then
    print_status "High Noise Model: OK"
else
    print_error "High Noise Model: Missing or incomplete"
    all_good=false
fi

if check_model "$MODEL_DIR/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors" 13000; then
    print_status "Low Noise Model: OK"
else
    print_error "Low Noise Model: Missing or incomplete"
    all_good=false
fi

# Final summary
echo ""
echo "========================================="
if [ "$all_good" = true ]; then
    echo "All models downloaded successfully!"
    echo "========================================="
    echo ""
    echo "Model locations:"
    echo "  $MODEL_DIR/"
    echo "  ├── text_encoders/"
    echo "  │   └── models_t5_umt5-xxl-enc-bf16.pth"
    echo "  ├── vae/"
    echo "  │   └── wan_2.1_vae.safetensors"
    echo "  └── diffusion_models/"
    echo "      ├── wan2.2_t2v_high_noise_14B_fp16.safetensors"
    echo "      └── wan2.2_t2v_low_noise_14B_fp16.safetensors"
    echo ""
    echo "Next step: Prepare your dataset and run ./step3_prepare_dataset.sh"
else
    echo "Some models are missing!"
    echo "========================================="
    echo ""
    echo "Please run this script again to retry failed downloads."
    echo "The script will resume from where it left off."
    exit 1
fi