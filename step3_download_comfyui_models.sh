#!/bin/bash

# Step 3 备用方案: 下载 ComfyUI 版本的 Wan2.2 模型
# 如果官方模型下载失败，可以使用这个脚本下载 ComfyUI 版本

set -e

echo "========================================="
echo "下载 ComfyUI 版本的 Wan2.2 模型"
echo "========================================="
echo ""

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"
COMFYUI_DIR="$PROJECT_ROOT/models/comfyui_models"

mkdir -p "$MODEL_DIR"
mkdir -p "$COMFYUI_DIR"

# 使用 HuggingFace 镜像
export HF_ENDPOINT=https://hf-mirror.com

# 下载函数
download_file() {
    local url=$1
    local output=$2
    local desc=$3
    
    if [ -f "$output" ]; then
        local size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000000 ]; then  # 大于1MB
            echo "文件已存在，跳过: $output"
            return 0
        else
            echo "文件太小，重新下载: $output"
            rm -f "$output"
        fi
    fi
    
    echo "下载: $desc"
    echo "保存到: $output"
    
    # 使用 wget 下载，支持断点续传
    if wget -c "$url" -O "$output" --timeout=30 --tries=3; then
        echo "✓ 下载成功: $desc"
        return 0
    else
        echo "✗ 下载失败: $desc"
        return 1
    fi
}

echo "1. 下载 ComfyUI 版本的主模型..."
download_file \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors" \
    "$COMFYUI_DIR/wan2.2_ti2v_5B_fp16.safetensors" \
    "Wan2.2 5B FP16 模型 (约9.9GB)"

echo ""
echo "2. 下载 T5 文本编码器..."
download_file \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors" \
    "$COMFYUI_DIR/umt5_xxl_fp16.safetensors" \
    "UMT5-XXL FP16 文本编码器 (约9.2GB)"

echo ""
echo "3. 下载 VAE (使用官方版本)..."
if [ ! -f "$MODEL_DIR/Wan2.2_VAE.pth" ]; then
    download_file \
        "https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/Wan2.2_VAE.pth" \
        "$MODEL_DIR/Wan2.2_VAE.pth" \
        "Wan2.2 VAE (约2.6GB)"
else
    echo "VAE 已存在: $MODEL_DIR/Wan2.2_VAE.pth"
fi

# 创建配置文件
echo ""
echo "4. 创建配置文件..."
if [ ! -f "$MODEL_DIR/config.json" ]; then
    cat > "$MODEL_DIR/config.json" << 'EOF'
{
  "_class_name": "Wan2.2",
  "_diffusers_version": "0.27.0",
  "num_layers": 30,
  "caption_channels": 4096,
  "attention_head_dim": 128,
  "in_channels": 16,
  "out_channels": 16,
  "num_attention_heads": 30,
  "cross_attention_dim": 2048,
  "time_embed_dim": 1024,
  "mlp_ratio": 4,
  "model_max_length": 128
}
EOF
    echo "✓ 配置文件创建成功"
fi

echo ""
echo "========================================="
echo "ComfyUI 模型下载完成！"
echo "========================================="
echo ""
echo "模型位置:"
echo "  - 主模型: $COMFYUI_DIR/wan2.2_ti2v_5B_fp16.safetensors"
echo "  - T5编码器: $COMFYUI_DIR/umt5_xxl_fp16.safetensors"
echo "  - VAE: $MODEL_DIR/Wan2.2_VAE.pth"
echo ""
echo "注意: 使用 ComfyUI 模型需要在训练配置中指定对应路径"
echo "========================================="