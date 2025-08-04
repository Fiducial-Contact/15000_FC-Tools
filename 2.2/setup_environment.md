# PyTorch Environment Setup for Wan2.2 Training

This guide provides detailed instructions for setting up the PyTorch environment for Wan2.2 5B model training on a cloud Linux system.

## System Requirements

- **OS**: Ubuntu 22.04 LTS (recommended)
- **Python**: 3.10 or 3.12
- **CUDA**: 12.1.1
- **PyTorch**: 2.0.1 or later

## Step 1: Install System Dependencies

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential build tools
sudo apt install -y build-essential git wget curl

# Install Python development packages
sudo apt install -y python3-dev python3-pip python3-venv

# Install CUDA dependencies (if not already installed)
sudo apt install -y nvidia-driver-525 nvidia-utils-525

# Install additional libraries for video processing
sudo apt install -y ffmpeg libavcodec-dev libavformat-dev libswscale-dev
```

## Step 2: Install Miniconda

```bash
# Download Miniconda installer
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

# Make installer executable
chmod +x Miniconda3-latest-Linux-x86_64.sh

# Install Miniconda
./Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3

# Add to PATH
echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Initialize conda
conda init bash
source ~/.bashrc
```

## Step 3: Create Conda Environment

```bash
# Create new environment with Python 3.10 (matching your screenshot)
conda create -n wan22 python=3.10 -y

# Activate the environment
conda activate wan22
```

## Step 4: Install PyTorch 2.0.1 with CUDA 12.1

```bash
# Install PyTorch 2.0.1 with CUDA 12.1 support
pip3 install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu121

# Verify installation
python -c "import torch; print(f'PyTorch version: {torch.__version__}')"
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
python -c "import torch; print(f'CUDA version: {torch.version.cuda}')"
```

## Step 5: Install CUDA Toolkit and NVCC

```bash
# Install CUDA 12.1 NVCC from conda
conda install -c nvidia cuda-nvcc=12.1 -y

# Install CUDA toolkit components
conda install -c nvidia cuda-toolkit=12.1 -y

# Verify NVCC installation
nvcc --version
```

## Step 6: Install DeepSpeed and Dependencies

```bash
# Clone diffusion-pipe repository (if not already done)
git clone --recurse-submodules https://github.com/tdrussell/diffusion-pipe
cd diffusion-pipe

# Install requirements
pip install -r requirements.txt

# Manually ensure DeepSpeed 0.17.0 is installed
pip install deepspeed==0.17.0

# Install additional dependencies for Wan2.2
pip install einops safetensors transformers accelerate
pip install imageio imageio-ffmpeg opencv-python-headless
pip install tensorboard wandb
```

## Step 7: Install Flash Attention (Optional but Recommended)

```bash
# Set environment variables for CUDA
export CUDA_HOME=/usr/local/cuda-12.1
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Install flash-attn (may take a while to compile)
pip install flash-attn==2.8.0.post2 --no-build-isolation
```

## Step 8: Environment Variables Setup

Create a file `~/.wan22_env` with the following content:

```bash
#!/bin/bash
# Wan2.2 Training Environment Variables

# CUDA settings
export CUDA_HOME=/usr/local/cuda-12.1
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export PATH=$CUDA_HOME/bin:$PATH

# PyTorch settings for RTX 4000 series
export NCCL_P2P_DISABLE=1
export NCCL_IB_DISABLE=1

# Memory optimization
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# DeepSpeed settings
export DS_ACCELERATOR=cuda

# Logging
export TRANSFORMERS_VERBOSITY=error
export WANDB_MODE=offline  # Set to 'online' if using W&B

# Model cache directory
export HF_HOME=/path/to/your/cache/huggingface
export TRANSFORMERS_CACHE=$HF_HOME/transformers
```

Source this file before training:
```bash
source ~/.wan22_env
```

## Step 9: Verify Installation

Create a test script `test_environment.py`:

```python
import torch
import deepspeed
import transformers
import einops
import safetensors

print("=== Environment Check ===")
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"DeepSpeed version: {deepspeed.__version__}")
print(f"Transformers version: {transformers.__version__}")

if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")

# Test DeepSpeed initialization
print("\nTesting DeepSpeed initialization...")
try:
    deepspeed.init_distributed()
    print("DeepSpeed initialized successfully!")
except Exception as e:
    print(f"DeepSpeed initialization failed: {e}")
    print("This is normal if not running with deepspeed launcher")

print("\n=== Environment ready for Wan2.2 training! ===")
```

Run the test:
```bash
python test_environment.py
```

## Step 10: Optimize for Cloud GPU

For cloud GPU instances (AWS, GCP, Azure):

```bash
# Set persistent GPU mode
sudo nvidia-smi -pm 1

# Set GPU clock speeds to maximum (optional)
sudo nvidia-smi -ac 8001,1980  # For A100
# sudo nvidia-smi -ac 6251,1530  # For V100

# Monitor GPU usage
watch -n 1 nvidia-smi
```

## Troubleshooting

### CUDA Out of Memory
```bash
# Clear GPU memory
python -c "import torch; torch.cuda.empty_cache()"

# Check memory usage
nvidia-smi
```

### DeepSpeed Issues
```bash
# Reinstall with specific CUDA version
DS_BUILD_CUDA_EXT=1 pip install deepspeed==0.17.0 --force-reinstall
```

### Flash Attention Build Errors
```bash
# Install with specific CUDA architecture
TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9" pip install flash-attn --no-build-isolation
```

## Final Setup Verification

Run this command to ensure everything is properly configured:

```bash
cd /path/to/diffusion-pipe
NCCL_P2P_DISABLE="1" NCCL_IB_DISABLE="1" \
deepspeed --num_gpus=1 train.py --help
```

If this shows the help message without errors, your environment is ready!

## Next Steps

1. Download the Wan2.2 5B model using `downloads.sh`
2. Prepare your dataset
3. Configure training parameters
4. Start training!

Remember to activate the conda environment and source the environment variables before each training session:

```bash
conda activate wan22
source ~/.wan22_env
```