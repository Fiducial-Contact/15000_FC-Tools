#!/bin/bash

# Step 1: 环境设置和依赖安装脚本
# 这是第一步：设置环境并安装所有必要的依赖

set -e  # 遇到错误立即退出

echo "========================================="
echo "Step 1: 环境设置和依赖安装"
echo "========================================="
echo ""

# 获取脚本所在目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 设置项目相关路径
PROJECT_ROOT="$SCRIPT_DIR"
echo "项目根目录: $PROJECT_ROOT"

# 检测当前环境
echo ""
echo "检测当前环境..."
python --version || { echo "错误: 未找到 Python"; exit 1; }
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || echo "警告: 未检测到 GPU"

# 安装 aria2（如果需要）
echo ""
echo "检查并安装必要工具..."
if ! command -v aria2c &> /dev/null; then
    echo "安装 aria2..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y aria2 wget curl || { echo "错误: 安装工具失败"; exit 1; }
    elif command -v yum &> /dev/null; then
        yum install -y aria2 wget curl || { echo "错误: 安装工具失败"; exit 1; }
    else
        echo "警告: 无法自动安装 aria2，但不影响后续步骤"
    fi
else
    echo "aria2 已安装"
fi

# 安装 Python 依赖
echo ""
echo "安装 Python 依赖..."

# 检查是否在中国，使用镜像源
if ping -c 1 -W 1 pypi.tuna.tsinghua.edu.cn &> /dev/null; then
    echo "使用清华镜像源..."
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn
fi

# 清理可能的缓存问题
echo "清理 pip 缓存..."
pip cache purge 2>/dev/null || true

# 安装 DeepSpeed（跳过编译）
echo "安装 DeepSpeed..."
DS_BUILD_OPS=0 pip install --no-cache-dir deepspeed==0.17.0 || { echo "错误: DeepSpeed 安装失败"; exit 1; }

# 首先确保 PyTorch 已正确安装
echo "检查/安装 PyTorch..."
if ! python -c "import torch" 2>/dev/null; then
    echo "安装 PyTorch..."
    # 使用官方源安装 PyTorch 以避免哈希问题
    pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cu118 || \
    pip install --no-cache-dir torch || \
    { echo "错误: PyTorch 安装失败"; exit 1; }
fi

# 安装核心依赖（使用 --no-deps 逐个安装避免依赖冲突）
echo "安装核心依赖..."
# torch-optimi 需要特殊处理
pip install --no-cache-dir --no-deps torch-optimi || echo "警告: torch-optimi 安装失败，使用标准优化器"

# 安装其他核心依赖
pip install --no-cache-dir transformers accelerate safetensors einops toml tqdm peft packaging

# 安装数据处理依赖
echo "安装数据处理依赖..."
pip install --no-cache-dir pillow
pip install --no-cache-dir imageio
pip install --no-cache-dir imageio-ffmpeg
pip install --no-cache-dir opencv-python-headless
# av 包可能在某些镜像源上有哈希值问题，使用官方源或清华源
pip install --no-cache-dir av --index-url https://pypi.org/simple || \
pip install --no-cache-dir av -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装训练工具
echo "安装训练工具..."
pip install --no-cache-dir tensorboard wandb sentencepiece protobuf
pip install --no-cache-dir huggingface_hub

# 可选：安装 bitsandbytes
echo "尝试安装 bitsandbytes（可选）..."
pip install --no-cache-dir bitsandbytes || echo "警告: bitsandbytes 安装失败，但不影响基础训练"

# 再次检查关键依赖
echo ""
echo "验证关键依赖..."
python -c "
import importlib
required = ['torch', 'transformers', 'deepspeed', 'accelerate', 'safetensors']
missing = []
for pkg in required:
    try:
        importlib.import_module(pkg)
        print(f'✓ {pkg} 已安装')
    except ImportError:
        print(f'✗ {pkg} 未安装')
        missing.append(pkg)
if missing:
    print(f'\\n错误: 缺少关键依赖: {missing}')
    exit(1)
"

echo ""
echo "========================================="
echo "Step 1 完成！环境设置成功"
echo "========================================="
echo ""
echo "下一步：运行 ./step2_create_structure.sh"
echo ""
echo "注意：如果 av 包安装失败（哈希值错误），请手动运行："
echo "  pip install av --index-url https://pypi.org/simple"
echo "========================================="