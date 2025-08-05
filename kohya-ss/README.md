# WAN2.2 LoRA Training - Simplified Guide

This is a simplified workflow for training WAN2.2 LoRA models. The scripts have been reorganized to reduce complexity and avoid common errors.

## Quick Start

### 1. Setup Environment (One-time)
```bash
./step1_setup_environment.sh
```
This will:
- Check system requirements (Python 3.10+, CUDA GPU)
- Clone musubi-tuner repository
- Create conda environment `wan22_lora`
- Install all required packages

### 2. Download Models (One-time)
```bash
./step2_download_models.sh
```
Downloads ~30GB of required models:
- T5 Text Encoder (4.7GB)
- VAE Model (240MB)
- High Noise Model (13GB)
- Low Noise Model (13GB)

### 3. Prepare Dataset
1. Add your training images to `dataset/images/`
2. Create a `.txt` caption file for each image
   - Example: `image001.jpg` → `image001.txt`
3. Include your trigger phrase in every caption

### 4. Train LoRA
```bash
./train_lora.sh "MyLoRA" "trigger phrase" "YourName"
```

## Script Overview

### Core Scripts (Use These)
- `step1_setup_environment.sh` - Initial setup
- `step2_download_models.sh` - Download models
- `train_lora.sh` - Main training script
- `verify_environment.sh` - Check environment

### Legacy Scripts (Still Work)
- `step4_train_wan22_lora.sh` - Advanced training script with more options

## Key Improvements

1. **No Manual Environment Activation**: All scripts use `conda run` internally
2. **Fixed Syntax Errors**: Shell compatibility issues resolved
3. **Simplified Workflow**: Just 3 main scripts instead of many
4. **Better Error Handling**: Clear error messages and checks

## Troubleshooting

### "Conda environment not active" Error
The new scripts don't require manual activation. They use `conda run` automatically.

### Syntax Error on Line 178
This has been fixed in both the original and new scripts.

### Low GPU Memory
Scripts automatically detect and enable memory optimization for GPUs < 16GB.

### Missing Packages
Run `./verify_environment.sh` to check what's missing.

## Dataset Tips

- Use high-quality images (768x768 or larger recommended)
- Write descriptive captions including your trigger phrase
- 20-50 images usually work well
- More diverse images = better results

## Training Parameters

Default settings (optimized by AI_Characters):
- Network Dimension: 16
- Learning Rate: 3e-4
- Epochs: 100
- Batch Size: 1

These work well for most cases. Advanced users can modify in the script.

## Using Your LoRA

After training, you'll get two files:
- `[Name]-HighNoise.safetensors`
- `[Name]-LowNoise.safetensors`

Load both in ComfyUI with strength 1.0 and use your trigger phrase.