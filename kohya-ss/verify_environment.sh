#!/bin/bash

# WAN2.2 Environment Verification Script
# Checks if the conda environment is properly set up

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
echo "WAN2.2 Environment Verification"
echo "========================================="
echo ""

ENV_NAME="wan22_lora"

# Check if conda environment exists
if ! conda env list | grep -q "^${ENV_NAME} "; then
    print_error "Conda environment '${ENV_NAME}' not found!"
    echo ""
    echo "Please run ./setup_environment.sh first"
    exit 1
fi

print_status "Found conda environment '${ENV_NAME}'"

# Check packages using conda run
echo ""
print_info "Checking installed packages..."

conda run -n ${ENV_NAME} python -c "
import sys
import importlib

def check_package(name, display_name=None):
    display = display_name or name
    try:
        module = importlib.import_module(name)
        version = getattr(module, '__version__', 'unknown')
        print(f'✓ {display}: {version}')
        return True
    except ImportError:
        print(f'✗ {display}: NOT INSTALLED')
        return False

print()
all_good = True

# Core packages
all_good &= check_package('torch', 'PyTorch')
all_good &= check_package('torchvision', 'TorchVision')
all_good &= check_package('xformers', 'xformers')
all_good &= check_package('accelerate', 'Accelerate')
all_good &= check_package('transformers', 'Transformers')
all_good &= check_package('diffusers', 'Diffusers')
all_good &= check_package('safetensors', 'Safetensors')
all_good &= check_package('protobuf', 'Protocol Buffers')
all_good &= check_package('musubi_tuner', 'musubi-tuner')

# Check CUDA
print()
try:
    import torch
    if torch.cuda.is_available():
        print(f'✓ CUDA available: {torch.cuda.get_device_name(0)}')
        print(f'✓ CUDA version: {torch.version.cuda}')
        print(f'✓ GPU memory: {torch.cuda.get_device_properties(0).total_memory // 1024**3}GB')
    else:
        print('✗ CUDA not available')
        all_good = False
except:
    pass

print()
if all_good:
    print('✅ Environment is ready for training!')
    sys.exit(0)
else:
    print('❌ Some packages are missing or CUDA is not available')
    sys.exit(1)
"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    print_status "All checks passed!"
    echo ""
    echo "You can now run training with:"
    echo "  ./train_lora.sh \"LoRA_Name\" \"trigger phrase\""
else
    echo ""
    print_error "Environment check failed!"
    echo ""
    echo "Try running these commands:"
    echo "  conda activate ${ENV_NAME}"
    echo "  conda install protobuf -y"
    echo "  pip install -r requirements.txt"
fi