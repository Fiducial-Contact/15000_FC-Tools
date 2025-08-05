# WAN2.2 LoRA Training with kohya-ss/musubi-tuner

This directory contains an automated training environment for WAN2.2 LoRA models using the kohya-ss/musubi-tuner framework, based on AI_Characters' recommended workflow.

## Quick Start Options

### Option 1: Fully Automated Setup (Recommended)
```bash
./step0_run_all.sh --auto --name "MyLoRA" --author "YourName" --trigger "your style"
```

### Option 2: Quick Training (if already set up)
```bash
./quick_train.sh "MyLoRA" "your trigger phrase"
```

### Option 3: Step-by-Step Setup

1. **Setup Environment**
   ```bash
   ./step1_setup_environment.sh
   ```
   This will:
   - Check Python and GPU requirements
   - Clone musubi-tuner repository
   - Install PyTorch 2.7.0 and dependencies
   - Create virtual environment

2. **Download Models**
   ```bash
   ./step2_download_models.sh
   ```
   Downloads all required WAN2.2 models (~30GB total):
   - T5 Text Encoder
   - VAE Model
   - High Noise Model (14B)
   - Low Noise Model (14B)

3. **Prepare Dataset**
   ```bash
   # Add your images to dataset/images/
   # Add your videos to dataset/videos/ (optional)
   # Create .txt caption files for each media file
   
   ./step3_prepare_dataset.sh
   ```

4. **Start Training**
   ```bash
   ./step4_train_wan22_lora.sh --name "MyLoRA" --author "YourName" --trigger "your trigger phrase"
   ```

## Directory Structure

```
kohya-ss/
├── step0_run_all.sh         # 🚀 All-in-one setup and training
├── quick_train.sh           # 🏃 Quick training for existing setups
├── step1_setup_environment.sh    # Environment setup script
├── step2_download_models.sh      # Model download script
├── step3_prepare_dataset.sh      # Dataset preparation script
├── step4_train_wan22_lora.sh     # Main training script
├── activate_env.sh          # Quick environment activation
├── model_paths.sh           # Model path configuration (auto-generated)
├── pre_cache_dataset.sh     # Optional dataset pre-caching
├── configs/
│   ├── training_config.toml # Training configuration template
│   └── dataset_example.toml # Dataset configuration example
├── dataset/
│   ├── images/              # Place your images here
│   ├── videos/              # Place your videos here (optional)
│   ├── captions/            # Alternative caption storage
│   └── dataset.toml         # Auto-generated dataset config
├── musubi-tuner/            # kohya-ss training framework (auto-cloned)
│   ├── venv/                # Python virtual environment
│   └── models/              # Downloaded model files
└── output/                  # Training outputs (LoRA files)
```

## Training Options

### Basic Usage
```bash
./step4_train_wan22_lora.sh --name "MyLoRA" --author "YourName" --trigger "my style"
```

### Advanced Options
```bash
./step4_train_wan22_lora.sh \
    --name "MyLoRA" \
    --author "YourName" \
    --trigger "my style trigger" \
    --epochs 100 \
    --lr 3e-4 \
    --dim 16 \
    --batch-size 1 \
    --gradient-accumulation 1 \
    --seed 42 \
    --low-memory \           # For 16GB GPUs
    --use-cache              # Use pre-cached latents
```

### Available Parameters
- `--name`: LoRA name (default: MyWAN22LoRA)
- `--author`: Author name for metadata
- `--trigger`: Trigger phrase that must be in all captions
- `--epochs`: Maximum training epochs (default: 100)
- `--lr`: Learning rate (default: 3e-4)
- `--dim`: Network dimension (default: 16, recommended)
- `--batch-size`: Batch size (default: 1)
- `--gradient-accumulation`: Gradient accumulation steps
- `--seed`: Random seed for reproducibility
- `--low-memory`: Enable for 16GB GPUs (adds --blocks_to_swap 20)
- `--use-cache`: Use pre-cached latents if available

## Dataset Guidelines

### Image Requirements
- **Format**: JPG, PNG, WebP
- **Resolution**: 768x768 or higher recommended
- **Quantity**: 20-50 images minimum for good results
- **Style**: Consistent style across dataset

### Caption Requirements
- Each image needs a corresponding .txt file
- Example: `image001.jpg` → `image001.txt`
- **Must include trigger phrase** in every caption
- Be descriptive but concise

### Caption Examples
Good:
```
image in an early 2010s amateur photo artstyle with washed out colors, woman smiling at camera, indoor lighting
```

Bad:
```
beautiful photo (too vague)
IMG_1234.jpg (meaningless)
a picture (missing trigger phrase)
```

## GPU Memory Requirements

- **Recommended**: 24GB+ VRAM
- **Minimum**: 16GB VRAM (with --low-memory flag)
- **Low Memory Tips**:
  - Use `--low-memory` flag
  - Pre-cache dataset with `./pre_cache_dataset.sh`
  - Reduce batch size to 1
  - Use gradient accumulation

## Training Process

The script automatically trains **two models**:
1. **High Noise Model** (timesteps 875-1000)
2. **Low Noise Model** (timesteps 0-875)

Both models are trained with the same dataset and settings.

## Output Files

After training, you'll find in the `output/` directory:
- `YourLoRA-HighNoise.safetensors`
- `YourLoRA-LowNoise.safetensors`
- `training_info.txt` (training parameters log)

## Using Your LoRA

1. Load both files in ComfyUI
2. Set strength to **1.0** (not 3.0 as with older versions)
3. Use your trigger phrase in prompts
4. Recommended: Use [AI_Characters' WAN2.2 workflow](https://www.dropbox.com/scl/fi/pfpzff7eyjcql0uetj1at/WAN2.2_recommended_default_text2image_inference_workflow_by_AI_Characters-v3.json)

## Troubleshooting

### CUDA/GPU Issues
- Ensure NVIDIA drivers are installed
- Check CUDA version compatibility
- Try reinstalling PyTorch if needed

### Memory Issues
- Use `--low-memory` flag
- Reduce batch size
- Pre-cache dataset
- Close other GPU applications

### Training Issues
- Ensure all captions include trigger phrase
- Check dataset has enough variety
- Verify models downloaded completely
- Monitor loss curves for convergence

## Credits

This training setup is based on:
- [AI_Characters' WAN2.2 LoRA workflow](https://civitai.com/articles/17740)
- [kohya-ss/musubi-tuner](https://github.com/kohya-ss/musubi-tuner)
- Community best practices from Reddit and Civitai

## Support

For issues specific to this setup, please check:
1. All scripts ran without errors
2. Dataset is properly formatted
3. GPU has sufficient memory
4. Virtual environment is activated

For general WAN2.2 training questions, refer to the community resources linked above.