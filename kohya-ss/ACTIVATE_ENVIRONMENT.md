# 🔧 WAN2.2 LoRA Training - Environment Activation Guide

## ⚠️ Important: Manual Activation Required

Due to how conda environments work, you **MUST** manually activate the environment in your current shell session. Scripts cannot activate environments that persist after they exit.

## 📋 Quick Steps

```bash
# 1. Activate the conda environment
conda activate wan22_lora

# 2. Install protobuf (fixes import issues)
conda install protobuf -y

# 3. Verify the environment
./step1.5_activate_and_verify.sh --verify
```

## 🔍 Detailed Instructions

### Step 1: Activate Conda Environment

Your terminal prompt should change to show `(wan22_lora)`:

```bash
# Before activation
(base) user@machine:~/kohya-ss$ 

# Run activation command
conda activate wan22_lora

# After activation - notice the (wan22_lora) prefix
(wan22_lora) user@machine:~/kohya-ss$ 
```

### Step 2: Install Protobuf

Even though protobuf was installed during setup, conda environments sometimes need it reinstalled:

```bash
# Using conda (recommended)
conda install protobuf -y

# Alternative if conda doesn't work
python -m pip install --force-reinstall protobuf
```

### Step 3: Verify Everything Works

Run the verification script:

```bash
./step1.5_activate_and_verify.sh --verify
```

You should see output like:
```
✓ Conda environment 'wan22_lora' is active
✓ PyTorch: 2.7.0+cu128
✓ Protocol Buffers: 6.31.1
✓ musubi-tuner: 0.1.0
✅ All required packages are installed!
✅ CUDA is available: NVIDIA GeForce RTX 4090
```

## ❓ Troubleshooting

### "conda: command not found"

Initialize conda first:
```bash
source /root/miniconda3/etc/profile.d/conda.sh
```

### "No module named 'protobuf'" after installation

Try force reinstalling:
```bash
conda uninstall protobuf -y
conda install protobuf -y
```

### Environment not activating

Check if the environment exists:
```bash
conda env list
```

If `wan22_lora` is not listed, run step 1 again:
```bash
./step1_setup_environment.sh
```

## 📝 Notes

- **Always activate the environment** before running training scripts
- The activation is **per terminal session** - new terminals need reactivation
- Your prompt should always show `(wan22_lora)` when working with this project

## 🚀 Next Steps

After successful verification, continue with:

```bash
# If starting fresh
./step0_run_all.sh --start-from 2

# Or run individual steps
./step2_download_models.sh      # Download models
./step3_prepare_dataset.sh      # Prepare dataset
./step4_train_wan22_lora.sh     # Start training
```

## 💡 Pro Tip

Add this to your `~/.bashrc` for quick activation:

```bash
alias wan22='conda activate wan22_lora && cd ~/15000_FC-Tools/kohya-ss'
```

Then just type `wan22` to activate and navigate!