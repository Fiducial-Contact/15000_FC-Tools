#!/bin/bash

# WAN2.2 LoRA Quick Training Script
# Simplified interface for fast training start
# Usage: ./quick_train.sh "LoRA_Name" "trigger phrase"

set -e

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

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "WAN2.2 LoRA Quick Training"
    echo ""
    echo "Usage: $0 \"LoRA_Name\" \"trigger phrase\" [author]"
    echo ""
    echo "Examples:"
    echo "  $0 \"AnimeStyle\" \"anime style art\""
    echo "  $0 \"PhotoRealistic\" \"photorealistic style\" \"YourName\""
    echo ""
    echo "Prerequisites:"
    echo "  1. Run ./step1_setup_environment.sh (first time only)"
    echo "  2. Run ./step2_download_models.sh (first time only)"
    echo "  3. Add images to dataset/images/ with .txt captions"
    echo ""
    exit 1
fi

LORA_NAME="$1"
TRIGGER_PHRASE="$2"
AUTHOR_NAME="${3:-Anonymous}"

echo "========================================="
echo "WAN2.2 LoRA Quick Training"
echo "========================================="
echo ""
print_info "LoRA Name: $LORA_NAME"
print_info "Trigger: $TRIGGER_PHRASE"
print_info "Author: $AUTHOR_NAME"
echo ""

# Quick checks
echo "Running quick checks..."

# Check if environment is set up
if [ ! -d "musubi-tuner/venv" ]; then
    print_error "Environment not set up. Please run:"
    print_error "  ./step1_setup_environment.sh"
    exit 1
fi

# Check if models are downloaded
if [ ! -f "model_paths.sh" ]; then
    print_error "Models not downloaded. Please run:"
    print_error "  ./step2_download_models.sh"
    exit 1
fi

# Check dataset
image_count=$(find "$SCRIPT_DIR/dataset/images" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)
caption_count=$(find "$SCRIPT_DIR/dataset/images" -type f -name "*.txt" 2>/dev/null | wc -l)

if [ "$image_count" -eq 0 ]; then
    print_error "No images found in dataset/images/"
    print_info "Please add your training images to: $SCRIPT_DIR/dataset/images/"
    exit 1
fi

print_status "Found $image_count images"

if [ "$caption_count" -lt "$image_count" ]; then
    print_warning "Found $caption_count captions for $image_count images"
    print_warning "Each image should have a corresponding .txt caption file"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_status "All images have captions"
fi

# Run dataset preparation
echo ""
echo "Preparing dataset..."
if ! bash "$SCRIPT_DIR/step3_prepare_dataset.sh"; then
    print_error "Dataset preparation failed"
    exit 1
fi

# Check GPU memory for optimization hints
GPU_MEMORY=0
if command -v nvidia-smi &> /dev/null; then
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 2>/dev/null || echo 0)
fi

EXTRA_ARGS=""
if [ "$GPU_MEMORY" -gt 0 ] && [ "$GPU_MEMORY" -lt 20000 ]; then
    print_warning "Detected GPU with ${GPU_MEMORY}MB memory"
    print_warning "Enabling memory optimizations..."
    EXTRA_ARGS="--low-memory"
fi

# Start training
echo ""
echo "========================================="
echo "Starting training..."
echo "========================================="
echo ""
echo "Training parameters:"
echo "  - Network dimension: 16"
echo "  - Learning rate: 3e-4"
echo "  - Max epochs: 100"
echo "  - Memory mode: $([ -n "$EXTRA_ARGS" ] && echo "Low (16GB)" || echo "Normal")"
echo ""

# Show estimated time
if [ "$image_count" -lt 50 ]; then
    echo "Estimated training time: 2-3 hours"
elif [ "$image_count" -lt 100 ]; then
    echo "Estimated training time: 3-4 hours"
else
    echo "Estimated training time: 4-6 hours"
fi
echo ""

read -p "Start training now? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    print_warning "Training cancelled"
    exit 0
fi

# Run training
if bash "$SCRIPT_DIR/step4_train_wan22_lora.sh" \
    --name "$LORA_NAME" \
    --author "$AUTHOR_NAME" \
    --trigger "$TRIGGER_PHRASE" \
    $EXTRA_ARGS; then
    
    echo ""
    echo "========================================="
    echo "Training Complete!"
    echo "========================================="
    echo ""
    print_status "Your LoRA files are ready:"
    echo "  - output/${LORA_NAME}-HighNoise.safetensors"
    echo "  - output/${LORA_NAME}-LowNoise.safetensors"
    echo ""
    echo "Usage instructions:"
    echo "  1. Load both files in ComfyUI"
    echo "  2. Set strength to 1.0"
    echo "  3. Use in prompts: \"$TRIGGER_PHRASE\""
    echo ""
else
    print_error "Training failed"
    exit 1
fi