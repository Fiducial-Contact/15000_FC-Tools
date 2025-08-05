# 📚 WAN2.2 LoRA Dataset Preparation Guide

Welcome! This guide will help you prepare your dataset for training a WAN2.2 LoRA model.

## 🎯 Quick Start

1. **Add your images** to the `images/` folder
2. **Create caption files** - for each image, create a `.txt` file with the same name
3. **Include your trigger phrase** in every caption

## 📁 Directory Structure

```
dataset/
├── images/               # Put your training images here
│   ├── photo001.jpg     # Your image
│   ├── photo001.txt     # Caption for photo001.jpg
│   ├── photo002.png     # Another image
│   ├── photo002.txt     # Caption for photo002.png
│   └── ...
├── videos/              # (Optional) Video files
├── caption_examples.txt # Example captions for reference
└── dataset.toml         # Auto-generated configuration
```

## 🖼️ Image Requirements

### Supported Formats
- `.jpg` / `.jpeg`
- `.png`
- `.webp`

### Recommended Specifications
- **Resolution**: 768×768 or higher (1024×1024 for best quality)
- **Aspect Ratio**: Square (1:1) or standard ratios (16:9, 4:3)
- **File Size**: Under 10MB per image
- **Quantity**: 20-50 images for good results

### Image Selection Tips
- Choose images with **consistent style**
- Include **variety** in poses, angles, and contexts
- Avoid blurry or low-quality images
- Ensure good lighting in most images

## ✍️ Caption Requirements

### Basic Rules
1. **One caption per image** - `image.jpg` needs `image.txt`
2. **Include trigger phrase** - MUST appear in every caption
3. **Be descriptive** - Describe what's in the image
4. **Keep it concise** - 1-2 sentences is usually enough

### Caption Format
```
trigger_phrase, main subject, action/pose, setting, lighting, style details
```

### Examples

#### Good Caption Examples
```
mystyle, woman with long brown hair, sitting at cafe table, natural window lighting, casual atmosphere
```

```
mystyle, elderly man wearing suit, standing in library, warm indoor lighting, professional portrait
```

```
mystyle, group of friends laughing, outdoor picnic scene, golden hour sunlight, candid photo
```

#### Bad Caption Examples
```
beautiful photo
```
❌ Too vague, missing trigger phrase

```
IMG_1234.jpg
```
❌ Meaningless, not descriptive

```
a woman smiling
```
❌ Missing trigger phrase, not enough detail

## 🎨 Style-Specific Tips

### For Photographic Styles
- Mention camera angle (eye-level, low angle, etc.)
- Include lighting type (natural, studio, flash)
- Describe mood or atmosphere

### For Artistic Styles
- Mention medium (digital art, oil painting, etc.)
- Include color palette info
- Describe artistic techniques

### For Character LoRAs
- Focus on consistent features
- Describe clothing and accessories
- Include pose and expression

## 📝 Caption Writing Workflow

1. **Start with trigger phrase**: `mystyle,`
2. **Identify main subject**: `young woman with glasses,`
3. **Describe action/pose**: `reading book,`
4. **Add context**: `in cozy library,`
5. **Include lighting**: `soft warm lighting`

Final caption: `mystyle, young woman with glasses, reading book, in cozy library, soft warm lighting`

## 🚀 Dataset Checklist

Before training, ensure:
- [ ] At least 20 images in `images/` folder
- [ ] Every image has a corresponding `.txt` file
- [ ] All captions include your trigger phrase
- [ ] Images are high quality (768×768 or higher)
- [ ] Captions are descriptive and accurate
- [ ] Dataset has variety while maintaining consistency

## 💡 Pro Tips

1. **Batch Processing**: Use tools like Excel or a text editor to create captions efficiently
2. **Naming Convention**: Use sequential numbers (001, 002, etc.) for easy organization
3. **Test Your Trigger**: Make it unique enough to not conflict with common words
4. **Quality > Quantity**: 30 great images > 100 mediocre ones
5. **Caption Variety**: Don't copy-paste the same caption - add unique details

## ⚠️ Common Mistakes to Avoid

- **Forgetting trigger phrase** - Double-check every caption
- **Mismatched filenames** - `photo1.jpg` needs `photo1.txt` (exact match)
- **Too many styles** - Keep your dataset focused on one consistent style
- **Low resolution images** - These will limit your LoRA's quality
- **Subjective descriptions** - Avoid "beautiful", "amazing" - be objective

## 🎯 Ready to Train?

Once your dataset is prepared:

1. Return to the main kohya-ss directory
2. Run: `./step0_run_all.sh --start-from 4`
3. Or use: `./step4_train_wan22_lora.sh --name "YourLoRA" --author "YourName" --trigger "your_trigger"`

Good luck with your training! 🚀