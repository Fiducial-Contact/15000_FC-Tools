#!/bin/bash

# WAN2.2 Environment Activation and Verification Script
# This script helps ensure the conda environment is properly activated
# and all required packages are installed correctly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

print_command() {
    echo -e "${CYAN}$1${NC}"
}

echo "========================================="
echo "Step 1.5: Environment Activation & Verification"
echo "========================================="
echo ""

# Check if running with --verify flag
if [ "$1" == "--verify" ]; then
    echo "Verifying environment setup..."
    echo ""
    
    # Check if we're in the conda environment
    if [[ "$CONDA_DEFAULT_ENV" == "wan22_lora" ]]; then
        print_status "Conda environment 'wan22_lora' is active"
    else
        print_error "Conda environment 'wan22_lora' is NOT active!"
        echo ""
        echo "Please activate it first with:"
        print_command "  conda activate wan22_lora"
        exit 1
    fi
    
    # Check Python version and location
    echo ""
    print_info "Python information:"
    echo "  Python path: $(which python)"
    echo "  Python version: $(python --version)"
    echo "  Conda environment: $CONDA_PREFIX"
    
    # Verify all required packages
    echo ""
    print_info "Verifying package installations..."
    
    python -c "
import sys
import importlib

packages = [
    ('torch', 'PyTorch'),
    ('torchvision', 'TorchVision'),
    ('xformers', 'xformers'),
    ('protobuf', 'Protocol Buffers'),
    ('six', 'six'),
    ('musubi_tuner', 'musubi-tuner'),
    ('transformers', 'Transformers'),
    ('diffusers', 'Diffusers'),
    ('accelerate', 'Accelerate'),
    ('safetensors', 'Safetensors'),
]

all_good = True
print()

for module_name, display_name in packages:
    try:
        module = importlib.import_module(module_name)
        version = getattr(module, '__version__', 'unknown')
        print(f'✓ {display_name}: {version}')
    except ImportError as e:
        print(f'✗ {display_name}: NOT INSTALLED')
        all_good = False

print()

if all_good:
    print('✅ All required packages are installed!')
    print('✅ Environment is ready for training!')
    
    # Check CUDA
    try:
        import torch
        if torch.cuda.is_available():
            print(f'✅ CUDA is available: {torch.cuda.get_device_name(0)}')
            print(f'✅ CUDA version: {torch.version.cuda}')
        else:
            print('⚠️  CUDA is not available')
    except:
        pass
else:
    print('❌ Some packages are missing!')
    print('❌ Please run the installation commands below')
    sys.exit(1)
"
    
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        print_status "Environment verification complete!"
        echo ""
        echo "You can now proceed to the next step."
    else
        echo ""
        print_error "Environment verification failed!"
        echo ""
        echo "Please run the installation commands shown below."
    fi
    
else
    # Show activation instructions
    print_warning "IMPORTANT: Manual environment activation required!"
    echo ""
    echo "The conda environment needs to be activated in your current shell."
    echo "Scripts cannot activate conda environments that persist after they exit."
    echo ""
    echo "Please run these commands in order:"
    echo ""
    echo "1. Activate the conda environment:"
    print_command "   conda activate wan22_lora"
    echo ""
    echo "2. Install/reinstall protobuf (fixes import issues):"
    print_command "   conda install protobuf -y"
    echo ""
    echo "3. Verify the environment:"
    print_command "   ./step1.5_activate_and_verify.sh --verify"
    echo ""
    echo "Alternative: If conda install doesn't work, try:"
    print_command "   python -m pip install --force-reinstall protobuf"
    echo ""
    print_info "After running these commands, your prompt should show (wan22_lora)"
    print_info "Example: (wan22_lora) user@machine:~$"
    echo ""
    
    # Create a helper script for quick activation
    cat > activate_wan22.sh << 'EOF'
#!/bin/bash
# Quick activation helper
echo "Run this command in your terminal:"
echo "source /root/miniconda3/etc/profile.d/conda.sh && conda activate wan22_lora"
echo ""
echo "Then install protobuf:"
echo "conda install protobuf -y"
EOF
    chmod +x activate_wan22.sh
    
    print_info "Created activate_wan22.sh helper script"
fi