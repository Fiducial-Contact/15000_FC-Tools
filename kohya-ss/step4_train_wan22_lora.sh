#!/bin/bash

# WAN2.2 LoRA Training Script
# Trains both high-noise and low-noise models automatically
# Based on AI_Characters' recommended settings

set -e

echo "========================================="
echo "WAN2.2 LoRA Training Script"
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

# Default parameters
LORA_NAME="MyWAN22LoRA"
AUTHOR_NAME="YourName"
TRIGGER_PHRASE="your trigger phrase"
MAX_EPOCHS=100
SAVE_EVERY_N_EPOCHS=100
LEARNING_RATE="3e-4"
NETWORK_DIM=16
NETWORK_ALPHA=16
BATCH_SIZE=1
GRADIENT_ACCUMULATION=1
SEED=5
GPU_MEMORY_FRACTION=""
BLOCKS_TO_SWAP=""
USE_CACHED_LATENTS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            LORA_NAME="$2"
            shift 2
            ;;
        --author)
            AUTHOR_NAME="$2"
            shift 2
            ;;
        --trigger)
            TRIGGER_PHRASE="$2"
            shift 2
            ;;
        --epochs)
            MAX_EPOCHS="$2"
            shift 2
            ;;
        --lr)
            LEARNING_RATE="$2"
            shift 2
            ;;
        --dim)
            NETWORK_DIM="$2"
            shift 2
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --gradient-accumulation)
            GRADIENT_ACCUMULATION="$2"
            shift 2
            ;;
        --seed)
            SEED="$2"
            shift 2
            ;;
        --low-memory)
            BLOCKS_TO_SWAP="20"
            shift
            ;;
        --use-cache)
            USE_CACHED_LATENTS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --name NAME               LoRA name (default: MyWAN22LoRA)"
            echo "  --author AUTHOR           Author name (default: YourName)"
            echo "  --trigger PHRASE          Trigger phrase for the LoRA"
            echo "  --epochs N                Max training epochs (default: 100)"
            echo "  --lr RATE                 Learning rate (default: 3e-4)"
            echo "  --dim N                   Network dimension (default: 16)"
            echo "  --batch-size N            Batch size (default: 1)"
            echo "  --gradient-accumulation N Gradient accumulation steps (default: 1)"
            echo "  --seed N                  Random seed (default: 5)"
            echo "  --low-memory              Enable low memory mode (16GB GPUs)"
            echo "  --use-cache               Use cached latents if available"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check environment
ENV_NAME="wan22_lora"
if ! conda env list | grep -q "^${ENV_NAME} "; then
    print_error "Conda environment '${ENV_NAME}' not found. Please run ./step1_setup_environment.sh first"
    exit 1
fi

# Note: We'll use conda run instead of activating the environment
print_info "Using conda environment '${ENV_NAME}' for training..."

# Check for models
if [ ! -f "model_paths.sh" ]; then
    print_error "Models not found. Please run ./download_models.sh first"
    exit 1
fi

# Source model paths
source model_paths.sh

# Check dataset
DATASET_CONFIG="$SCRIPT_DIR/dataset/dataset.toml"
if [ ! -f "$DATASET_CONFIG" ]; then
    print_error "Dataset configuration not found. Please run ./step3_prepare_dataset.sh first"
    exit 1
fi

# Check for actual dataset files
image_count=$(find "$SCRIPT_DIR/dataset/images" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)
video_count=$(find "$SCRIPT_DIR/dataset/videos" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null | wc -l)

if [ "$image_count" -eq 0 ] && [ "$video_count" -eq 0 ]; then
    print_error "No training data found!"
    echo ""
    echo "Please add your training data:"
    echo "  1. Copy images to: $SCRIPT_DIR/dataset/images/"
    echo "  2. Create .txt caption files for each image"
    echo "  3. Include trigger phrase \"$TRIGGER_PHRASE\" in all captions"
    echo ""
    echo "See dataset/PREPARE_YOUR_DATA_HERE.md for detailed instructions"
    exit 1
fi

