#!/bin/bash

# WAN2.2 LoRA Training Environment Setup Script
# Based on AI_Characters' workflow and community best practices
# This script provides intelligent environment detection and setup

set -e

echo "========================================="
echo "WAN2.2 LoRA Training Environment Setup"
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

# Step 1: Check Python version
echo "Step 1: Checking Python version..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
    print_status "Python $PYTHON_VERSION is installed (3.10+ required)"
else
    print_error "Python 3.10+ is required, but $PYTHON_VERSION is installed"
    exit 1
fi

# Step 2: Check CUDA and GPU
echo ""
echo "Step 2: Checking GPU and CUDA..."
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
    GPU_NAME=$(echo $GPU_INFO | cut -d',' -f1 | xargs)
    GPU_MEMORY=$(echo $GPU_INFO | cut -d',' -f2 | xargs)
    
    print_status "GPU detected: $GPU_NAME with ${GPU_MEMORY}MB memory"
    
    # Check GPU memory
    if [ "$GPU_MEMORY" -lt 16000 ]; then
        print_warning "GPU has less than 16GB VRAM. Training may be challenging."
        print_warning "Consider using --blocks_to_swap 20 parameter during training."
    elif [ "$GPU_MEMORY" -lt 24000 ]; then
        print_warning "GPU has less than 24GB VRAM. Some optimizations may be needed."
    else
        print_status "GPU memory is sufficient for training"
    fi
    
    # Get CUDA version
    CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | head -1)
    print_status "CUDA Version: $CUDA_VERSION"
else
    print_error "No GPU detected. WAN2.2 training requires a CUDA-capable GPU"
    exit 1
fi

# Step 3: Check if musubi-tuner is already cloned
echo ""
echo "Step 3: Setting up musubi-tuner repository..."
if [ -d "musubi-tuner" ]; then
    cd musubi-tuner
    CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "none")
    REQUIRED_COMMIT="d0a193061a23a51c90664282205d753605a641c1"
    
    if [ "$CURRENT_COMMIT" = "$REQUIRED_COMMIT" ]; then
        print_status "musubi-tuner is already at the correct commit"
    else
        print_warning "musubi-tuner exists but at different commit"
        echo "Current: $CURRENT_COMMIT"
        echo "Required: $REQUIRED_COMMIT"
        read -p "Switch to required commit? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git fetch origin
            git checkout feature-wan-2-2
            git checkout $REQUIRED_COMMIT
            print_status "Switched to required commit"
        fi
    fi
    cd ..
else
    print_status "Cloning musubi-tuner repository..."
    git clone --recursive https://github.com/kohya-ss/musubi-tuner.git
    cd musubi-tuner
    git checkout feature-wan-2-2
    git checkout d0a193061a23a51c90664282205d753605a641c1
    cd ..
    print_status "Repository cloned and checked out successfully"
fi

# Step 4: Check virtual environment
echo ""
echo "Step 4: Setting up Python virtual environment..."
VENV_DIR="musubi-tuner/venv"

if [ -d "$VENV_DIR" ]; then
    print_status "Virtual environment already exists"
    # Check if it's valid
    if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
        print_status "Virtual environment activated"
    else
        print_warning "Virtual environment seems corrupted, recreating..."
        rm -rf "$VENV_DIR"
        cd musubi-tuner
        python3 -m venv venv
        source venv/bin/activate
        cd ..
    fi
else
    cd musubi-tuner
    python3 -m venv venv
    source venv/bin/activate
    cd ..
    print_status "Virtual environment created and activated"
fi

# Step 5: Install CUDNN (for systems that support apt)
echo ""
echo "Step 5: Checking CUDNN installation..."
if command -v apt &> /dev/null && command -v sudo &> /dev/null; then
    if dpkg -l | grep -q "libcudnn8.*8.9.7.29"; then
        print_status "CUDNN 8.9.7.29 is already installed"
    else
        print_warning "Attempting to install CUDNN 8.9.7.29..."
        sudo apt install -y libcudnn8=8.9.7.29-1+cuda12.2 libcudnn8-dev=8.9.7.29-1+cuda12.2 --allow-change-held-packages || {
            print_warning "CUDNN installation failed. This is usually okay - PyTorch includes CUDNN."
        }
    fi
else
    print_info "Skipping CUDNN system package installation (not required for PyTorch 2.7+)"
fi

# Step 6: Check PyTorch installation
echo ""
echo "Step 6: Checking PyTorch installation..."
cd musubi-tuner

