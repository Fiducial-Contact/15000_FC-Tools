#!/bin/bash

# Wan2.2 5B Training Launch Script
# This script sets up the environment and launches training

# Exit on error
set -e

echo "==================================="
echo "Wan2.2 5B LoRA Training Script"
echo "==================================="

# Change to diffusion-pipe directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFFUSION_PIPE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$DIFFUSION_PIPE_DIR"

echo "Working directory: $DIFFUSION_PIPE_DIR"

# Check if conda environment is activated
if [[ "$CONDA_DEFAULT_ENV" != "wan22" ]]; then
    echo "Activating wan22 conda environment..."
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate wan22
fi

# Source environment variables
if [ -f ~/.wan22_env ]; then
    echo "Loading environment variables..."
    source ~/.wan22_env
else
    echo "Warning: ~/.wan22_env not found. Using default environment."
fi

# Set environment variables for RTX 4000 series
export NCCL_P2P_DISABLE="1"
export NCCL_IB_DISABLE="1"
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"

# Optional: Set cache directory
# export HF_HOME="/data/cache/huggingface"
# export TRANSFORMERS_CACHE="$HF_HOME/transformers"

# Parse command line arguments
NUM_GPUS=1
CONFIG_FILE="2.2/configs/wan2.2_5b_lora.toml"
RESUME_CHECKPOINT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --num_gpus)
            NUM_GPUS="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --resume)
            RESUME_CHECKPOINT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--num_gpus N] [--config path/to/config.toml] [--resume checkpoint_path]"
            exit 1
            ;;
    esac
done

echo ""
echo "Training configuration:"
echo "- Number of GPUs: $NUM_GPUS"
echo "- Config file: $CONFIG_FILE"
if [ -n "$RESUME_CHECKPOINT" ]; then
    echo "- Resuming from: $RESUME_CHECKPOINT"
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Function to monitor GPU memory
monitor_gpu() {
    echo ""
    echo "GPU Status:"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits
}

# Show initial GPU status
monitor_gpu

# Build the training command
CMD="deepspeed --num_gpus=$NUM_GPUS train.py --deepspeed --config $CONFIG_FILE"

if [ -n "$RESUME_CHECKPOINT" ]; then
    CMD="$CMD --resume_from_checkpoint $RESUME_CHECKPOINT"
fi

echo ""
echo "Starting training with command:"
echo "$CMD"
echo ""
echo "Press Ctrl+C to stop training"
echo "==================================="

# Launch training
$CMD

# Training completed or interrupted
echo ""
echo "==================================="
echo "Training session ended"
monitor_gpu
echo "==================================="