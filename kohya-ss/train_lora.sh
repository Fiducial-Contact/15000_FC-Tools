#!/bin/bash

# WAN2.2 LoRA Training Script - Simplified Version
# Combines functionality from multiple scripts for easier use
# Usage: ./train_lora_simple.sh "LoRA_Name" "trigger phrase" [author_name]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
echo "WAN2.2 LoRA Training - Simplified"
echo "========================================="
echo ""

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 \"LoRA_Name\" \"trigger phrase\" [author_name]"
    echo ""
    echo "Example:"
    echo "  $0 \"MyStyle\" \"mystyle photo\" \"YourName\""
    exit 1
fi

LORA_NAME="$1"
TRIGGER_PHRASE="$2"
AUTHOR_NAME="${3:-$USER}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check environment
ENV_NAME="wan22_lora"
if ! conda env list | grep -q "^${ENV_NAME} "; then
    print_error "Conda environment '${ENV_NAME}' not found!"
    echo ""
    echo "Please run ./setup_environment.sh first"
    exit 1
fi

# Check models
if [ ! -f "model_paths.sh" ]; then
    print_error "Models not found. Please run ./download_models.sh first"
    exit 1
fi

# Source model paths
source model_paths.sh

# Check dataset
image_count=$(find "$SCRIPT_DIR/dataset/images" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)

if [ "$image_count" -eq 0 ]; then
    print_error "No images found in dataset/images/"
    echo ""
    echo "Please add your training images with captions first."
    echo "Each image needs a corresponding .txt file."
    exit 1
fi

print_status "Found $image_count images in dataset"

