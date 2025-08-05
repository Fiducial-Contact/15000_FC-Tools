# Wan2.2 5B (TI2V) Model Training Guide

This guide provides complete instructions for training the Wan2.2 5B Text/Image-to-Video model using diffusion-pipe.

## Model Overview

The Wan2.2 5B (ti2v_5B) model is a dense 5-billion parameter model that supports both:
- Text-to-Video (T2V) generation
- Image-to-Video (I2V) generation

Key features:
- Resolution: 720P (and various aspect ratios)
- Frame rate: 24 fps
- VAE compression: 16×16×4 (spatial×spatial×temporal)
- Single unified framework for both T2V and I2V tasks

## Prerequisites

1. GPU Requirements:
   - Minimum: NVIDIA RTX 4090 (24GB VRAM)
   - Recommended: Multiple GPUs for faster training
   - The model can run on a single 4090 with optimizations

2. System Requirements:
   - Ubuntu 22.04 or similar Linux distribution
   - CUDA 12.1.1 or compatible version
   - At least 64GB system RAM recommended
   - Fast SSD with >500GB free space

## Directory Structure

```
wan2.2_training/
├── models/               # Downloaded model files
│   ├── Wan2.2-TI2V-5B/  # Main model checkpoint
│   ├── vae/             # VAE files
│   └── text_encoders/   # UMT5 text encoder
├── datasets/            # Your training data
│   ├── videos/         # Video files
│   ├── images/         # Image files
│   └── captions/       # Text caption files
└── outputs/            # Training outputs
```

## Step 1: Environment Setup

See `setup_environment.md` for detailed PyTorch environment setup instructions.

Quick setup:
```bash
conda create -n wan22-train python=3.12
conda activate wan22-train
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements.txt
```

## Step 2: Download Models

Use the provided `downloads.sh` script to download all required models:

```bash
chmod +x downloads.sh
./downloads.sh
```

This will download:
1. Wan2.2-TI2V-5B main model
2. Wan2.2 VAE (different from Wan2.1!)
3. UMT5-XXL text encoder

Alternatively, you can use ComfyUI safetensors files if you already have them.

## Step 3: Dataset Preparation

### Dataset Structure

Your dataset should be organized as follows:

```
datasets/
├── videos/
│   ├── video001.mp4
│   ├── video001.txt    # Caption for video001
│   ├── video002.mp4
│   └── video002.txt
└── images/
    ├── img001.jpg
    ├── img001.txt      # Caption for img001
    ├── img002.png
    └── img002.txt
```

### Caption Format

Each media file should have a corresponding `.txt` file with the same base name containing the text description. For example:

`video001.txt`:
```
A serene lake with mountains in the background, birds flying across the sunset sky
```

### Dataset Configuration

Edit `configs/dataset_video.toml` to point to your dataset directories.

## Step 4: Training Configuration

The main training configuration is in `configs/wan2.2_5b_lora.toml`. Key parameters:

### Model Configuration
```toml
[model]
type = 'wan'
ckpt_path = '/path/to/Wan2.2-TI2V-5B'
dtype = 'bfloat16'
transformer_dtype = 'float8'  # Use float8 to save VRAM
```

### LoRA Configuration
```toml
[adapter]
type = 'lora'
rank = 32
dtype = 'bfloat16'
```

### Training Parameters
```toml
micro_batch_size_per_gpu = 1
gradient_accumulation_steps = 4  # Effective batch size = 4
lr = 2e-5
epochs = 100
```

### Memory Optimization

For 24GB GPUs, use these settings:
```toml
activation_checkpointing = 'unsloth'
blocks_to_swap = 20  # Offload 20 transformer blocks to RAM
transformer_dtype = 'float8'
```

## Step 5: Launch Training

### Single GPU Training

```bash
cd /path/to/diffusion-pipe
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
NCCL_P2P_DISABLE="1" \
NCCL_IB_DISABLE="1" \
deepspeed --num_gpus=1 train.py --deepspeed --config 2.2/configs/wan2.2_5b_lora.toml
```

### Multi-GPU Training

For 4 GPUs:
```bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
NCCL_P2P_DISABLE="1" \
NCCL_IB_DISABLE="1" \
deepspeed --num_gpus=4 train.py --deepspeed --config 2.2/configs/wan2.2_5b_lora.toml
```

## Step 6: Monitoring Training

Training progress is logged to TensorBoard:
```bash
tensorboard --logdir outputs/wan22_training_run/tensorboard
```

Key metrics to monitor:
- `loss`: Should decrease over time
- `grad_norm`: Should remain stable
- `lr`: Learning rate schedule

## Step 7: Using Checkpoints

Checkpoints are saved every N epochs (configurable). To resume training:

```bash
deepspeed --num_gpus=1 train.py --deepspeed \
  --config 2.2/configs/wan2.2_5b_lora.toml \
  --resume_from_checkpoint outputs/wan22_training_run/checkpoint_epoch50
```

## Tips and Troubleshooting

### Out of Memory (OOM) Issues

1. Increase `blocks_to_swap` (up to 25 for 5B model)
2. Reduce `micro_batch_size_per_gpu` to 1
3. Use `float8` for transformer dtype
4. Enable `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`

### Slow Training

1. Reduce `blocks_to_swap` if you have more VRAM
2. Use multiple GPUs with pipeline parallelism
3. Ensure you're using fast storage (NVMe SSD)
4. Pre-cache your dataset

### Dataset Issues

1. Ensure all media files have corresponding caption files
2. Check video codec compatibility (H.264 recommended)
3. Videos should be at least 5 seconds (121 frames @ 24fps)

## Advanced Configuration

### Mixed Resolution Training

Edit the dataset config to train on multiple resolutions:
```toml
resolutions = [512, 768]  # Train on 512² and 768² pixels
enable_ar_bucket = true
min_ar = 0.5
max_ar = 2.0
```

### I2V-Specific Training

For image-to-video training, ensure your dataset includes:
1. Start frame images
2. Corresponding video sequences
3. Appropriate captions describing the motion

## Model Architecture Details

The ti2v_5B configuration:
- Transformer dimension: 3072
- FFN dimension: 14336
- Number of heads: 24
- Number of layers: 30
- Frequency dimension: 256
- Patch size: (1, 2, 2)
- QK normalization: enabled
- Cross-attention normalization: enabled

## Inference Parameters

Default inference settings for ti2v_5B:
- Sample FPS: 24
- Sample shift: 5.0
- Sample steps: 50
- Guidance scale: 5.0
- Frame count: 121 (5 seconds @ 24fps)

## References

- Wan2.2 Paper: [Coming Soon]
- HuggingFace Model: https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B
- Diffusion-pipe: https://github.com/tdrussell/diffusion-pipe