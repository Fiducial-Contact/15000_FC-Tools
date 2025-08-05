#!/bin/bash

# WAN2.2 Dataset Preparation Script
# Helps prepare and validate datasets for LoRA training
# Based on community best practices

set -e

echo "========================================="
echo "WAN2.2 Dataset Preparation Script"
echo "========================================="
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

# Dataset directories
DATASET_DIR="$SCRIPT_DIR/dataset"
IMAGE_DIR="$DATASET_DIR/images"
VIDEO_DIR="$DATASET_DIR/videos"
CAPTION_DIR="$DATASET_DIR/captions"

# Create directories if they don't exist
mkdir -p "$IMAGE_DIR" "$VIDEO_DIR" "$CAPTION_DIR"

# Step 1: Check dataset contents
echo "Step 1: Checking dataset contents..."
echo ""

image_count=$(find "$IMAGE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)
video_count=$(find "$VIDEO_DIR" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null | wc -l)

print_info "Found $image_count images in $IMAGE_DIR"
print_info "Found $video_count videos in $VIDEO_DIR"

if [ "$image_count" -eq 0 ] && [ "$video_count" -eq 0 ]; then
    print_warning "No dataset files found!"
    echo ""
    echo "Please add your training data:"
    echo "  - Images: Place .jpg/.png/.webp files in $IMAGE_DIR"
    echo "  - Videos: Place .mp4/.avi/.mov files in $VIDEO_DIR"
    echo ""
    echo "For each file, create a corresponding .txt caption file:"
    echo "  - image001.jpg → image001.txt"
    echo "  - video001.mp4 → video001.txt"
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Step 2: Validate captions
echo ""
echo "Step 2: Validating captions..."

missing_captions=0
total_files=0

# Check image captions
if [ "$image_count" -gt 0 ]; then
    for img in "$IMAGE_DIR"/*.{jpg,jpeg,png,webp} 2>/dev/null; do
        [ -f "$img" ] || continue
        total_files=$((total_files + 1))
        
        base_name=$(basename "$img" | sed 's/\.[^.]*$//')
        caption_file="$IMAGE_DIR/${base_name}.txt"
        
        if [ ! -f "$caption_file" ]; then
            print_warning "Missing caption for: $(basename "$img")"
            missing_captions=$((missing_captions + 1))
        fi
    done
fi

# Check video captions
if [ "$video_count" -gt 0 ]; then
    for vid in "$VIDEO_DIR"/*.{mp4,avi,mov,mkv} 2>/dev/null; do
        [ -f "$vid" ] || continue
        total_files=$((total_files + 1))
        
        base_name=$(basename "$vid" | sed 's/\.[^.]*$//')
        caption_file="$VIDEO_DIR/${base_name}.txt"
        
        if [ ! -f "$caption_file" ]; then
            print_warning "Missing caption for: $(basename "$vid")"
            missing_captions=$((missing_captions + 1))
        fi
    done
fi

if [ "$missing_captions" -gt 0 ]; then
    print_warning "Found $missing_captions files without captions (out of $total_files total)"
    echo "Each training file needs a corresponding .txt caption file"
else
    print_status "All files have captions"
fi

# Step 3: Analyze image properties
echo ""
echo "Step 3: Analyzing dataset properties..."

if [ "$image_count" -gt 0 ]; then
    # Create a Python script to analyze images
    cat > analyze_dataset.py << 'EOF'
import os
import sys
from PIL import Image
from collections import defaultdict

image_dir = sys.argv[1]
stats = {
    'resolutions': defaultdict(int),
    'aspects': defaultdict(int),
    'formats': defaultdict(int),
    'total_pixels': 0,
    'count': 0
}

print("\nAnalyzing images...")
for filename in os.listdir(image_dir):
    if filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
        filepath = os.path.join(image_dir, filename)
        try:
            with Image.open(filepath) as img:
                width, height = img.size
                resolution = f"{width}x{height}"
                aspect = round(width / height, 2)
                
                stats['resolutions'][resolution] += 1
                stats['aspects'][aspect] += 1
                stats['formats'][img.format] += 1
                stats['total_pixels'] += width * height
                stats['count'] += 1
                
                # Warn about problematic images
                if width < 512 or height < 512:
                    print(f"⚠️  Low resolution: {filename} ({resolution})")
                elif width > 2048 or height > 2048:
                    print(f"⚠️  Very high resolution: {filename} ({resolution})")
                    
        except Exception as e:
            print(f"❌ Error reading {filename}: {e}")

if stats['count'] > 0:
    print(f"\n📊 Dataset Statistics:")
    print(f"  Total images: {stats['count']}")
    print(f"  Average resolution: {int(stats['total_pixels'] / stats['count'] / 1000)}K pixels")
    
    print(f"\n📐 Top resolutions:")
    for res, count in sorted(stats['resolutions'].items(), key=lambda x: x[1], reverse=True)[:5]:
        print(f"    {res}: {count} images")
    
    print(f"\n📏 Aspect ratios:")
    for aspect, count in sorted(stats['aspects'].items(), key=lambda x: x[1], reverse=True)[:5]:
        print(f"    {aspect}: {count} images")
        
    print(f"\n🎨 Formats:")
    for fmt, count in stats['formats'].items():
        print(f"    {fmt}: {count} images")
        
    # Recommendations
    print(f"\n💡 Recommendations:")
    if any(int(r.split('x')[0]) < 768 or int(r.split('x')[1]) < 768 for r in stats['resolutions'].keys()):
        print("  - Consider using images with at least 768x768 resolution")
    if len(stats['aspects']) > 3:
        print("  - Consider standardizing aspect ratios for more consistent training")
    print("  - Recommended resolution for WAN2.2: 768x768 or 1024x1024")
EOF

    python analyze_dataset.py "$IMAGE_DIR"
    rm analyze_dataset.py
fi

# Step 4: Create dataset configuration
echo ""
echo "Step 4: Creating dataset configuration..."

# Determine batch size based on available memory
if command -v nvidia-smi &> /dev/null; then
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    if [ "$GPU_MEMORY" -lt 16000 ]; then
        BATCH_SIZE=1
        BUCKET_NO_UPSCALE="true"
    elif [ "$GPU_MEMORY" -lt 24000 ]; then
        BATCH_SIZE=1
        BUCKET_NO_UPSCALE="false"
    else
        BATCH_SIZE=2
        BUCKET_NO_UPSCALE="false"
    fi
else
    BATCH_SIZE=1
    BUCKET_NO_UPSCALE="true"
fi

# Create dataset.toml
cat > "$DATASET_DIR/dataset.toml" << EOF
# WAN2.2 LoRA Training Dataset Configuration
# Generated by prepare_dataset.sh

[general]
# Enable image datasets
enable_image_datasets = true
# Enable video datasets if you have them
enable_video_datasets = $([ "$video_count" -gt 0 ] && echo "true" || echo "false")

# Resolution for training (recommended: 768 or 1024)
resolution = 768

# Batch size (adjust based on GPU memory)
batch_size = $BATCH_SIZE

# Enable bucketing for mixed aspect ratios
enable_bucket = true
bucket_no_upscale = $BUCKET_NO_UPSCALE

# Image configuration
[[image_datasets]]
# Directory containing images and captions
directory = "$IMAGE_DIR"

# Number of repeats for the dataset
# Adjust based on dataset size (smaller dataset = more repeats)
num_repeats = $([ "$image_count" -lt 50 ] && echo "10" || echo "5")

# Caption extension
caption_extension = ".txt"

# Shuffle captions (adds variety)
shuffle_caption = true

# Keep tokens separator
keep_tokens_separator = ","

EOF

if [ "$video_count" -gt 0 ]; then
    cat >> "$DATASET_DIR/dataset.toml" << EOF

# Video configuration
[[video_datasets]]
# Directory containing videos and captions
directory = "$VIDEO_DIR"

# Number of repeats for the dataset
num_repeats = $([ "$video_count" -lt 20 ] && echo "10" || echo "5")

# Caption extension
caption_extension = ".txt"

# Video settings
frame_extraction_method = "uniform"
max_frames = 24
fps = 8

# Shuffle captions
shuffle_caption = true
EOF
fi

print_status "Created dataset configuration at $DATASET_DIR/dataset.toml"

# Step 5: Create caption templates
echo ""
echo "Step 5: Creating caption templates..."

# Create example captions
cat > "$DATASET_DIR/caption_examples.txt" << 'EOF'
# WAN2.2 Caption Examples
# Good captions are descriptive and include the trigger phrase

For Smartphone Style LoRA:
- "image in an early 2010s amateur photo artstyle with washed out colors, a woman smiling at camera, casual indoor lighting"
- "image in an early 2010s amateur photo artstyle with washed out colors, group of friends at beach, overexposed sky"

General Tips:
1. Always include your trigger phrase at the beginning
2. Describe the main subject clearly
3. Mention lighting conditions
4. Include style-relevant details
5. Keep captions concise but descriptive
6. Avoid subjective qualities like "beautiful" or "amazing"

Bad Examples:
- "a photo" (too vague)
- "beautiful woman" (subjective, not descriptive)
- "IMG_1234" (meaningless)

Good Examples:
- "amateur photo style, young man wearing glasses, sitting at desk, fluorescent office lighting"
- "vintage photograph aesthetic, elderly couple on park bench, soft natural lighting, autumn leaves"
EOF

print_status "Created caption examples at $DATASET_DIR/caption_examples.txt"

# Step 6: Pre-cache option
echo ""
echo "Step 6: Pre-caching setup..."

cat > pre_cache_dataset.sh << 'EOF'
#!/bin/bash
# Pre-cache dataset for faster training
# Run this after activating the environment

echo "Pre-caching dataset..."
echo "This will create latent and text encoder caches"
echo "It may take some time but will speed up training significantly"

cd musubi-tuner

# Source model paths
source ../model_paths.sh

# Pre-cache command
python -m musubi_tuner.cache_latents \
    --dataset_config ../dataset/dataset.toml \
    --vae "$WAN22_VAE_MODEL" \
    --t5 "$WAN22_T5_MODEL" \
    --cache_dir ../dataset/cache \
    --mixed_precision fp16

echo "Pre-caching complete!"
echo "Caches saved to: ../dataset/cache/"
EOF

chmod +x pre_cache_dataset.sh
print_status "Created pre_cache_dataset.sh for optional pre-caching"

# Final summary
echo ""
echo "========================================="
echo "Dataset Structure Prepared!"
echo "========================================="
echo ""
echo "✅ Created directories:"
echo "  - $IMAGE_DIR (for your training images)"
echo "  - $VIDEO_DIR (for videos, optional)"
echo "  - $CAPTION_DIR (alternative caption storage)"
echo ""
echo "✅ Generated files:"
echo "  - dataset.toml (configuration)"
echo "  - caption_examples.txt (caption writing guide)"
echo "  - pre_cache_dataset.sh (optimization script)"
echo ""
if [ "$image_count" -eq 0 ]; then
    echo "📌 NOW ADD YOUR TRAINING DATA:"
    echo ""
    echo "  1. Copy your images to: $IMAGE_DIR"
    echo "     Supported formats: .jpg, .png, .webp"
    echo ""
    echo "  2. For each image, create a .txt file with the same name:"
    echo "     Example: photo1.jpg → photo1.txt"
    echo ""
    echo "  3. In each .txt file, write a caption that includes your trigger phrase"
    echo "     Example: \"your_trigger_phrase, a woman smiling at camera\""
    echo ""
    echo "  📖 See PREPARE_YOUR_DATA_HERE.md in the dataset folder for detailed instructions"
    echo ""
    echo "Once your data is ready, continue with:"
    echo "  ./step0_run_all.sh --start-from 4"
    echo "  OR"
    echo "  ./step4_train_wan22_lora.sh --name \"YourLoRA\" --author \"YourName\" --trigger \"your phrase\""
else
    echo "Current dataset status:"
    echo "  - Images: $image_count"
    echo "  - Videos: $video_count"
    echo "  - Missing captions: $missing_captions"
    echo ""
    echo "You can now:"
    echo "  - Add more images if needed (recommended: 20-50 images)"
    echo "  - Run ./step4_train_wan22_lora.sh to start training"
    echo "  - (Optional) Run ./pre_cache_dataset.sh to speed up training"
fi
echo ""
echo "💡 Tips:"
echo "  - Use consistent style across your dataset"
echo "  - Include your trigger phrase in EVERY caption"
echo "  - See caption_examples.txt for writing tips"