# Check for captions
missing_captions=0
for img in "$SCRIPT_DIR/dataset/images"/*.jpg "$SCRIPT_DIR/dataset/images"/*.jpeg "$SCRIPT_DIR/dataset/images"/*.png "$SCRIPT_DIR/dataset/images"/*.webp; do
    [ -f "$img" ] || continue
    base_name=$(basename "$img" | sed 's/\.[^.]*$//')
    caption_file="$SCRIPT_DIR/dataset/images/${base_name}.txt"
    if [ ! -f "$caption_file" ]; then
        missing_captions=$((missing_captions + 1))
    fi
done

if [ "$missing_captions" -gt 0 ]; then
    print_warning "Found $missing_captions images without captions"
fi

# Create dataset.toml if needed
if [ ! -f "dataset/dataset.toml" ]; then
    print_info "Creating dataset configuration..."
    mkdir -p dataset
    cat > "dataset/dataset.toml" << 'EOF'
# WAN2.2 LoRA Training Dataset Configuration

[general]
enable_bucket = true
resolution = 768
batch_size = 1

[[datasets]]
resolution = 768
batch_size = 1
keep_tokens = 1

  [[datasets.subsets]]
  image_dir = "./dataset/images"
  caption_extension = ".txt"
  num_repeats = 1
  shuffle_caption = true
  keep_tokens = 1
EOF
    print_status "Dataset configuration created"
fi

# Training settings
MAX_EPOCHS=100
LEARNING_RATE="3e-4"
NETWORK_DIM=16
NETWORK_ALPHA=16

# Check GPU memory
if command -v nvidia-smi &> /dev/null; then
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    print_info "GPU Memory: ${GPU_MEMORY}MB"
    
    if [ "$GPU_MEMORY" -lt 16000 ]; then
        BLOCKS_TO_SWAP="20"
        print_warning "Low GPU memory detected. Enabling memory optimization."
    else
        BLOCKS_TO_SWAP=""
    fi
fi

# Summary
echo ""
echo "Training Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LoRA Name: $LORA_NAME"
echo "  Trigger: $TRIGGER_PHRASE"
echo "  Author: $AUTHOR_NAME"
echo "  Dataset: $image_count images"
echo "  Learning Rate: $LEARNING_RATE"
echo "  Network Dim: $NETWORK_DIM"
echo "  Epochs: $MAX_EPOCHS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Confirm
read -p "Start training? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Training cancelled"
    exit 0
fi

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/output"
mkdir -p "$OUTPUT_DIR"

# Function to train a model
train_model() {
    local model_type=$1
    local model_path=$2
    local min_timestep=$3
    local max_timestep=$4
    
    echo ""
    echo "Training $model_type Model (timesteps $min_timestep-$max_timestep)..."
    
    # Build command
    local cmd="python -m accelerate launch --num_cpu_threads_per_process 1"
    cmd="$cmd src/musubi_tuner/wan_train_network.py"
    cmd="$cmd --task t2v-A14B"
    cmd="$cmd --dit \"$model_path\""
    cmd="$cmd --vae \"$WAN22_VAE_MODEL\""
    cmd="$cmd --t5 \"$WAN22_T5_MODEL\""
    cmd="$cmd --dataset_config \"$SCRIPT_DIR/dataset/dataset.toml\""
    cmd="$cmd --xformers"
    cmd="$cmd --mixed_precision fp16"
    cmd="$cmd --fp8_base"
    cmd="$cmd --optimizer_type adamw"
    cmd="$cmd --learning_rate $LEARNING_RATE"
    cmd="$cmd --gradient_checkpointing"
    cmd="$cmd --gradient_accumulation_steps 1"
    cmd="$cmd --max_data_loader_n_workers 2"
    cmd="$cmd --network_module networks.lora_wan"
    cmd="$cmd --network_dim $NETWORK_DIM"
    cmd="$cmd --network_alpha $NETWORK_ALPHA"
    cmd="$cmd --timestep_sampling shift"
    cmd="$cmd --discrete_flow_shift 1.0"
    cmd="$cmd --max_train_epochs $MAX_EPOCHS"
    cmd="$cmd --save_every_n_epochs $MAX_EPOCHS"
    cmd="$cmd --seed 5"
    cmd="$cmd --optimizer_args weight_decay=0.1"
    cmd="$cmd --max_grad_norm 0"
    cmd="$cmd --lr_scheduler polynomial"
    cmd="$cmd --lr_scheduler_power 8"
    cmd="$cmd --lr_scheduler_min_lr_ratio=5e-5"
    cmd="$cmd --output_dir \"$OUTPUT_DIR\""
    cmd="$cmd --output_name \"${LORA_NAME}-${model_type}\""
    cmd="$cmd --metadata_title \"${LORA_NAME}-${model_type}\""
    cmd="$cmd --metadata_author \"$AUTHOR_NAME\""
    cmd="$cmd --preserve_distribution_shape"
    cmd="$cmd --min_timestep $min_timestep"
    cmd="$cmd --max_timestep $max_timestep"
    
    if [ -n "$BLOCKS_TO_SWAP" ]; then
        cmd="$cmd --blocks_to_swap $BLOCKS_TO_SWAP"
    fi
    
    # Execute in musubi-tuner directory with conda run
    cd musubi-tuner
    conda run -n ${ENV_NAME} bash -c "$cmd"
    local exit_code=$?
    cd ..
    
    if [ $exit_code -eq 0 ]; then
        print_status "$model_type model training completed"
        return 0
    else
        print_error "$model_type model training failed"
        return $exit_code
    fi
}

# Start training
start_time=$(date +%s)

print_info "Training will create two models:"
print_info "1. High-noise model (timesteps 875-1000)"
print_info "2. Low-noise model (timesteps 0-875)"
echo ""

# Train high-noise model
if train_model "HighNoise" "$WAN22_HIGH_NOISE_MODEL" 875 1000; then
    print_status "High-noise model complete"
else
    print_error "High-noise model failed"
    exit 1
fi

# Train low-noise model
if train_model "LowNoise" "$WAN22_LOW_NOISE_MODEL" 0 875; then
    print_status "Low-noise model complete"
else
    print_error "Low-noise model failed"
    exit 1
fi

# Calculate time
end_time=$(date +%s)
duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))

# Summary
echo ""
echo "========================================="
echo "Training Complete!"
echo "========================================="
echo ""
echo "Time: ${hours}h ${minutes}m"
echo ""
echo "Output files:"
ls -la "$OUTPUT_DIR"/${LORA_NAME}-*.safetensors 2>/dev/null || echo "No output files found"
echo ""
echo "To use your LoRA in ComfyUI:"
echo "1. Load both files:"
echo "   - ${LORA_NAME}-HighNoise.safetensors"
echo "   - ${LORA_NAME}-LowNoise.safetensors"
echo "2. Set strength to 1.0 for both"
echo "3. Use trigger phrase: \"$TRIGGER_PHRASE\""
echo ""
echo "Recommended workflow:"
echo "https://www.dropbox.com/scl/fi/pfpzff7eyjcql0uetj1at/WAN2.2_recommended_default_text2image_inference_workflow_by_AI_Characters-v3.json"