# Check if PyTorch 2.7.0 is installed
TORCH_INSTALLED=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "none")
if [[ "$TORCH_INSTALLED" == "2.7.0"* ]]; then
    print_status "PyTorch 2.7.0 is already installed"
else
    print_status "Installing PyTorch 2.7.0 and related packages..."
    python -m pip install --timeout=120 --retries=3 torch==2.7.0 torchvision==0.22.0 xformers==0.0.30 --index-url https://download.pytorch.org/whl/cu128
fi

# Step 7: Install musubi-tuner and dependencies
echo ""
echo "Step 7: Installing musubi-tuner and dependencies..."

# Check if musubi-tuner is installed
if python -c "import musubi_tuner" 2>/dev/null; then
    print_status "musubi-tuner is already installed"
else
    print_status "Installing musubi-tuner in editable mode..."
    # For packages from aliyun mirror, add extra index
    # Note: If bitsandbytes download fails, it will be installed separately
    python -m pip install --timeout=120 --retries=3 -e . --extra-index-url https://mirrors.aliyun.com/pypi/simple/ || {
        print_warning "Installation failed, trying without bitsandbytes..."
        # Try installing without bitsandbytes first
        python -m pip install --timeout=120 --retries=3 --no-deps -e .
        # Then install other dependencies
        python -m pip install --timeout=120 --retries=3 accelerate diffusers transformers huggingface-hub safetensors \
            opencv-python av sentencepiece tqdm einops voluptuous easydict toml ftfy \
            --extra-index-url https://mirrors.aliyun.com/pypi/simple/
        # Try bitsandbytes separately with longer timeout
        print_warning "Attempting to install bitsandbytes separately..."
        python -m pip install --timeout=300 --retries=5 bitsandbytes==0.45.4 || print_warning "Bitsandbytes installation failed, continuing without it"
    }
fi

# Install additional required packages
print_status "Installing additional dependencies..."
echo "Using pip: $(which pip)"
python -m pip install --timeout=120 --retries=3 protobuf six

# Step 8: Verify installation
echo ""
echo "Step 8: Verifying installation..."

# Run verification (virtual environment is already activated from Step 4)
# Debug: Check which Python we're using
echo "Using Python: $(which python)"
echo "Python version: $(python --version)"

# Run verification with explicit python from venv
"$SCRIPT_DIR/$VENV_DIR/bin/python" -c "
import sys
try:
    import torch
    print(f'✓ PyTorch {torch.__version__} installed')
    if torch.cuda.is_available():
        print(f'✓ CUDA is available: {torch.cuda.get_device_name(0)}')
    else:
        print('✗ CUDA is not available')
        sys.exit(1)
    
    import xformers
    print(f'✓ xformers {xformers.__version__} installed')
    
    import musubi_tuner
    print('✓ musubi-tuner installed')
    
    import protobuf
    print('✓ protobuf installed')
    
except ImportError as e:
    print(f'✗ Error: {e}')
    sys.exit(1)
"

VERIFY_RESULT=$?
cd ..

if [ $VERIFY_RESULT -eq 0 ]; then
    print_status "All dependencies verified successfully"
else
    print_error "Some dependencies are missing"
    exit 1
fi

# Step 9: Create necessary directories
echo ""
echo "Step 9: Creating directory structure..."
mkdir -p musubi-tuner/{models/{diffusion_models,text_encoders,vae},output,logs}
mkdir -p dataset/{images,videos,captions}
print_status "Directory structure created"

# Final summary
echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Environment Summary:"
echo "  - Python: $PYTHON_VERSION"
echo "  - GPU: $GPU_NAME ($GPU_MEMORY MB)"
echo "  - CUDA: $CUDA_VERSION"
echo "  - PyTorch: 2.7.0"
echo ""
echo "Next steps:"
echo "  1. Run ./download_models.sh to download WAN2.2 models"
echo "  2. Prepare your dataset in dataset/ directory"
echo "  3. Run ./prepare_dataset.sh to configure training"
echo "  4. Run ./train_wan22_lora.sh to start training"
echo ""

# Create activation script for future use
cat > activate_env.sh << 'EOF'
#!/bin/bash
# Quick activation script for WAN2.2 training environment
cd "$(dirname "${BASH_SOURCE[0]}")"
source musubi-tuner/venv/bin/activate
echo "WAN2.2 training environment activated"
cd musubi-tuner
EOF

chmod +x activate_env.sh
print_status "Created activate_env.sh for quick environment activation"