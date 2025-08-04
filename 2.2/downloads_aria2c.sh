#!/bin/bash

# Wan2.2 完整下载脚本 - 使用 aria2c
# 包含所有需要下载的文件

echo "========================================="
echo "Wan2.2 5B 完整下载脚本"
echo "使用 aria2c 多线程下载"
echo "========================================="

# 检查 aria2c 是否安装
if ! command -v aria2c &> /dev/null; then
    echo "错误: aria2c 未安装"
    echo "请运行: apt-get update && apt-get install -y aria2"
    exit 1
fi

# 创建下载目录
mkdir -p /root/downloads/{pytorch,models,vae}

# 1. PyTorch 下载配置
cat > /root/downloads/pytorch_aria2c.txt << 'EOF'
# PyTorch 2.0.1 + CUDA 12.1
https://download.pytorch.org/whl/cu121/torch-2.0.1%2Bcu121-cp310-cp310-linux_x86_64.whl
  dir=/root/downloads/pytorch
  out=torch-2.0.1+cu121-cp310-cp310-linux_x86_64.whl
  
https://download.pytorch.org/whl/cu121/torchvision-0.15.2%2Bcu121-cp310-cp310-linux_x86_64.whl
  dir=/root/downloads/pytorch
  out=torchvision-0.15.2+cu121-cp310-cp310-linux_x86_64.whl
  
https://download.pytorch.org/whl/cu121/torchaudio-2.0.2%2Bcu121-cp310-cp310-linux_x86_64.whl
  dir=/root/downloads/pytorch
  out=torchaudio-2.0.2+cu121-cp310-cp310-linux_x86_64.whl
EOF

# 2. Wan2.2 模型下载配置（使用镜像）
cat > /root/downloads/wan22_model_aria2c.txt << 'EOF'
# Wan2.2-TI2V-5B 主模型文件
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/config.json
  dir=/root/downloads/models
  out=config.json
  
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model.safetensors.index.json
  dir=/root/downloads/models
  out=model.safetensors.index.json
  
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00001-of-00003.safetensors
  dir=/root/downloads/models
  out=model-00001-of-00003.safetensors
  
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00002-of-00003.safetensors
  dir=/root/downloads/models
  out=model-00002-of-00003.safetensors
  
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00003-of-00003.safetensors
  dir=/root/downloads/models
  out=model-00003-of-00003.safetensors
  
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/README.md
  dir=/root/downloads/models
  out=README.md
  
# VAE 文件
https://hf-mirror.com/Wan-AI/Wan2.2-TI2V-5B/resolve/main/Wan2.2_VAE.pth
  dir=/root/downloads/vae
  out=Wan2.2_VAE.pth
EOF

# 3. 备用下载源（如果镜像站点失败）
cat > /root/downloads/wan22_model_alt_aria2c.txt << 'EOF'
# 备用: 使用原始 HuggingFace URL（可能需要代理）
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/config.json
  dir=/root/downloads/models
  out=config.json
  
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model.safetensors.index.json
  dir=/root/downloads/models
  out=model.safetensors.index.json
  
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00001-of-00003.safetensors
  dir=/root/downloads/models
  out=model-00001-of-00003.safetensors
  
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00002-of-00003.safetensors
  dir=/root/downloads/models
  out=model-00002-of-00003.safetensors
  
https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B/resolve/main/model-00003-of-00003.safetensors
  dir=/root/downloads/models
  out=model-00003-of-00003.safetensors
EOF

# 创建下载函数
download_with_aria2c() {
    local config_file=$1
    local description=$2
    
    echo ""
    echo "下载: $description"
    echo "配置文件: $config_file"
    echo ""
    
    aria2c \
        -x 16 \
        -s 16 \
        -j 5 \
        -c \
        --file-allocation=none \
        --check-certificate=false \
        --console-log-level=notice \
        --summary-interval=10 \
        --auto-file-renaming=false \
        -i "$config_file"
    
    return $?
}

# 主下载脚本
echo "选择下载选项："
echo "1. 下载 PyTorch"
echo "2. 下载 Wan2.2 模型（镜像站点）"
echo "3. 下载 Wan2.2 模型（原始站点）"
echo "4. 下载所有内容"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        download_with_aria2c "/root/downloads/pytorch_aria2c.txt" "PyTorch 2.0.1 + CUDA 12.1"
        ;;
    2)
        download_with_aria2c "/root/downloads/wan22_model_aria2c.txt" "Wan2.2-TI2V-5B 模型（镜像）"
        ;;
    3)
        download_with_aria2c "/root/downloads/wan22_model_alt_aria2c.txt" "Wan2.2-TI2V-5B 模型（原始）"
        ;;
    4)
        download_with_aria2c "/root/downloads/pytorch_aria2c.txt" "PyTorch 2.0.1 + CUDA 12.1"
        download_with_aria2c "/root/downloads/wan22_model_aria2c.txt" "Wan2.2-TI2V-5B 模型"
        ;;
    *)
        echo "无效选项"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "下载完成！"
echo "========================================="
echo ""
echo "下载的文件位置："
echo "- PyTorch: /root/downloads/pytorch/"
echo "- 模型文件: /root/downloads/models/"
echo "- VAE 文件: /root/downloads/vae/"
echo ""
echo "安装说明："
echo "1. 安装 PyTorch:"
echo "   cd /root/downloads/pytorch"
echo "   pip install torch-*.whl torchvision-*.whl torchaudio-*.whl"
echo ""
echo "2. 移动模型文件:"
echo "   mkdir -p /root/models/Wan2.2-TI2V-5B"
echo "   cp /root/downloads/models/* /root/models/Wan2.2-TI2V-5B/"
echo "   cp /root/downloads/vae/Wan2.2_VAE.pth /root/models/Wan2.2-TI2V-5B/"
echo ""

# 创建额外的下载脚本：手动下载单个文件
cat > download_single_file.sh << 'SINGLE'
#!/bin/bash

if [ $# -lt 2 ]; then
    echo "用法: $0 <URL> <输出文件名>"
    echo "示例: $0 https://example.com/file.bin output.bin"
    exit 1
fi

URL=$1
OUTPUT=$2

echo "下载: $URL"
echo "保存为: $OUTPUT"

aria2c \
    -x 16 \
    -s 16 \
    -c \
    --file-allocation=none \
    --check-certificate=false \
    --console-log-level=notice \
    --summary-interval=10 \
    -o "$OUTPUT" \
    "$URL"
SINGLE

chmod +x download_single_file.sh

echo "额外工具："
echo "- 单文件下载: ./download_single_file.sh <URL> <输出文件名>"