print_info "Found $image_count images and $video_count videos in dataset"

# Check for captions
missing_captions=0
if [ "$image_count" -gt 0 ]; then
    for img in "$SCRIPT_DIR/dataset/images"/*.jpg "$SCRIPT_DIR/dataset/images"/*.jpeg "$SCRIPT_DIR/dataset/images"/*.png "$SCRIPT_DIR/dataset/images"/*.webp; do
        [ -f "$img" ] || continue
        base_name=$(basename "$img" | sed 's/\.[^.]*$//')
        caption_file="$SCRIPT_DIR/dataset/images/${base_name}.txt"
        if [ ! -f "$caption_file" ]; then
            missing_captions=$((missing_captions + 1))
        fi
    done
fi

if [ "$missing_captions" -gt 0 ]; then
    print_warning "Found $missing_captions images without captions"
    echo "Each image needs a corresponding .txt file with a caption"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check GPU memory and adjust settings
if command -v nvidia-smi &> /dev/null; then
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    print_info "GPU Memory: ${GPU_MEMORY}MB"
    
    if [ "$GPU_MEMORY" -lt 16000 ] && [ -z "$BLOCKS_TO_SWAP" ]; then
        print_warning "GPU has less than 16GB memory. Enabling low memory mode..."
        BLOCKS_TO_SWAP="20"
    fi
fi

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/output"
mkdir -p "$OUTPUT_DIR"

# Create training info file
cat > "$OUTPUT_DIR/training_info.txt" << EOF
WAN2.2 LoRA Training Information
================================
Date: $(date)
Name: $LORA_NAME
Author: $AUTHOR_NAME
Trigger: $TRIGGER_PHRASE

Training Parameters:
- Network Dimension: $NETWORK_DIM
- Network Alpha: $NETWORK_ALPHA
- Learning Rate: $LEARNING_RATE
- Max Epochs: $MAX_EPOCHS
- Batch Size: $BATCH_SIZE
- Gradient Accumulation: $GRADIENT_ACCUMULATION
- Seed: $SEED
- Low Memory Mode: $([ -n "$BLOCKS_TO_SWAP" ] && echo "Yes (blocks_to_swap=$BLOCKS_TO_SWAP)" || echo "No")
- Cached Latents: $USE_CACHED_LATENTS

Models:
- High Noise: wan2.2_t2v_high_noise_14B_fp16.safetensors
- Low Noise: wan2.2_t2v_low_noise_14B_fp16.safetensors
EOF

# Function to train a model
train_model() {
    local model_type=$1
    local model_path=$2
    local min_timestep=$3
    local max_timestep=$4
    
    echo ""
    echo "========================================="
    echo "Training $model_type Model"
    echo "========================================="
    echo "Timestep range: $min_timestep - $max_timestep"
    echo ""
    
    local output_name="${LORA_NAME}-${model_type}"
    local title="${LORA_NAME}-${model_type}"
    
    # Build training command
    local cmd="python -m accelerate launch --num_cpu_threads_per_process 1"
    cmd="$cmd src/musubi_tuner/wan_train_network.py"
    cmd="$cmd --task t2v-A14B"
    cmd="$cmd --dit \"$model_path\""
    cmd="$cmd --vae \"$WAN22_VAE_MODEL\""
    cmd="$cmd --t5 \"$WAN22_T5_MODEL\""
    cmd="$cmd --dataset_config \"$DATASET_CONFIG\""
    cmd="$cmd --xformers"
    cmd="$cmd --mixed_precision fp16"
    cmd="$cmd --fp8_base"
    cmd="$cmd --optimizer_type adamw"
    cmd="$cmd --learning_rate $LEARNING_RATE"
    cmd="$cmd --gradient_checkpointing"
    cmd="$cmd --gradient_accumulation_steps $GRADIENT_ACCUMULATION"
    cmd="$cmd --max_data_loader_n_workers 2"
    cmd="$cmd --network_module networks.lora_wan"
    cmd="$cmd --network_dim $NETWORK_DIM"
    cmd="$cmd --network_alpha $NETWORK_ALPHA"
    cmd="$cmd --timestep_sampling shift"
    cmd="$cmd --discrete_flow_shift 1.0"
    cmd="$cmd --max_train_epochs $MAX_EPOCHS"
    cmd="$cmd --save_every_n_epochs $SAVE_EVERY_N_EPOCHS"
    cmd="$cmd --seed $SEED"
    cmd="$cmd --optimizer_args weight_decay=0.1"
    cmd="$cmd --max_grad_norm 0"
    cmd="$cmd --lr_scheduler polynomial"
    cmd="$cmd --lr_scheduler_power 8"
    cmd="$cmd --lr_scheduler_min_lr_ratio=5e-5"
    cmd="$cmd --output_dir \"$OUTPUT_DIR\""
    cmd="$cmd --output_name \"$output_name\""
    cmd="$cmd --metadata_title \"$title\""
    cmd="$cmd --metadata_author \"$AUTHOR_NAME\""
    cmd="$cmd --preserve_distribution_shape"
    cmd="$cmd --min_timestep $min_timestep"
    cmd="$cmd --max_timestep $max_timestep"
    
    if [ -n "$BLOCKS_TO_SWAP" ]; then
        cmd="$cmd --blocks_to_swap $BLOCKS_TO_SWAP"
    fi
    
    if [ "$USE_CACHED_LATENTS" = true ] && [ -d "$SCRIPT_DIR/dataset/cache" ]; then
        cmd="$cmd --cache_dir \"$SCRIPT_DIR/dataset/cache\""
    fi
    
    # Show command
    print_info "Training command:"
    echo "$cmd"
    echo ""
    
    # Execute training using conda run
    cd musubi-tuner
    conda run -n ${ENV_NAME} $cmd
    local exit_code=$?
    cd ..
    
    if [ $exit_code -eq 0 ]; then
        print_status "$model_type model training completed successfully"
        return 0
    else
        print_error "$model_type model training failed with exit code $exit_code"
        return $exit_code
    fi
}

# Main training sequence
echo "Starting WAN2.2 LoRA training..."
echo "This will train both high-noise and low-noise models"
echo ""

# Show trigger phrase reminder
print_warning "Make sure all your captions include the trigger phrase:"
print_warning "\"$TRIGGER_PHRASE\""
echo ""

read -p "Ready to start training? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Training cancelled"
    exit 0
fi

# Record start time
start_time=$(date +%s)

# Train high-noise model (timesteps 875-1000)
if train_model "HighNoise" "$WAN22_HIGH_NOISE_MODEL" 875 1000; then
    print_status "High-noise model training completed"
else
    print_error "High-noise model training failed"
    exit 1
fi

# Train low-noise model (timesteps 0-875)
if train_model "LowNoise" "$WAN22_LOW_NOISE_MODEL" 0 875; then
    print_status "Low-noise model training completed"
else
    print_error "Low-noise model training failed"
    exit 1
fi

# Calculate total time
end_time=$(date +%s)
duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))

# Final summary
echo ""
echo "========================================="
echo "Training Complete!"
echo "========================================="
echo ""
echo "Total training time: ${hours}h ${minutes}m"
echo ""
echo "Output files:"
ls -la "$OUTPUT_DIR"/${LORA_NAME}-*.safetensors 2>/dev/null || echo "No output files found"
echo ""
echo "To use your LoRA:"
echo "1. Load both files in ComfyUI:"
echo "   - ${LORA_NAME}-HighNoise.safetensors"
echo "   - ${LORA_NAME}-LowNoise.safetensors"
echo "2. Set strength to 1.0 for both (not 3.0 as with older versions)"
echo "3. Use your trigger phrase: \"$TRIGGER_PHRASE\""
echo ""
echo "Recommended: Use AI_Characters' WAN2.2 workflow:"
echo "https://www.dropbox.com/scl/fi/pfpzff7eyjcql0uetj1at/WAN2.2_recommended_default_text2image_inference_workflow_by_AI_Characters-v3.json"