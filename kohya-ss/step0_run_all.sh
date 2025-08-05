#!/bin/bash

# WAN2.2 LoRA Training - All-in-One Setup Script
# This script runs all setup steps automatically
# Based on AI_Characters' workflow with kohya-ss/musubi-tuner

set -e

echo "========================================="
echo "WAN2.2 LoRA Training - Complete Setup"
echo "========================================="
echo ""
echo "This script will automatically:"
echo "  1. Setup Python environment and dependencies"
echo "  2. Download all required models (~30GB)"
echo "  3. Prepare dataset configuration"
echo "  4. Start training your LoRA"
echo ""
echo "Estimated time: 3-6 hours (depending on dataset size)"
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

# Parse command line arguments
LORA_NAME=""
AUTHOR_NAME=""
TRIGGER_PHRASE=""
SKIP_STEPS=""
START_FROM_STEP=1
AUTO_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            LORA_NAME="$2"
            shift 2
            ;;
        --author)
            AUTHOR_NAME="$2"
            shift 2
            ;;
        --trigger)
            TRIGGER_PHRASE="$2"
            shift 2
            ;;
        --skip)
            SKIP_STEPS="$2"
            shift 2
            ;;
        --start-from)
            START_FROM_STEP="$2"
            shift 2
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --name NAME         LoRA name (required for auto mode)"
            echo "  --author AUTHOR     Author name (required for auto mode)"
            echo "  --trigger PHRASE    Trigger phrase (required for auto mode)"
            echo "  --skip STEPS        Comma-separated list of steps to skip (1,2,3,4)"
            echo "  --start-from N      Start from step N (default: 1)"
            echo "  --auto              Run in automatic mode (no prompts)"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Interactive mode"
            echo "  $0"
            echo ""
            echo "  # Automatic mode"
            echo "  $0 --auto --name \"MyLoRA\" --author \"YourName\" --trigger \"my style\""
            echo ""
            echo "  # Skip environment setup and model download"
            echo "  $0 --skip 1,2"
            echo ""
            echo "  # Resume from dataset preparation"
            echo "  $0 --start-from 3"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if auto mode has required parameters
if [ "$AUTO_MODE" = true ]; then
    if [ -z "$LORA_NAME" ] || [ -z "$AUTHOR_NAME" ] || [ -z "$TRIGGER_PHRASE" ]; then
        print_error "Auto mode requires --name, --author, and --trigger parameters"
        exit 1
    fi
fi

# Save configuration for later steps
CONFIG_FILE="$SCRIPT_DIR/.training_config"
cat > "$CONFIG_FILE" << EOF
LORA_NAME="$LORA_NAME"
AUTHOR_NAME="$AUTHOR_NAME"
TRIGGER_PHRASE="$TRIGGER_PHRASE"
EOF

# Function to check if step should be skipped
should_skip_step() {
    local step=$1
    if [[ ",$SKIP_STEPS," == *",$step,"* ]]; then
        return 0
    fi
    if [ "$step" -lt "$START_FROM_STEP" ]; then
        return 0
    fi
    return 1
}

# Function to run a step
run_step() {
    local step_num=$1
    local step_name=$2
    local script_name=$3
    local description=$4
    
    if should_skip_step "$step_num"; then
        print_warning "Skipping Step $step_num: $step_name"
        return 0
    fi
    
    echo ""
    echo "========================================="
    echo "Step $step_num: $step_name"
    echo "========================================="
    echo "$description"
    echo ""
    
    if [ "$AUTO_MODE" != true ]; then
        read -p "Continue with this step? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_warning "Skipping Step $step_num"
            return 0
        fi
    fi
    
    # Run the script
    if [ -f "$SCRIPT_DIR/$script_name" ]; then
        if bash "$SCRIPT_DIR/$script_name"; then
            print_status "Step $step_num completed successfully"
            return 0
        else
            print_error "Step $step_num failed"
            return 1
        fi
    else
        print_error "Script not found: $script_name"
        return 1
    fi
}

# Main execution
echo "Starting WAN2.2 LoRA training setup..."
if [ "$AUTO_MODE" = true ]; then
    print_info "Running in automatic mode"
    print_info "LoRA Name: $LORA_NAME"
    print_info "Author: $AUTHOR_NAME"
    print_info "Trigger: $TRIGGER_PHRASE"
else
    print_info "Running in interactive mode"
    
    # Collect information if not provided
    if [ -z "$LORA_NAME" ]; then
        read -p "Enter LoRA name: " LORA_NAME
    fi
    if [ -z "$AUTHOR_NAME" ]; then
        read -p "Enter author name: " AUTHOR_NAME
    fi
    if [ -z "$TRIGGER_PHRASE" ]; then
        read -p "Enter trigger phrase: " TRIGGER_PHRASE
    fi
    
    # Update config file
    cat > "$CONFIG_FILE" << EOF
