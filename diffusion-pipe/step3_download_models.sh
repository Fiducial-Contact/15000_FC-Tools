#!/bin/bash

# Step 3: 下载 Wan2.2-TI2V-5B 模型
# 这是第三步：下载预训练模型文件

set -e

echo "========================================="
echo "Step 3: 下载 Wan2.2-TI2V-5B 模型"
echo "========================================="
echo ""

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
MODEL_DIR="$PROJECT_ROOT/models/Wan2.2-TI2V-5B"

mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

echo "模型目录: $MODEL_DIR"
echo ""

# 使用 HuggingFace 镜像
export HF_ENDPOINT=https://hf-mirror.com

# 基础 URL
BASE_URL="https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main"

# 下载函数
download_file() {
    local filename=$1
    local url="$BASE_URL/$filename"
    
    if [ -f "$filename" ]; then
        local size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000 ]; then
            echo "文件已存在，跳过: $filename (大小: $size bytes)"
            return 0
        else
            echo "文件太小，重新下载: $filename"
            rm -f "$filename"
        fi
    fi
    
    echo "下载: $filename"
    echo "URL: $url"
    
    # 尝试下载，最多重试3次
    for i in {1..3}; do
        echo "尝试 $i/3..."
        
        # 首先尝试 wget
        if command -v wget &> /dev/null; then
            if wget -c "$url" -O "$filename" --timeout=30 --tries=3; then
                echo "✓ 下载成功: $filename"
                return 0
            fi
        fi
        
        # 如果 wget 失败，尝试 curl
        if command -v curl &> /dev/null; then
            if curl -L -C - "$url" -o "$filename" --connect-timeout 30 --retry 3; then
                echo "✓ 下载成功: $filename"
                return 0
            fi
        fi
        
        # 如果都失败，尝试 aria2c
        if command -v aria2c &> /dev/null; then
            if aria2c -x 16 -s 16 -c "$url" -o "$filename" --timeout=30 --retry-wait=5; then
                echo "✓ 下载成功: $filename"
                return 0
            fi
        fi
        
        echo "✗ 下载失败，等待5秒后重试..."
        sleep 5
    done
    
    echo "错误: 无法下载 $filename"
    return 1
}

# 模型文件列表
echo "开始下载模型文件..."
echo "提示：大文件下载可能需要较长时间，请耐心等待"
echo ""

# 下载配置文件（小文件）
echo "[1/7] 下载配置文件..."
download_file "config.json"

echo ""
echo "[2/7] 下载索引文件..."
download_file "diffusion_pytorch_model.safetensors.index.json"

# 下载模型分片（大文件）
echo ""
echo "[3/7] 下载模型分片 1/3 (约10GB)..."
download_file "diffusion_pytorch_model-00001-of-00003.safetensors"

echo ""
echo "[4/7] 下载模型分片 2/3 (约10GB)..."
download_file "diffusion_pytorch_model-00002-of-00003.safetensors"

echo ""
echo "[5/7] 下载模型分片 3/3 (约179MB)..."
download_file "diffusion_pytorch_model-00003-of-00003.safetensors"

# 下载其他文件
echo ""
echo "[6/7] 下载 README..."
download_file "README.md"

echo ""
echo "[7/7] 下载 VAE 模型..."
download_file "Wan2.2_VAE.pth"

# 验证关键文件
echo ""
echo "验证模型文件..."
if [ ! -f "config.json" ]; then
    echo "✗ 错误: config.json 缺失！"
    exit 1
fi

if [ ! -f "diffusion_pytorch_model.safetensors.index.json" ]; then
    echo "✗ 错误: diffusion_pytorch_model.safetensors.index.json 缺失！"
    exit 1
fi

echo "✓ 关键文件验证通过"

echo ""
echo "模型文件列表:"
ls -lah "$MODEL_DIR"

echo ""
echo "========================================="
echo "Step 3 完成！模型下载成功"
echo "========================================="
echo ""
echo "模型位置: $MODEL_DIR"
echo ""
echo "下一步：运行 ./step4_prepare_training.sh"
echo "========================================="