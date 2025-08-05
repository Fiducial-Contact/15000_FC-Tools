#!/bin/bash

# WAN2.2 Model Download Script
# Downloads all required models for WAN2.2 LoRA training
# Includes integrity checking and resume support

set -e

echo "========================================="
echo "WAN2.2 Model Download Script"
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

# Check if huggingface-cli is installed
if ! command -v huggingface-cli &> /dev/null; then
    print_warning "huggingface-cli not found. Installing..."
    pip install huggingface-hub
fi

# Model directory
MODEL_DIR="musubi-tuner/models"
mkdir -p "$MODEL_DIR"/{diffusion_models,text_encoders,vae}

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

# Function to download with progress
download_model() {
    local repo_id=$1
    local filename=$2
    local local_dir=$3
    local expected_size=$4
    local description=$5
    
    local full_path="$local_dir/$filename"
    
    echo ""
    print_info "Checking $description..."
    
    if check_model "$full_path" "$expected_size"; then
        print_status "$description already downloaded"
        return 0
    fi
    
    print_info "Downloading $description..."
    print_info "This may take some time depending on your internet speed"
    
    # Use huggingface-cli for reliable downloads with resume support
    huggingface-cli download "$repo_id" "$filename" \
        --local-dir "$local_dir" \
        --local-dir-use-symlinks False \
        --resume-download
    
    if check_model "$full_path" "$expected_size"; then
        print_status "$description downloaded successfully"
    else
        print_error "Failed to download $description"
        return 1
    fi
}

# Download models
echo "Starting model downloads..."
echo "Total download size: ~30GB"
echo ""

# 1. T5 Text Encoder (UMT5-XXL)
download_model \
    "Wan-AI/Wan2.1-I2V-14B-720P" \
    "models_t5_umt5-xxl-enc-bf16.pth" \
    "$MODEL_DIR/text_encoders" \
    4700 \
    "T5 Text Encoder (UMT5-XXL)"

# 2. VAE Model
download_model \
    "Comfy-Org/Wan_2.1_ComfyUI_repackaged" \
    "split_files/vae/wan_2.1_vae.safetensors" \
    "$MODEL_DIR/vae" \
    650 \
    "WAN 2.1 VAE Model"

# 3. WAN2.2 High Noise Model
download_model \
    "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
    "split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors" \
    "$MODEL_DIR/diffusion_models" \
    13000 \
    "WAN2.2 High Noise Model (14B FP16)"

# 4. WAN2.2 Low Noise Model
download_model \
    "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" \
    "split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors" \
    "$MODEL_DIR/diffusion_models" \
    13000 \
    "WAN2.2 Low Noise Model (14B FP16)"

# Create model path configuration file
echo ""
print_info "Creating model path configuration..."

cat > model_paths.sh << EOF
#!/bin/bash
# Model paths for WAN2.2 training
# Source this file to set environment variables

export WAN22_MODELS_DIR="$SCRIPT_DIR/$MODEL_DIR"
export WAN22_T5_MODEL="\$WAN22_MODELS_DIR/text_encoders/models_t5_umt5-xxl-enc-bf16.pth"
export WAN22_VAE_MODEL="\$WAN22_MODELS_DIR/vae/split_files/vae/wan_2.1_vae.safetensors"
export WAN22_HIGH_NOISE_MODEL="\$WAN22_MODELS_DIR/diffusion_models/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors"
export WAN22_LOW_NOISE_MODEL="\$WAN22_MODELS_DIR/diffusion_models/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"

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

if check_model "$MODEL_DIR/vae/split_files/vae/wan_2.1_vae.safetensors" 650; then
    print_status "VAE Model: OK"
else
    print_error "VAE Model: Missing or incomplete"
    all_good=false
fi

if check_model "$MODEL_DIR/diffusion_models/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors" 13000; then
    print_status "High Noise Model: OK"
else
    print_error "High Noise Model: Missing or incomplete"
    all_good=false
fi

if check_model "$MODEL_DIR/diffusion_models/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors" 13000; then
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
    echo "  │   └── split_files/vae/wan_2.1_vae.safetensors"
    echo "  └── diffusion_models/"
    echo "      └── split_files/diffusion_models/"
    echo "          ├── wan2.2_t2v_high_noise_14B_fp16.safetensors"
    echo "          └── wan2.2_t2v_low_noise_14B_fp16.safetensors"
    echo ""
    echo "Next step: Prepare your dataset and run ./prepare_dataset.sh"
else
    echo "Some models are missing!"
    echo "========================================="
    echo ""
    echo "Please run this script again to retry failed downloads."
    echo "The script will resume from where it left off."
    exit 1
fi