LORA_NAME="$LORA_NAME"
AUTHOR_NAME="$AUTHOR_NAME"
TRIGGER_PHRASE="$TRIGGER_PHRASE"
EOF
fi

# Step 1: Environment Setup
if ! run_step 1 "Environment Setup" "step1_setup_environment.sh" \
    "This will check your system requirements and install necessary dependencies"; then
    print_error "Environment setup failed. Please check the errors above."
    exit 1
fi

# Step 1.5: Manual Environment Activation
echo ""
echo "========================================="
echo "Step 1.5: Manual Environment Activation Required"
echo "========================================="
print_warning "IMPORTANT: You must manually activate the conda environment!"
echo ""
echo "Please run these commands in your terminal:"
echo ""
print_info "1. conda activate wan22_lora"
print_info "2. conda install protobuf -y"
print_info "3. ./step1.5_activate_and_verify.sh --verify"
echo ""
echo "After completing these steps, run this script again with:"
echo "  $0 --start-from 2"
echo ""
read -p "Press Enter to acknowledge and exit (you'll need to activate manually)..." 
exit 0

# Step 2: Download Models
if ! run_step 2 "Download Models" "step2_download_models.sh" \
    "This will download all required WAN2.2 models (~30GB)"; then
    print_error "Model download failed. You can resume later with: $0 --start-from 2"
    exit 1
fi

# Step 3: Dataset Preparation
if ! run_step 3 "Dataset Preparation" "step3_prepare_dataset.sh" \
    "This will analyze your dataset and create configuration files"; then
    print_error "Dataset preparation failed. Please add images to dataset/images/"
    exit 1
fi

# Check if this is a continuation (step 4 only)
if [ "$START_FROM_STEP" -eq 4 ] && [ "$#" -eq 2 ]; then
    # User is continuing from step 4, check dataset
    image_count=$(find "$SCRIPT_DIR/dataset/images" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)
    
    if [ "$image_count" -eq 0 ]; then
        print_error "No images found in dataset/images/"
        print_info "Please add your training images with corresponding .txt caption files"
        print_info "Then run: $0 --start-from 4"
        exit 1
    fi
    
    # Step 4: Training
    echo ""
    echo "========================================="
    echo "Step 4: Training"
    echo "========================================="
    echo "Found $image_count images in dataset"
    echo "Ready to start training with:"
    echo "  - LoRA Name: $LORA_NAME"
    echo "  - Author: $AUTHOR_NAME"
    echo "  - Trigger: $TRIGGER_PHRASE"
    echo ""
    
    if [ "$AUTO_MODE" != true ]; then
        read -p "Start training now? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_warning "Training cancelled"
            exit 0
        fi
    fi
    
    # Run training
    if bash "$SCRIPT_DIR/step4_train_wan22_lora.sh" \
        --name "$LORA_NAME" \
        --author "$AUTHOR_NAME" \
        --trigger "$TRIGGER_PHRASE"; then
        print_status "Training completed successfully!"
    else
        print_error "Training failed"
        exit 1
    fi
else
    # Normal flow - stop after step 3
    echo ""
    echo "========================================="
    echo "Setup Complete - Ready for Dataset!"
    echo "========================================="
    echo ""
    print_status "Environment is set up"
    print_status "Models are downloaded"
    print_status "Dataset structure is prepared"
    echo ""
    echo "Next steps:"
    echo "  1. Add your training images to: $SCRIPT_DIR/dataset/images/"
    echo "  2. Create a .txt caption file for each image"
    echo "     Example: image001.jpg → image001.txt"
    echo "  3. Include your trigger phrase in every caption: \"$TRIGGER_PHRASE\""
    echo ""
    echo "See dataset/PREPARE_YOUR_DATA_HERE.md for detailed instructions"
    echo ""
    echo "When ready, continue training with:"
    echo "  $0 --start-from 4"
    echo ""
    echo "Or use the quick training script:"
    echo "  ./quick_train.sh \"$LORA_NAME\" \"$TRIGGER_PHRASE\""
    echo ""
    
    # Save config for later use
    print_info "Your settings have been saved for easy resumption"
fi

# Final summary
echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Your LoRA has been trained and saved to:"
echo "  output/${LORA_NAME}-HighNoise.safetensors"
echo "  output/${LORA_NAME}-LowNoise.safetensors"
echo ""
echo "To use your LoRA:"
echo "  1. Load both files in ComfyUI"
echo "  2. Set strength to 1.0 for both"
echo "  3. Use trigger phrase: \"$TRIGGER_PHRASE\""
echo ""
echo "Recommended workflow:"
echo "https://www.dropbox.com/scl/fi/pfpzff7eyjcql0uetj1at/WAN2.2_recommended_default_text2image_inference_workflow_by_AI_Characters-v3.json"