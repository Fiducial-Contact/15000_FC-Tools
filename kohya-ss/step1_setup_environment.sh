#!/bin/bash

# WAN2.2 LoRA Training Environment Setup
# Simplified version - focuses on essential setup steps

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
echo "WAN2.2 LoRA Training Environment Setup"
echo "========================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check Python
echo "Checking system requirements..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
    print_status "Python $PYTHON_VERSION found"
else
    print_error "Python 3.10+ required, but $PYTHON_VERSION found"
    exit 1
fi

# Check GPU
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
    GPU_NAME=$(echo $GPU_INFO | cut -d',' -f1 | xargs)
    GPU_MEMORY=$(echo $GPU_INFO | cut -d',' -f2 | xargs)
    print_status "GPU: $GPU_NAME (${GPU_MEMORY}MB)"
    
    if [ "$GPU_MEMORY" -lt 16000 ]; then
        print_warning "GPU has less than 16GB VRAM. Training may be challenging."
    fi
else
    print_error "No GPU detected. WAN2.2 training requires CUDA GPU"
    exit 1
fi

# Check conda
if ! command -v conda &> /dev/null; then
    print_error "Conda not found. Please install miniconda or anaconda first."
    echo ""
    echo "Download from: https://docs.conda.io/en/latest/miniconda.html"
    exit 1
fi

print_status "Conda found"

# Clone musubi-tuner if needed
echo ""
echo "Setting up musubi-tuner repository..."
if [ -d "musubi-tuner" ]; then
    print_status "musubi-tuner already exists"
else
    print_info "Cloning musubi-tuner..."
    git clone --recursive https://github.com/kohya-ss/musubi-tuner.git
    cd musubi-tuner
    git checkout feature-wan-2-2
    git checkout d0a193061a23a51c90664282205d753605a641c1
    cd ..
    print_status "Repository cloned"
fi

# Create/check conda environment
ENV_NAME="wan22_lora"
echo ""
echo "Setting up conda environment..."

if conda env list | grep -q "^${ENV_NAME} "; then
    print_status "Conda environment '${ENV_NAME}' already exists"
else
    print_info "Creating conda environment '${ENV_NAME}'..."
    conda create -n ${ENV_NAME} python=3.10 -y
    print_status "Environment created"
fi

# Install packages
echo ""
echo "Installing packages (this may take several minutes)..."

# Install PyTorch with CUDA
print_info "Installing PyTorch 2.7.0..."
conda run -n ${ENV_NAME} python -m pip install --timeout=120 torch==2.7.0 torchvision==0.22.0 xformers==0.0.30 --index-url https://download.pytorch.org/whl/cu128

# Install musubi-tuner
print_info "Installing musubi-tuner..."
cd musubi-tuner
conda run -n ${ENV_NAME} python -m pip install -e .
cd ..

# Install protobuf via conda (more reliable)
print_info "Installing protobuf..."
conda install -n ${ENV_NAME} protobuf -y

# Create directories
echo ""
print_info "Creating directory structure..."
mkdir -p musubi-tuner/{models/{diffusion_models,text_encoders,vae},output,logs}
mkdir -p dataset/{images,videos}
print_status "Directories created"

# Final verification
echo ""
print_info "Verifying installation..."
conda run -n ${ENV_NAME} python -c "
import torch
print(f'PyTorch: {torch.__version__}')
if torch.cuda.is_available():
    print(f'CUDA: Available ({torch.cuda.get_device_name(0)})')
else:
    print('CUDA: Not available')
    exit(1)
"

if [ $? -eq 0 ]; then
    print_status "Environment setup complete!"
else
    print_error "Environment verification failed"
    exit 1
fi

# Summary
echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Download models: ./step2_download_models.sh"
echo "2. Add training images to: dataset/images/"
echo "3. Create caption files (.txt) for each image"
echo "4. Run training: ./train_lora.sh \"LoRA_Name\" \"trigger\""
echo ""
echo "To verify environment anytime: ./verify_environment.sh"