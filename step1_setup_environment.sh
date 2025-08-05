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

# 检查 PyTorch 版本
echo "检查 PyTorch 版本..."
TORCH_VERSION=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "0.0.0")
TORCH_VERSION_CLEAN=$(echo $TORCH_VERSION | cut -d'+' -f1)  # 移除 +cu118 等后缀
TORCH_MAJOR=$(echo $TORCH_VERSION_CLEAN | cut -d'.' -f1)
TORCH_MINOR=$(echo $TORCH_VERSION_CLEAN | cut -d'.' -f2)

echo "当前 PyTorch 版本: $TORCH_VERSION"

# 判断是否需要升级
if [ "$TORCH_VERSION" = "0.0.0" ] || [ "$TORCH_MAJOR" -lt 2 ] || ([ "$TORCH_MAJOR" -eq 2 ] && [ "$TORCH_MINOR" -lt 1 ]); then
    if [ "$TORCH_VERSION" != "0.0.0" ]; then
        echo "需要升级到 PyTorch 2.1+ 以支持 Flash Attention"
        echo "正在卸载旧版本..."
        pip uninstall -y torch torchvision torchaudio 2>/dev/null || true
    fi
    
    echo "安装 PyTorch 2.1+"
    # 检测 CUDA 版本并选择合适的 PyTorch
    if command -v nvidia-smi &> /dev/null; then
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d'.' -f1-2)
        echo "检测到 CUDA 版本: $CUDA_VERSION"
        
        # 根据 CUDA 版本选择 PyTorch
        if [[ "$CUDA_VERSION" == "11."* ]]; then
            echo "使用 CUDA 11.8 版本的 PyTorch"
            pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
        elif [[ "$CUDA_VERSION" == "12."* ]]; then
            echo "使用 CUDA 12.1 版本的 PyTorch"
            pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121
        else
            echo "使用默认 CUDA 版本的 PyTorch"
            pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0
        fi
    else
        echo "未检测到 GPU，安装 CPU 版本的 PyTorch"
        pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cpu
    fi
    
    # 验证安装
    NEW_TORCH_VERSION=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "0.0.0")
    echo "已安装 PyTorch 版本: $NEW_TORCH_VERSION"
else
    echo "PyTorch 版本 $TORCH_VERSION 符合要求"
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

# 安装 Flash Attention
echo ""
echo "安装 Flash Attention..."
# Flash Attention 需要 PyTorch 2.0+ 和特定的 CUDA 版本
TORCH_VERSION=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "0.0.0")
if [[ "$TORCH_VERSION" == "2."* ]]; then
    # 尝试安装 Flash Attention
    pip install --no-cache-dir flash-attn --no-build-isolation || {
        echo "警告: Flash Attention 安装失败"
        echo "可能的原因："
        echo "  - CUDA 版本不兼容"
        echo "  - 缺少编译工具"
        echo "  - GPU 架构不支持"
        echo "训练将使用标准注意力机制（速度较慢但功能相同）"
    }
else
    echo "跳过 Flash Attention 安装（需要 PyTorch 2.0+）"
fi

# 再次检查关键依赖和版本
echo ""
echo "验证安装结果..."
python -c "
import importlib
import sys

# 检查必需的包
required = ['torch', 'transformers', 'deepspeed', 'accelerate', 'safetensors']
missing = []
for pkg in required:
    try:
        importlib.import_module(pkg)
        print(f'✓ {pkg} 已安装')
    except ImportError:
        print(f'✗ {pkg} 未安装')
        missing.append(pkg)

# 详细检查 PyTorch 版本
try:
    import torch
    torch_version = torch.__version__
    print(f'\\nPyTorch 版本: {torch_version}')
    
    # 检查版本是否满足要求
    version_parts = torch_version.split('+')[0].split('.')
    major, minor = int(version_parts[0]), int(version_parts[1])
    if major < 2 or (major == 2 and minor < 1):
        print(f'⚠️  警告: PyTorch 版本 {torch_version} 低于推荐版本 2.1.0')
        print('   某些功能可能无法使用')
    else:
        print('✓ PyTorch 版本符合要求')
    
    # 检查 CUDA 可用性
    if torch.cuda.is_available():
        print(f'✓ CUDA 可用: {torch.cuda.get_device_name(0)}')
        print(f'  CUDA 版本: {torch.version.cuda}')
    else:
        print('⚠️  未检测到 CUDA，将使用 CPU 训练（速度较慢）')
except Exception as e:
    print(f'检查 PyTorch 时出错: {e}')

# 检查 Flash Attention
try:
    import flash_attn
    print('\\n✓ Flash Attention 已安装')
except ImportError:
    print('\\n⚠️  Flash Attention 未安装，将使用标准注意力机制')
    print('   这不会影响训练，但速度会较慢')

if missing:
    print(f'\\n错误: 缺少关键依赖: {missing}')
    sys.exit(1)
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