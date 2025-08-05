# WAN2.2 Training Tools

This repository contains two different training approaches for WAN2.2 models:

## 1. diffusion-pipe/
Original diffusion-pipe based training implementation with automatic PyTorch version management.

**Features:**
- Automatic PyTorch 2.1+ installation
- Integrated model download scripts
- Step-by-step setup process
- Support for both image and video training

**Quick Start:**
```bash
cd diffusion-pipe
./step0_run_all.sh
```

## 2. kohya-ss/
New kohya-ss/musubi-tuner based training implementation, following AI_Characters' recommended WAN2.2 LoRA workflow.

**Features:**
- Uses latest musubi-tuner with WAN2.2 support
- Automatic dual-model training (high-noise & low-noise)
- Smart environment detection and setup
- PyTorch 2.7.0 with optimized settings
- Memory optimization for 16GB GPUs

**Quick Start:**
```bash
cd kohya-ss
./setup_environment.sh
./download_models.sh
./prepare_dataset.sh
./train_wan22_lora.sh --name "MyLoRA" --author "YourName" --trigger "your trigger phrase"
```

## Which to Use?

- **diffusion-pipe**: If you're already familiar with the original training process
- **kohya-ss**: For the latest WAN2.2 optimizations and community-recommended settings

Both approaches are maintained and functional. The kohya-ss approach is newer and includes specific optimizations for WAN2.2 training.

## Requirements

- Python 3.10+
- NVIDIA GPU with 16GB+ VRAM (24GB+ recommended)
- CUDA 11.8 or 12.x
- ~50GB disk space for models

## Support

For issues and questions:
- Check the README in each directory
- Refer to the original documentation and community resources
- GPU memory issues: Use low-memory flags and optimizations

## Credits

- Original diffusion-pipe implementation
- AI_Characters for WAN2.2 LoRA workflow
- kohya-ss for musubi-tuner framework
- WAN AI team for the base models